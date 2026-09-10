import { PrismaPg } from "@prisma/adapter-pg";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";

import { PrismaClient } from "../src/generated/prisma/client";
import {
  ActorType,
  NotificationDeliveryChannel,
  OperationalNotificationType,
  OutboxStatus,
} from "../src/generated/prisma/enums";
import { DeliveryProcessor } from "../src/delivery/delivery.processor";
import { PhoneChallengeService } from "../src/registration/phone-challenge.service";
import { PhoneSecurityService } from "../src/registration/phone-security.service";
import { SmsGateway } from "../src/registration/sms-gateway";
import { PhoneChallengePurpose } from "../src/generated/prisma/enums";
import { SessionService } from "../src/auth/session.service";
import { TokenService } from "../src/auth/token.service";
import { PrismaService } from "../src/database/prisma.service";
import { testAuthConfig } from "./support/auth-config";

const runtimeUrl = process.env.TEST_DATABASE_URL;
const directUrl = process.env.TEST_DIRECT_URL;
const describePostgres = runtimeUrl && directUrl ? describe : describe.skip;

describePostgres("opt-in isolated PostgreSQL migration and constraints", () => {
  jest.setTimeout(60_000);
  let prisma: PrismaClient;

  beforeAll(async () => {
    if (
      runtimeUrl === process.env.DATABASE_URL ||
      directUrl === process.env.DIRECT_URL
    ) {
      throw new Error(
        "Use separately isolated test database URLs, never shared application data.",
      );
    }
    execFileSync(
      process.platform === "win32" ? "pnpm.cmd" : "pnpm",
      ["prisma", "migrate", "deploy"],
      {
        cwd: resolve(__dirname, ".."),
        env: { ...process.env, DIRECT_URL: directUrl! },
        stdio: "pipe",
      },
    );
    prisma = new PrismaClient({
      adapter: new PrismaPg({ connectionString: runtimeUrl! }),
    });
    await prisma.$connect();
  });

  afterAll(async () => prisma?.$disconnect());

  it("rolls back OTP/account/session completion and consumes once under concurrent retry", async () => {
    const config = testAuthConfig();
    const phones = new PhoneSecurityService(config);
    const database = prisma as unknown as PrismaService;
    let deliveredCode = "";
    const sms: SmsGateway = {
      async sendVerificationCode(_phone, code) {
        deliveredCode = code;
        return "test-message-id";
      },
    };
    const service = new PhoneChallengeService(database, phones, sms, config);
    const sessions = new SessionService(
      database,
      new TokenService(config),
      config,
    );
    const phone = `+2567${Date.now().toString().slice(-8)}`;
    const user = await prisma.user.create({
      data: {
        actorType: ActorType.CLIENT,
        phoneLookup: phones.lookup(phone),
        encryptedPhone: phones.encrypt(phone),
        isActive: false,
        loginEnabled: false,
      },
    });
    const challenge = await service.create(
      phone,
      PhoneChallengePurpose.REGISTRATION,
      user.id,
    );
    try {
      await expect(
        service.verifyAndComplete(
          challenge.challengeId,
          deliveredCode,
          PhoneChallengePurpose.REGISTRATION,
          async (_, tx) => {
            await tx.user.update({
              where: { id: user.id },
              data: {
                phoneVerifiedAt: new Date(),
                loginEnabled: true,
                isActive: true,
              },
            });
            await sessions.create(user, tx);
            throw new Error("synthetic interruption after session creation");
          },
        ),
      ).rejects.toThrow("synthetic interruption");
      expect(
        await prisma.phoneChallenge.findUniqueOrThrow({
          where: { id: challenge.challengeId },
        }),
      ).toMatchObject({ consumedAt: null });
      expect(
        await prisma.user.findUniqueOrThrow({ where: { id: user.id } }),
      ).toMatchObject({ phoneVerifiedAt: null, loginEnabled: false });
      expect(
        await prisma.authenticationSession.count({
          where: { userId: user.id },
        }),
      ).toBe(0);
      const results = await Promise.allSettled(
        [1, 2].map(() =>
          service.verifyAndComplete(
            challenge.challengeId,
            deliveredCode,
            PhoneChallengePurpose.REGISTRATION,
            async (_, tx) => sessions.create(user, tx),
          ),
        ),
      );
      expect(
        results.filter((result) => result.status === "fulfilled"),
      ).toHaveLength(1);
      expect(
        await prisma.authenticationSession.count({
          where: { userId: user.id },
        }),
      ).toBe(1);
    } finally {
      await prisma.phoneChallenge.deleteMany({ where: { userId: user.id } });
      await prisma.user.delete({ where: { id: user.id } });
    }
  });

  it("enforces protected-email uniqueness and Provider consistency", async () => {
    const lookup = Buffer.from(randomUUID()).toString("base64url");
    const base = {
      encryptedEmail: "v1.synthetic.encrypted.payload",
      emailLookup: lookup,
      passwordHash: "$argon2id$synthetic-not-usable",
      actorType: ActorType.CLIENT,
      emailVerifiedAt: new Date(),
    };
    const user = await prisma.user.create({ data: base, select: { id: true } });
    try {
      await expect(prisma.user.create({ data: base })).rejects.toBeDefined();
      await expect(
        prisma.user.create({
          data: {
            ...base,
            emailLookup: Buffer.from(randomUUID()).toString("base64url"),
            actorType: ActorType.SERVICE_PROVIDER,
          },
        }),
      ).rejects.toBeDefined();
    } finally {
      await prisma.user.delete({ where: { id: user.id } });
    }
  });

  it("cascades sessions and hashed refresh tokens with user cleanup", async () => {
    const user = await prisma.user.create({
      data: {
        encryptedEmail: "v1.synthetic.encrypted.payload",
        emailLookup: Buffer.from(randomUUID()).toString("base64url"),
        passwordHash: "$argon2id$synthetic-not-usable",
        actorType: ActorType.CLIENT,
        emailVerifiedAt: new Date(),
      },
      select: { id: true },
    });
    const session = await prisma.authenticationSession.create({
      data: {
        userId: user.id,
        familyId: randomUUID(),
        passwordVersion: 1,
        absoluteExpiresAt: new Date(Date.now() + 60_000),
        refreshTokens: {
          create: {
            tokenHash: Buffer.from(randomUUID()).toString("base64url"),
            expiresAt: new Date(Date.now() + 60_000),
          },
        },
      },
      select: { id: true },
    });
    await prisma.user.delete({ where: { id: user.id } });
    await expect(
      prisma.authenticationSession.count({ where: { id: session.id } }),
    ).resolves.toBe(0);
    await expect(
      prisma.refreshToken.count({ where: { sessionId: session.id } }),
    ).resolves.toBe(0);
  });

  it("allows two processors to compete without delivering one event twice", async () => {
    const event = await prisma.outboxEvent.create({
      data: {
        channel: NotificationDeliveryChannel.IN_APP,
        eventType: OperationalNotificationType.REMINDER,
        deduplicationKey: `integration:${randomUUID()}`,
        payload: { kind: "synthetic" },
      },
      select: { id: true },
    });
    const config = {
      batchSize: 1,
      pollIntervalMilliseconds: 100,
      claimLeaseSeconds: 30,
      maxAttempts: 3,
      backoffBaseSeconds: 1,
      backoffMaximumSeconds: 10,
      retentionDays: 1,
    };
    const dependency = {} as never;
    const first = new DeliveryProcessor(
      prisma as never,
      dependency,
      dependency,
      dependency,
      dependency,
      dependency,
      dependency,
      dependency,
      config,
    );
    const second = new DeliveryProcessor(
      prisma as never,
      dependency,
      dependency,
      dependency,
      dependency,
      dependency,
      dependency,
      dependency,
      config,
    );
    try {
      const claimed = await Promise.all([
        first.processBatch(),
        second.processBatch(),
      ]);
      expect(claimed.reduce((sum, value) => sum + value, 0)).toBe(1);
      await expect(
        prisma.outboxEvent.findUniqueOrThrow({ where: { id: event.id } }),
      ).resolves.toMatchObject({
        status: OutboxStatus.DELIVERED,
        attempts: 1,
      });
      await expect(
        prisma.deliveryAttempt.count({ where: { outboxEventId: event.id } }),
      ).resolves.toBe(1);
    } finally {
      await prisma.outboxEvent.delete({ where: { id: event.id } });
    }
  });
});

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

const runtimeUrl = process.env.TEST_DATABASE_URL;
const directUrl = process.env.TEST_DIRECT_URL;
const describePostgres = runtimeUrl && directUrl ? describe : describe.skip;

describePostgres("opt-in isolated PostgreSQL migration and constraints", () => {
  jest.setTimeout(60_000);
  let prisma: PrismaClient;

  beforeAll(async () => {
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

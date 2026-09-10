import { HttpException, UnauthorizedException } from "@nestjs/common";

import { Test } from "@nestjs/testing";
import {
  FastifyAdapter,
  NestFastifyApplication,
} from "@nestjs/platform-fastify";
import { AuthController } from "../src/auth/auth.controller";
import { AuthService } from "../src/auth/auth.service";
import { SessionService } from "../src/auth/session.service";
import { SignedAccessTokenGuard } from "../src/auth/signed-access-token.guard";
import { RegistrationController } from "../src/registration/registration.controller";
import { RegistrationService } from "../src/registration/registration.service";
import { DevelopmentFakeSmsGateway } from "../src/registration/sms-gateway";

import { PrismaService } from "../src/database/prisma.service";
import {
  PhoneChallengeDeliveryStatus,
  PhoneChallengePurpose,
} from "../src/generated/prisma/enums";
import { PhoneChallengeService } from "../src/registration/phone-challenge.service";
import { PhoneSecurityService } from "../src/registration/phone-security.service";
import { SmsGateway } from "../src/registration/sms-gateway";
import { testAuthConfig } from "./support/auth-config";

describe("PhoneChallengeService", () => {
  function harness({ recent = 0, deliveryFails = false } = {}) {
    let stored: Record<string, unknown> | null = null;
    let deliveredCode: string | null = null;
    const phoneChallenge = {
      findFirst: jest.fn().mockResolvedValue(null),
      count: jest.fn().mockResolvedValue(recent),
      create: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
        stored = {
          ...data,
          consumedAt: null,
          deliveryStatus: PhoneChallengeDeliveryStatus.PENDING,
        };
        return stored;
      }),
      findUnique: jest.fn(async () => stored),
      update: jest.fn(async ({ data }: { data: Record<string, unknown> }) => {
        stored = { ...stored, ...data };
        return stored;
      }),
      updateMany: jest.fn(
        async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: Record<string, unknown>;
        }) => {
          if (where.id && stored?.id !== where.id) return { count: 0 };
          if (stored && where.consumedAt === null && stored.consumedAt !== null)
            return { count: 0 };
          if (
            stored &&
            where.attemptsRemaining &&
            Number(stored.attemptsRemaining) <= 0
          )
            return { count: 0 };
          if (stored && "attemptsRemaining" in data)
            stored = {
              ...stored,
              attemptsRemaining: Number(stored.attemptsRemaining) - 1,
            };
          if (stored && "consumedAt" in data) stored = { ...stored, ...data };
          return { count: 1 };
        },
      ),
    };
    const prisma = {
      phoneChallenge,
      $transaction: jest.fn(async (callback: (value: object) => unknown) =>
        callback({
          phoneChallenge,
          $queryRaw: jest.fn().mockResolvedValue([]),
        }),
      ),
    } as unknown as PrismaService;
    const phones = {
      lookup: jest.fn(() => "protected-phone-lookup"),
      encrypt: jest.fn(() => "encrypted-phone"),
      decrypt: jest.fn(() => "+256700000123"),
      mask: jest.fn(() => "+256 •••••• 123"),
    } as unknown as PhoneSecurityService;
    const sms = {
      sendVerificationCode: jest.fn(async (_phone: string, code: string) => {
        deliveredCode = code;
        if (deliveryFails) throw new Error("provider unavailable");
        return "provider-message-id";
      }),
    } as unknown as SmsGateway;
    const config = testAuthConfig();
    return {
      service: new PhoneChallengeService(prisma, phones, sms, config),
      phoneChallenge,
      sms,
      config,
      get stored() {
        return stored;
      },
      get deliveredCode() {
        return deliveredCode;
      },
    };
  }

  it.each([
    ["/v1/registrations/clients", PhoneChallengePurpose.REGISTRATION],
    ["/v1/registrations/service-providers", PhoneChallengePurpose.REGISTRATION],
    ["/v1/registrations/resend-phone-code", PhoneChallengePurpose.REGISTRATION],
    ["/v1/auth/client-code/request", PhoneChallengePurpose.CLIENT_SIGN_IN],
    ["/v1/auth/client-code/resend", PhoneChallengePurpose.CLIENT_SIGN_IN],
  ])(
    "%s never exposes an OTP even with fake acceptance",
    async (url, purpose) => {
      const value = harness();
      const fake = new DevelopmentFakeSmsGateway();
      jest
        .spyOn(value.sms, "sendVerificationCode")
        .mockImplementation((phone, code) =>
          fake.sendVerificationCode(phone, code),
        );
      const create = () =>
        value.service.create("+256700000123", purpose, "user-1");
      const resend = async () => {
        const initial = await create();
        await value.phoneChallenge.update({
          data: { resendAvailableAt: new Date(0) },
        });
        return value.service.resend(initial.challengeId, purpose);
      };
      const module = await Test.createTestingModule({
        controllers: [AuthController, RegistrationController],
        providers: [
          {
            provide: AuthService,
            useValue: { requestClientCode: create, resendClientCode: resend },
          },
          {
            provide: RegistrationService,
            useValue: {
              registerClient: create,
              registerServiceProvider: create,
              resendPhoneCode: resend,
            },
          },
          { provide: SessionService, useValue: {} },
        ],
      })
        .overrideGuard(SignedAccessTokenGuard)
        .useValue({ canActivate: () => true })
        .compile();
      const app = module.createNestApplication<NestFastifyApplication>(
        new FastifyAdapter(),
      );
      try {
        await app.init();
        const response = await app.inject({ method: "POST", url, payload: {} });
        expect(response.statusCode).toBe(
          url === "/v1/registrations/clients" ||
            url === "/v1/registrations/service-providers"
            ? 201
            : 200,
        );
        expect(Object.keys(response.json()).sort()).toEqual([
          "challengeId",
          "deliveryStatus",
          "expiresAt",
          "maskedPhone",
          "resendAvailableAt",
        ]);
        expect(response.json().deliveryStatus).toBe("SENT");
        expect(value.stored?.consumedAt).toBeNull();
      } finally {
        await app.close();
      }
    },
  );

  it("stores only a keyed code hash, sends six digits, and consumes once", async () => {
    const value = harness();
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.CLIENT_SIGN_IN,
      "user-1",
    );

    expect(challenge.deliveryStatus).toBe("SENT");
    expect(value.deliveredCode).toMatch(/^\d{6}$/);
    expect(value.stored?.codeHash).not.toBe(value.deliveredCode);
    expect(value.stored?.codeHash).toMatch(/^[A-Za-z0-9_-]{43}$/);
    await expect(
      value.service.verify(
        challenge.challengeId,
        value.deliveredCode!,
        PhoneChallengePurpose.CLIENT_SIGN_IN,
      ),
    ).resolves.toBe("user-1");
    expect(value.phoneChallenge.updateMany).toHaveBeenLastCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ consumedAt: null }),
      }),
    );
  });

  it("never exposes the sent code in a phone challenge response", async () => {
    const value = harness();
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );

    expect(Object.keys(challenge).sort()).toEqual([
      "challengeId",
      "deliveryStatus",
      "expiresAt",
      "maskedPhone",
      "resendAvailableAt",
    ]);
    expect(JSON.stringify(challenge)).not.toContain(value.deliveredCode);
  });

  it("returns a truthful failed-delivery state and rejects verification", async () => {
    const value = harness({ deliveryFails: true });
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );
    expect(challenge.deliveryStatus).toBe("FAILED");
    await expect(
      value.service.verify(
        challenge.challengeId,
        value.deliveredCode!,
        PhoneChallengePurpose.REGISTRATION,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("returns the release boundary and keeps failed sends in the hourly count", async () => {
    jest.useFakeTimers().setSystemTime(new Date("2026-09-10T10:00:00Z"));
    try {
      const value = harness({ recent: 5, deliveryFails: true });
      value.phoneChallenge.findFirst
        .mockResolvedValueOnce({ createdAt: new Date("2026-09-10T09:20:00Z") })
        .mockResolvedValueOnce({
          resendAvailableAt: new Date("2026-09-10T09:59:00Z"),
        });
      await expect(
        value.service.create(
          "+256700000123",
          PhoneChallengePurpose.REGISTRATION,
          "user-1",
        ),
      ).rejects.toMatchObject({
        response: {
          limitCategory: "OTP_HOURLY",
          retryAt: "2026-09-10T10:20:00.001Z",
        },
      });
      expect(value.phoneChallenge.count).toHaveBeenCalledWith({
        where: {
          phoneLookup: "protected-phone-lookup",
          purpose: PhoneChallengePurpose.REGISTRATION,
          createdAt: { gte: new Date("2026-09-10T09:00:00Z") },
        },
      });
      expect(value.sms.sendVerificationCode).not.toHaveBeenCalled();
    } finally {
      jest.useRealTimers();
    }
  });

  it("does not advertise a resend before a later hourly boundary", async () => {
    jest.useFakeTimers().setSystemTime(new Date("2026-09-10T10:00:00Z"));
    try {
      const value = harness();
      const challenge = await value.service.create(
        "+256700000123",
        PhoneChallengePurpose.REGISTRATION,
        "user-1",
      );
      value.phoneChallenge.findFirst
        .mockResolvedValueOnce({ createdAt: new Date("2026-09-10T09:20:00Z") })
        .mockResolvedValueOnce({
          resendAvailableAt: new Date(challenge.resendAvailableAt),
        });
      await expect(
        value.service.resend(challenge.challengeId),
      ).rejects.toMatchObject({
        response: { retryAt: "2026-09-10T10:20:00.001Z" },
      });
      expect(value.sms.sendVerificationCode).toHaveBeenCalledTimes(1);
    } finally {
      jest.useRealTimers();
    }
  });

  it("returns cooldown timing for initial requests and resends", async () => {
    jest.useFakeTimers().setSystemTime(new Date("2026-09-10T10:00:00Z"));
    try {
      const value = harness();
      const challenge = await value.service.create(
        "+256700000123",
        PhoneChallengePurpose.REGISTRATION,
        "user-1",
      );
      await expect(
        value.service.resend(challenge.challengeId),
      ).rejects.toMatchObject({
        response: {
          limitCategory: "OTP_COOLDOWN",
          retryAt: challenge.resendAvailableAt,
        },
      });
      value.phoneChallenge.findFirst.mockResolvedValueOnce({
        resendAvailableAt: new Date(challenge.resendAvailableAt),
      });
      await expect(
        value.service.create(
          "+256700000123",
          PhoneChallengePurpose.REGISTRATION,
          "user-1",
        ),
      ).rejects.toMatchObject({
        response: {
          limitCategory: "OTP_COOLDOWN",
          retryAt: challenge.resendAvailableAt,
        },
      });
      jest.advanceTimersByTime(60_000);
      await expect(
        value.service.resend(challenge.challengeId),
      ).resolves.toMatchObject({ deliveryStatus: "SENT" });
      expect(value.sms.sendVerificationCode).toHaveBeenCalledTimes(2);
    } finally {
      jest.useRealTimers();
    }
  });

  it("rate-limits excessive hourly code creation before sending", async () => {
    const value = harness({ recent: testAuthConfig().otpMaxRequestsPerHour });
    value.phoneChallenge.findFirst.mockResolvedValueOnce({
      createdAt: new Date(),
    });
    await expect(
      value.service.create(
        "+256700000123",
        PhoneChallengePurpose.CLIENT_SIGN_IN,
        null,
      ),
    ).rejects.toBeInstanceOf(HttpException);
    expect(value.sms.sendVerificationCode).not.toHaveBeenCalled();
  });

  it("isolates purposes, expiry and exhausted attempts", async () => {
    const value = harness();
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );
    await expect(
      value.service.verify(
        challenge.challengeId,
        value.deliveredCode!,
        PhoneChallengePurpose.CLIENT_SIGN_IN,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    const wrong = value.deliveredCode === "000000" ? "111111" : "000000";
    for (let i = 0; i < value.config.otpMaxAttempts; i++) {
      await expect(
        value.service.verify(
          challenge.challengeId,
          wrong,
          PhoneChallengePurpose.REGISTRATION,
        ),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    }
    await expect(
      value.service.verify(
        challenge.challengeId,
        value.deliveredCode!,
        PhoneChallengePurpose.REGISTRATION,
      ),
    ).rejects.toMatchObject({ status: 429 });
    expect(value.stored?.attemptsRemaining).toBe(0);
  });

  it("only completes one concurrent submission and preserves one-time use", async () => {
    const value = harness();
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );
    const complete = jest.fn(async () => "session");
    const results = await Promise.allSettled(
      [1, 2].map(() =>
        value.service.verifyAndComplete(
          challenge.challengeId,
          value.deliveredCode!,
          PhoneChallengePurpose.REGISTRATION,
          complete,
        ),
      ),
    );
    expect(
      results.filter((result) => result.status === "fulfilled"),
    ).toHaveLength(1);
    expect(complete).toHaveBeenCalledTimes(1);
    await expect(
      value.service.verify(
        challenge.challengeId,
        value.deliveredCode!,
        PhoneChallengePurpose.REGISTRATION,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("checks attempts in the final atomic consume even after a valid read", async () => {
    const value = harness();
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );
    value.phoneChallenge.updateMany.mockResolvedValueOnce({ count: 0 });
    const complete = jest.fn();
    await expect(
      value.service.verifyAndComplete(
        challenge.challengeId,
        value.deliveredCode!,
        PhoneChallengePurpose.REGISTRATION,
        complete,
      ),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(complete).not.toHaveBeenCalled();
    expect(value.phoneChallenge.updateMany).toHaveBeenLastCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          attemptsRemaining: { gt: 0 },
          expiresAt: { gt: expect.any(Date) },
        }),
      }),
    );
  });

  it("rejects expiry and resend cooldown without sending", async () => {
    const value = harness();
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );
    await expect(
      value.service.resend(
        challenge.challengeId,
        PhoneChallengePurpose.REGISTRATION,
      ),
    ).rejects.toMatchObject({ status: 400 });
    await value.phoneChallenge.update({ data: { expiresAt: new Date(0) } });
    await expect(
      value.service.verify(
        challenge.challengeId,
        value.deliveredCode!,
        PhoneChallengePurpose.REGISTRATION,
      ),
    ).rejects.toMatchObject({
      response: { code: "AUTH_VERIFICATION_EXPIRED" },
    });
    expect(value.sms.sendVerificationCode).toHaveBeenCalledTimes(1);
  });
});

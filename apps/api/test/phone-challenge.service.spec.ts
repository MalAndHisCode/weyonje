import { HttpException, UnauthorizedException } from "@nestjs/common";

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
  function harness({
    recent = 0,
    deliveryFails = false,
    fakeSms = false,
  } = {}) {
    let stored: Record<string, unknown> | null = null;
    let deliveredCode: string | null = null;
    const phoneChallenge = {
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
        async ({ data }: { data: Record<string, unknown> }) => {
          if (stored && "consumedAt" in data) stored = { ...stored, ...data };
          return { count: 1 };
        },
      ),
    };
    const prisma = {
      phoneChallenge,
      $transaction: jest.fn(async (callback: (value: object) => unknown) =>
        callback({ phoneChallenge }),
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
    const smsConfiguration = {
      provider: fakeSms ? "FAKE" : "AFRICAS_TALKING",
      username: "",
      apiKey: "",
      senderId: "",
      baseUrl: "",
      timeoutMilliseconds: 8_000,
    } as const;
    return {
      service: new PhoneChallengeService(
        prisma,
        phones,
        sms,
        config,
        smsConfiguration,
      ),
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

  it("returns the code only when the guarded development fake is selected", async () => {
    const value = harness({ fakeSms: true });
    const challenge = await value.service.create(
      "+256700000123",
      PhoneChallengePurpose.REGISTRATION,
      "user-1",
    );

    expect(challenge.developmentVerificationCode).toBe(value.deliveredCode);
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

  it("rate-limits excessive hourly code creation before sending", async () => {
    const value = harness({ recent: testAuthConfig().otpMaxRequestsPerHour });
    await expect(
      value.service.create(
        "+256700000123",
        PhoneChallengePurpose.CLIENT_SIGN_IN,
        null,
      ),
    ).rejects.toBeInstanceOf(HttpException);
    expect(value.sms.sendVerificationCode).not.toHaveBeenCalled();
  });
});

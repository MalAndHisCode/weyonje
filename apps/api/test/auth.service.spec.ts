import { HttpException } from "@nestjs/common";
import { testAuthConfig } from "./support/auth-config";
import { ApiErrorCode } from "@weyonje/contracts";

import { AuthService } from "../src/auth/auth.service";
import { EmailSecurityService } from "../src/auth/email-security.service";
import { LoginThrottleService } from "../src/auth/login-throttle.service";
import { PasswordService } from "../src/auth/password.service";
import { SessionService } from "../src/auth/session.service";
import { PrismaService } from "../src/database/prisma.service";
import { PhoneChallengeService } from "../src/registration/phone-challenge.service";
import { PhoneSecurityService } from "../src/registration/phone-security.service";

function harness(user: object | null, passwordValid = false) {
  const prisma = {
    user: {
      findUnique: jest.fn().mockResolvedValue(user),
      update: jest.fn().mockResolvedValue({}),
    },
  } as unknown as PrismaService;
  const emails = {
    normalize: jest.fn((value: string) => value.trim().toLowerCase()),
    lookup: jest.fn(() => "protected-lookup"),
  } as unknown as EmailSecurityService;
  const passwords = {
    verify: jest.fn().mockResolvedValue(passwordValid),
    verifyDummy: jest.fn().mockResolvedValue(undefined),
    needsUpgrade: jest.fn().mockReturnValue(false),
    hash: jest.fn(),
  } as unknown as PasswordService;
  const throttles = {
    assertAllowed: jest.fn().mockResolvedValue(undefined),
    recordFailure: jest.fn().mockResolvedValue(undefined),
    consumeProviderRequest: jest.fn().mockResolvedValue(undefined),
    consumeClientRequest: jest.fn().mockResolvedValue(undefined),
    recordSuccess: jest.fn().mockResolvedValue(undefined),
  } as unknown as LoginThrottleService;
  const sessions = {
    create: jest.fn().mockResolvedValue({ accessToken: "not-logged" }),
  } as unknown as SessionService;
  const phones = new PhoneSecurityService(testAuthConfig());
  const challenges = {
    nextRequestAvailableAt: jest.fn().mockResolvedValue({
      retryAt: new Date("2026-09-10T11:00:00Z"),
      hourlyLimited: true,
    }),
    create: jest.fn().mockResolvedValue({ challengeId: "challenge" }),
  } as unknown as PhoneChallengeService;
  return {
    service: new AuthService(
      prisma,
      emails,
      passwords,
      throttles,
      sessions,
      phones,
      challenges,
    ),
    passwords,
    throttles,
    sessions,
    prisma,
    challenges,
    phones,
  };
}

describe("AuthService", () => {
  it("combines the request throttle with the later hourly issuance deadline", async () => {
    const h = harness(null);
    jest.mocked(h.throttles.consumeClientRequest).mockRejectedValue(
      new HttpException(
        {
          code: ApiErrorCode.rateLimited,
          limitCategory: "CLIENT_REQUEST",
          retryAt: "2026-09-10T10:15:00Z",
        },
        429,
      ),
    );
    await expect(
      h.service.requestClientCode("0700000123", "192.0.2.1"),
    ).rejects.toMatchObject({
      response: {
        retryAt: "2026-09-10T11:00:00.000Z",
        limitCategory: "CLIENT_REQUEST",
      },
    });
    expect(h.challenges.create).not.toHaveBeenCalled();
  });
  it.each(["0700 000123", "+256700000123"])(
    "branches absent normalized phone %s without creating a challenge or account",
    async (phone) => {
      const h = harness(null);
      await expect(
        h.service.requestClientCode(phone, "192.0.2.1"),
      ).resolves.toEqual({ outcome: "REGISTRATION_REQUIRED" });
      expect(h.prisma.user.findUnique).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { phoneLookup: h.phones.lookup("+256700000123") },
        }),
      );
      expect(h.throttles.consumeClientRequest).toHaveBeenCalledTimes(1);
      expect(h.challenges.create).not.toHaveBeenCalled();
      expect(h.prisma.user.update).not.toHaveBeenCalled();
    },
  );
  it("continues eligible Clients through the existing challenge", async () => {
    const h = harness({
      id: "client",
      actorType: "CLIENT",
      phoneVerifiedAt: new Date(),
      loginEnabled: true,
      isActive: true,
    });
    await expect(
      h.service.requestClientCode("0700000123", "192.0.2.1"),
    ).resolves.toEqual({ challengeId: "challenge" });
    expect(h.challenges.create).toHaveBeenCalledWith(
      "+256700000123",
      "CLIENT_SIGN_IN",
      "client",
    );
  });
  it.each([
    { phoneVerifiedAt: null, loginEnabled: false, isActive: false },
    { isActive: false },
    { loginEnabled: false },
    { actorType: "SERVICE_PROVIDER" },
    { actorType: "KCCA_STAFF" },
  ])(
    "does not register or issue a sign-in code for restricted state %j",
    async (state) => {
      const h = harness({
        id: "client",
        actorType: "CLIENT",
        phoneVerifiedAt: new Date(),
        loginEnabled: true,
        isActive: true,
        ...state,
      });
      await expect(
        h.service.requestClientCode("0700000123", "192.0.2.1"),
      ).rejects.toMatchObject({
        response: { code: ApiErrorCode.accessDenied },
      });
      expect(h.challenges.create).not.toHaveBeenCalled();
    },
  );
  it("enforces lookup throttling before reading an account", async () => {
    const h = harness(null);
    jest
      .mocked(h.throttles.consumeClientRequest)
      .mockRejectedValue(new Error("limited"));
    await expect(
      h.service.requestClientCode("0700000123", "192.0.2.1"),
    ).rejects.toThrow("limited");
    expect(h.prisma.user.findUnique).not.toHaveBeenCalled();
  });
  it.each(["APPROVED", "PENDING", "REJECTED", "INACTIVE"])(
    "issues a Provider code for permitted authentication in %s",
    async (providerStatus) => {
      const h = harness({
        id: "provider",
        actorType: "SERVICE_PROVIDER",
        phoneVerifiedAt: new Date(),
        loginEnabled: true,
        isActive: providerStatus === "APPROVED",
        providerStatus,
      });
      await expect(
        h.service.requestProviderCode("0700 000123", "192.0.2.1"),
      ).resolves.toEqual({ challengeId: "challenge" });
      expect(h.challenges.create).toHaveBeenCalledWith(
        "+256700000123",
        "PROVIDER_SIGN_IN",
        "provider",
      );
      expect(h.throttles.consumeProviderRequest).toHaveBeenCalledWith(
        h.phones.lookup("+256700000123"),
        "192.0.2.1",
      );
      expect(h.throttles.consumeClientRequest).not.toHaveBeenCalled();
      expect(h.prisma.user.update).not.toHaveBeenCalled();
    },
  );
  it.each([
    null,
    { actorType: "CLIENT" },
    { actorType: "KCCA_STAFF" },
    { actorType: "SERVICE_PROVIDER", phoneVerifiedAt: null },
    {
      actorType: "SERVICE_PROVIDER",
      phoneVerifiedAt: new Date(),
      loginEnabled: false,
    },
  ])(
    "rejects unknown, wrong-actor and ineligible Provider phone %j",
    async (user) => {
      const h = harness(user);
      await expect(
        h.service.requestProviderCode("0700000123", "192.0.2.1"),
      ).rejects.toMatchObject({
        response: {
          code: ApiErrorCode.accessDenied,
          message: expect.stringContaining("Service Provider Registration"),
        },
      });
      expect(h.challenges.create).not.toHaveBeenCalled();
    },
  );
  it("throttles Provider lookup before querying the account", async () => {
    const h = harness(null);
    jest
      .mocked(h.throttles.consumeProviderRequest)
      .mockRejectedValue(new Error("limited"));
    await expect(
      h.service.requestProviderCode("0700000123", "192.0.2.1"),
    ).rejects.toThrow("limited");
    expect(h.prisma.user.findUnique).not.toHaveBeenCalled();
  });
  it.each([true, false])(
    "rechecks Provider phone and login under a row lock before creating a session; eligible=%s",
    async (eligible) => {
      const h = harness(null);
      const tx = {
        $queryRaw: jest.fn().mockResolvedValue([]),
        user: {
          findFirst: jest
            .fn()
            .mockResolvedValue(
              eligible ? { id: "provider", passwordVersion: 1 } : null,
            ),
        },
      };
      h.challenges.verifyAndComplete = jest.fn(
        async (_id, _code, purpose, complete) => {
          expect(purpose).toBe("PROVIDER_SIGN_IN");
          return complete(
            "provider",
            tx as unknown as Parameters<
              Parameters<PhoneChallengeService["verifyAndComplete"]>[3]
            >[1],
            "registered-phone-lookup",
          );
        },
      );
      const result = h.service.verifyProviderCode("challenge", "001234");
      if (eligible)
        await expect(result).resolves.toEqual({ accessToken: "not-logged" });
      else await expect(result).rejects.toThrow();
      expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
      expect(tx.user.findFirst).toHaveBeenCalledWith({
        where: {
          id: "provider",
          phoneLookup: "registered-phone-lookup",
          actorType: "SERVICE_PROVIDER",
          phoneVerifiedAt: { not: null },
          loginEnabled: true,
        },
        select: { id: true, passwordVersion: true },
      });
      if (eligible)
        expect(h.sessions.create).toHaveBeenCalledWith(
          { id: "provider", passwordVersion: 1 },
          tx,
        );
      else expect(h.sessions.create).not.toHaveBeenCalled();
      expect(h.prisma.user.update).not.toHaveBeenCalled();
    },
  );
  const activeUser = {
    id: "user-1",
    passwordHash: "argon2-hash",
    passwordVersion: 1,
    actorType: "KCCA_STAFF",
    loginEnabled: true,
    emailVerifiedAt: new Date(),
    phoneVerifiedAt: null,
    authenticationLockedUntil: null,
  };

  it("uses dummy verification and the same generic failure for an unknown email", async () => {
    const { service, passwords, throttles } = harness(null);
    await expect(
      service.signIn("a@example.test", "wrong", "127.0.0.1"),
    ).rejects.toMatchObject({
      response: { code: ApiErrorCode.invalidCredentials },
    });
    expect(passwords.verifyDummy).toHaveBeenCalledWith("wrong");
    expect(throttles.recordFailure).toHaveBeenCalled();
  });

  it.each([
    [
      "historical Provider password",
      { ...activeUser, actorType: "SERVICE_PROVIDER" },
      true,
    ],
    ["incorrect password", activeUser, false],
    ["login disabled", { ...activeUser, loginEnabled: false }, true],
    ["unverified", { ...activeUser, emailVerifiedAt: null }, true],
    [
      "temporarily locked",
      {
        ...activeUser,
        authenticationLockedUntil: new Date(Date.now() + 60_000),
      },
      true,
    ],
  ])("returns one safe failure for %s", async (_name, user, valid) => {
    const { service } = harness(user, valid);
    await expect(
      service.signIn("a@example.test", "password", "127.0.0.1"),
    ).rejects.toMatchObject({
      response: { code: ApiErrorCode.invalidCredentials },
    });
  });

  it("clears failure state and creates a session after valid credentials", async () => {
    const { service, throttles, sessions } = harness(activeUser, true);
    await expect(
      service.signIn("a@example.test", "password", "127.0.0.1"),
    ).resolves.toEqual({ accessToken: "not-logged" });
    expect(throttles.recordSuccess).toHaveBeenCalledWith(
      "protected-lookup",
      "127.0.0.1",
      "user-1",
    );
    expect(sessions.create).toHaveBeenCalledWith(activeUser);
  });
});

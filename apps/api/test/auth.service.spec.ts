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
    recordSuccess: jest.fn().mockResolvedValue(undefined),
  } as unknown as LoginThrottleService;
  const sessions = {
    create: jest.fn().mockResolvedValue({ accessToken: "not-logged" }),
  } as unknown as SessionService;
  const phones = {} as PhoneSecurityService;
  const challenges = {} as PhoneChallengeService;
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
  };
}

describe("AuthService", () => {
  const activeUser = {
    id: "user-1",
    passwordHash: "argon2-hash",
    passwordVersion: 1,
    actorType: "SERVICE_PROVIDER",
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

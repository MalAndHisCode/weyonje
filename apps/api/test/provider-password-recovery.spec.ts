import { AccountChallengeMethod } from "@weyonje/contracts";
import { AccountSecurityService } from "../src/account-security/account-security.service";
import { ChallengeCodeService } from "../src/account-security/challenge-code.service";
import { EmailSecurityService } from "../src/auth/email-security.service";
import { PasswordService } from "../src/auth/password.service";
import { PrismaService } from "../src/database/prisma.service";
import { testAuthConfig } from "./support/auth-config";

function harness(actor: "SERVICE_PROVIDER" | "KCCA_STAFF") {
  const config = testAuthConfig();
  const codes = new ChallengeCodeService(config);
  const id = "d22c98b7-69df-4ebc-bcb9-819dc0192c58";
  const tx = {
    user: {
      findFirst: jest
        .fn()
        .mockResolvedValue(actor === "KCCA_STAFF" ? { id: "user" } : null),
      update: jest.fn(),
    },
    accountChallenge: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    authenticationSession: {
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: jest.fn(),
    },
    securityEvent: { create: jest.fn() },
  };
  const prisma = {
    user: tx.user,
    securityEvent: { count: jest.fn().mockResolvedValue(0), create: jest.fn() },
    accountChallenge: {
      findUnique: jest
        .fn()
        .mockResolvedValue({
          id,
          userId: "user",
          purpose: "PASSWORD_RECOVERY",
          user: { actorType: actor, emailLookup: "lookup" },
          subjectHash: "lookup",
          consumedAt: null,
          supersededAt: null,
          expiresAt: new Date(Date.now() + 60000),
          resendAvailableAt: new Date(0),
          attemptsRemaining: 5,
          secretHash: codes.hash(id, "001234"),
        }),
    },
    $transaction: jest.fn(async (complete: (tx: object) => Promise<unknown>) =>
      complete(tx),
    ),
  };
  const service = new AccountSecurityService(
    prisma as unknown as PrismaService,
    new EmailSecurityService(config),
    {
      hash: jest.fn().mockResolvedValue("test-hash"),
    } as unknown as PasswordService,
    codes,
    {
      challengeTtlSeconds: 600,
      resendSeconds: 60,
      maximumAttempts: 5,
      maximumRequestsPerHour: 5,
      emailProvider: "FAKE",
      environment: "test",
    },
    {
      provider: "FAKE",
      username: "",
      apiKey: "",
      senderId: "",
      baseUrl: "",
      timeoutMilliseconds: 8000,
    },
  );
  return { service, tx, prisma, id };
}

describe("Provider password recovery retirement", () => {
  it("returns non-enumerating recovery guidance without issuing a Provider challenge", async () => {
    const h = harness("SERVICE_PROVIDER");
    await expect(
      h.service.requestPasswordRecovery(
        "contact@example.test",
        AccountChallengeMethod.email,
      ),
    ).resolves.toHaveProperty("challengeId");
    expect(h.tx.user.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ actorType: "KCCA_STAFF" }),
      }),
    );
    expect(h.prisma.$transaction).not.toHaveBeenCalled();
  });
  it("rejects resending a historical Provider recovery challenge", async () => {
    const h = harness("SERVICE_PROVIDER");
    await expect(h.service.resendPasswordRecovery(h.id)).rejects.toThrow();
    expect(h.prisma.$transaction).not.toHaveBeenCalled();
  });
  it.each(["SERVICE_PROVIDER", "KCCA_STAFF"] as const)(
    "rechecks the recovery actor during completion: %s",
    async (actor) => {
      const h = harness(actor);
      const result = h.service.completePasswordRecovery(
        h.id,
        "001234",
        "long-test-password",
      );
      if (actor === "SERVICE_PROVIDER") {
        await expect(result).rejects.toThrow();
        expect(h.tx.user.update).not.toHaveBeenCalled();
        expect(h.tx.accountChallenge.updateMany).not.toHaveBeenCalled();
      } else {
        await expect(result).resolves.toEqual({ completed: true });
        expect(h.tx.user.update).toHaveBeenCalledWith(
          expect.objectContaining({
            data: expect.objectContaining({
              passwordHash: "test-hash",
              passwordVersion: { increment: 1 },
            }),
          }),
        );
        expect(h.tx.authenticationSession.updateMany).toHaveBeenCalled();
      }
    },
  );
});

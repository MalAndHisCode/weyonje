import { UnauthorizedException } from "@nestjs/common";

import { SessionService } from "../src/auth/session.service";
import { TokenService } from "../src/auth/token.service";
import { PrismaService } from "../src/database/prisma.service";
import { ActorType } from "../src/generated/prisma/enums";
import { testAuthConfig } from "./support/auth-config";

describe("SessionService refresh rotation", () => {
  it("rotates once and revokes the session when the consumed token is reused", async () => {
    const config = testAuthConfig();
    const tokenService = new TokenService(config);
    const raw = "r".repeat(64);
    const original = {
      id: "token-1",
      tokenHash: tokenService.hashRefreshToken(raw),
      usedAt: null as Date | null,
      revokedAt: null as Date | null,
      expiresAt: new Date(Date.now() + 60_000),
    };
    const session = {
      id: "session-1",
      userId: "user-1",
      revokedAt: null as Date | null,
      absoluteExpiresAt: new Date(Date.now() + 60_000),
      passwordVersion: 1,
      user: {
        id: "user-1",
        actorType: ActorType.CLIENT,
        providerStatus: null,
        isActive: true,
        loginEnabled: true,
        emailVerifiedAt: new Date(),
        mobileMonitoringPermitted: false,
        passwordVersion: 1,
      },
    };
    const refreshToken = {
      findUnique: jest.fn(
        async ({ where }: { where: { tokenHash: string } }) =>
          where.tokenHash === original.tokenHash
            ? { ...original, session }
            : null,
      ),
      create: jest.fn(async () => ({ id: "token-2" })),
      updateMany: jest.fn(
        async ({
          where,
          data,
        }: {
          where: { id?: string };
          data: { usedAt?: Date; revokedAt?: Date };
        }) => {
          if (where.id === original.id && original.usedAt === null) {
            original.usedAt = data.usedAt ?? null;
            return { count: 1 };
          }
          if (data.revokedAt) original.revokedAt = data.revokedAt;
          return { count: 1 };
        },
      ),
    };
    const authenticationSession = {
      update: jest.fn(async () => ({})),
      updateMany: jest.fn(async ({ data }: { data: { revokedAt?: Date } }) => {
        if (data.revokedAt) session.revokedAt = data.revokedAt;
        return { count: 1 };
      }),
    };
    const prisma = {
      refreshToken,
      authenticationSession,
      $transaction: jest.fn(async (operation: (tx: object) => unknown) =>
        operation({ refreshToken, authenticationSession }),
      ),
    } as unknown as PrismaService;
    const service = new SessionService(prisma, tokenService, config);

    const rotated = await service.refresh(raw);
    expect(rotated.refreshToken).not.toBe(raw);
    expect(original.usedAt).toBeInstanceOf(Date);

    await expect(service.refresh(raw)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(session.revokedAt).toBeInstanceOf(Date);
    expect(original.revokedAt).toBeInstanceOf(Date);
  });

  it("invalidates access when the password version changes", async () => {
    const config = testAuthConfig();
    const prisma = {
      authenticationSession: {
        findFirst: jest.fn().mockResolvedValue({
          id: "session-1",
          revokedAt: null,
          absoluteExpiresAt: new Date(Date.now() + 60_000),
          passwordVersion: 1,
          user: {
            id: "user-1",
            actorType: ActorType.CLIENT,
            providerStatus: null,
            isActive: true,
            loginEnabled: true,
            emailVerifiedAt: new Date(),
            mobileMonitoringPermitted: false,
            passwordVersion: 2,
          },
        }),
      },
    } as unknown as PrismaService;
    const service = new SessionService(
      prisma,
      new TokenService(config),
      config,
    );
    await expect(
      service.authenticateAccess("user-1", "session-1"),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it.each([
    ["revoked", new Date(), new Date(Date.now() + 60_000)],
    ["expired", null, new Date(Date.now() - 60_000)],
  ])("rejects a %s server session", async (_name, revokedAt, expiresAt) => {
    const config = testAuthConfig();
    const prisma = {
      authenticationSession: {
        findFirst: jest.fn().mockResolvedValue({
          id: "session-1",
          revokedAt,
          absoluteExpiresAt: expiresAt,
          passwordVersion: 1,
          user: {
            id: "user-1",
            actorType: ActorType.CLIENT,
            providerStatus: null,
            isActive: true,
            loginEnabled: true,
            emailVerifiedAt: new Date(),
            mobileMonitoringPermitted: false,
            passwordVersion: 1,
          },
        }),
      },
    } as unknown as PrismaService;
    const service = new SessionService(
      prisma,
      new TokenService(config),
      config,
    );
    await expect(
      service.authenticateAccess("user-1", "session-1"),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("revokes sign-out idempotently", async () => {
    const config = testAuthConfig();
    const authenticationSession = {
      updateMany: jest
        .fn()
        .mockResolvedValueOnce({ count: 1 })
        .mockResolvedValueOnce({ count: 0 }),
    };
    const refreshToken = {
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    };
    const prisma = {
      authenticationSession,
      refreshToken,
      $transaction: jest.fn(async (operation: (client: object) => unknown) =>
        operation({ authenticationSession, refreshToken }),
      ),
    } as unknown as PrismaService;
    const service = new SessionService(
      prisma,
      new TokenService(config),
      config,
    );

    await service.signOut("user-1", "session-1");
    await service.signOut("user-1", "session-1");

    expect(authenticationSession.updateMany).toHaveBeenCalledTimes(2);
    expect(refreshToken.updateMany).toHaveBeenCalledTimes(1);
  });
});

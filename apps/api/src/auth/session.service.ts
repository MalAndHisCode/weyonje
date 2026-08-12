import { Inject, Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode, SessionCredentialsContract } from "@weyonje/contracts";
import { randomUUID } from "node:crypto";

import { authConfig } from "../config/auth.config";
import { PrismaService } from "../database/prisma.service";
import { AuthenticatedActor } from "./authenticated-actor";
import { TokenService } from "./token.service";

const USER_SELECT = {
  id: true,
  actorType: true,
  providerStatus: true,
  isActive: true,
  loginEnabled: true,
  emailVerifiedAt: true,
  phoneVerifiedAt: true,
  mobileMonitoringPermitted: true,
  providerApprovalPermitted: true,
  passwordVersion: true,
  serviceProviderProfile: {
    select: {
      providerNumber: true,
      latestRejectionReason: true,
    },
  },
} as const;

@Injectable()
export class SessionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}

  async create(user: {
    id: string;
    passwordVersion: number;
  }): Promise<SessionCredentialsContract> {
    const now = new Date();
    const refreshExpiresAt = new Date(
      now.getTime() + this.config.refreshTokenTtlSeconds * 1000,
    );
    const refresh = this.tokens.generateRefreshToken();
    const session = await this.prisma.authenticationSession.create({
      data: {
        userId: user.id,
        familyId: randomUUID(),
        absoluteExpiresAt: refreshExpiresAt,
        passwordVersion: user.passwordVersion,
        refreshTokens: {
          create: { tokenHash: refresh.hash, expiresAt: refreshExpiresAt },
        },
      },
      select: { id: true },
    });
    const access = await this.tokens.issueAccessToken(user.id, session.id);
    return credentials(
      access.token,
      refresh.raw,
      access.expiresAt,
      refreshExpiresAt,
    );
  }

  async authenticateAccess(
    userId: string,
    sessionId: string,
  ): Promise<AuthenticatedActor> {
    const now = new Date();
    const session = await this.prisma.authenticationSession.findFirst({
      where: { id: sessionId, userId },
      select: {
        id: true,
        revokedAt: true,
        absoluteExpiresAt: true,
        passwordVersion: true,
        user: { select: USER_SELECT },
      },
    });
    if (
      !session ||
      session.revokedAt !== null ||
      session.absoluteExpiresAt <= now ||
      session.passwordVersion !== session.user.passwordVersion ||
      !session.user.loginEnabled ||
      !hasVerifiedCredential(session.user)
    ) {
      throw this.invalidSession();
    }
    return { sessionId: session.id, user: session.user };
  }

  async refresh(rawToken: string): Promise<SessionCredentialsContract> {
    if (rawToken.length < 32 || rawToken.length > 512) {
      throw this.invalidSession();
    }
    const tokenHash = this.tokens.hashRefreshToken(rawToken);
    const now = new Date();
    const next = this.tokens.generateRefreshToken();
    const result = await this.prisma.$transaction(async (transaction) => {
      const current = await transaction.refreshToken.findUnique({
        where: { tokenHash },
        select: {
          id: true,
          usedAt: true,
          revokedAt: true,
          expiresAt: true,
          session: {
            select: {
              id: true,
              userId: true,
              revokedAt: true,
              absoluteExpiresAt: true,
              passwordVersion: true,
              user: { select: USER_SELECT },
            },
          },
        },
      });
      if (!current) return { kind: "invalid" } as const;

      if (current.usedAt !== null) {
        await revokeSession(
          transaction,
          current.session.id,
          now,
          "refresh_reuse",
        );
        return { kind: "reuse" } as const;
      }
      if (
        current.revokedAt !== null ||
        current.expiresAt <= now ||
        current.session.revokedAt !== null ||
        current.session.absoluteExpiresAt <= now ||
        current.session.passwordVersion !==
          current.session.user.passwordVersion ||
        !current.session.user.loginEnabled ||
        !hasVerifiedCredential(current.session.user)
      ) {
        return { kind: "invalid" } as const;
      }

      const replacement = await transaction.refreshToken.create({
        data: {
          sessionId: current.session.id,
          tokenHash: next.hash,
          expiresAt: current.session.absoluteExpiresAt,
        },
        select: { id: true },
      });
      const consumed = await transaction.refreshToken.updateMany({
        where: { id: current.id, usedAt: null, revokedAt: null },
        data: { usedAt: now, replacedById: replacement.id },
      });
      if (consumed.count !== 1) {
        await revokeSession(
          transaction,
          current.session.id,
          now,
          "refresh_reuse",
        );
        return { kind: "reuse" } as const;
      }
      await transaction.authenticationSession.update({
        where: { id: current.session.id },
        data: { lastUsedAt: now },
      });
      return {
        kind: "rotated",
        sessionId: current.session.id,
        userId: current.session.userId,
        refreshExpiresAt: current.session.absoluteExpiresAt,
      } as const;
    });

    if (result.kind !== "rotated") throw this.invalidSession();
    const access = await this.tokens.issueAccessToken(
      result.userId,
      result.sessionId,
    );
    return credentials(
      access.token,
      next.raw,
      access.expiresAt,
      result.refreshExpiresAt,
    );
  }

  async signOut(userId: string, sessionId: string): Promise<void> {
    const now = new Date();
    await this.prisma.$transaction(async (transaction) => {
      const updated = await transaction.authenticationSession.updateMany({
        where: { id: sessionId, userId, revokedAt: null },
        data: { revokedAt: now, revocationReason: "signed_out" },
      });
      if (updated.count > 0) {
        await transaction.refreshToken.updateMany({
          where: { sessionId, revokedAt: null },
          data: { revokedAt: now },
        });
      }
    });
  }

  private invalidSession(): UnauthorizedException {
    return new UnauthorizedException({
      code: ApiErrorCode.invalidSession,
      message: "The session is invalid or has expired. Sign in again.",
    });
  }
}

function hasVerifiedCredential(user: {
  emailVerifiedAt: Date | null;
  phoneVerifiedAt: Date | null;
}): boolean {
  return user.emailVerifiedAt !== null || user.phoneVerifiedAt !== null;
}

type TransactionClient = Parameters<
  Parameters<PrismaService["$transaction"]>[0]
>[0];

async function revokeSession(
  transaction: TransactionClient,
  sessionId: string,
  now: Date,
  reason: string,
): Promise<void> {
  await transaction.authenticationSession.updateMany({
    where: { id: sessionId, revokedAt: null },
    data: { revokedAt: now, revocationReason: reason },
  });
  await transaction.refreshToken.updateMany({
    where: { sessionId, revokedAt: null },
    data: { revokedAt: now },
  });
}

function credentials(
  accessToken: string,
  refreshToken: string,
  accessTokenExpiresAt: Date,
  refreshTokenExpiresAt: Date,
): SessionCredentialsContract {
  return {
    accessToken,
    refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt.toISOString(),
    refreshTokenExpiresAt: refreshTokenExpiresAt.toISOString(),
  };
}

import { HttpException, HttpStatus, Inject, Injectable } from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import { createHmac } from "node:crypto";

import { authConfig } from "../config/auth.config";
import { PrismaService } from "../database/prisma.service";
import { ThrottleScope } from "../generated/prisma/enums";

interface MemoryAttempt {
  failures: number;
  windowStartedAt: number;
  lockedUntil: number;
}

@Injectable()
export class LoginThrottleService {
  private readonly ipAttempts = new Map<string, MemoryAttempt>();
  private readonly maximumMemoryEntries = 2_048;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(authConfig.KEY)
    private readonly config: ConfigType<typeof authConfig>,
  ) {}

  // Separate namespaces preserve password-login counters. Consume before lookup,
  // under locks, so absent phones and concurrent requests cannot evade protection.
  async consumeClientRequest(
    phoneLookup: string,
    sourceIp: string,
  ): Promise<void> {
    await this.prisma.$transaction(async (transaction) => {
      const keys = [
        [
          ThrottleScope.IP,
          this.key("client-request-ip", sourceIp),
          this.config.ipMaxAttempts,
        ],
        [
          ThrottleScope.EMAIL,
          this.key("client-request-phone", phoneLookup),
          this.config.accountMaxAttempts,
        ],
      ] as const;
      for (const [, key] of keys) {
        await transaction.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${key}, 0))::text`;
      }
      const now = new Date();
      const rows = await Promise.all(
        keys.map(([scope, keyHash]) =>
          transaction.loginThrottle.findUnique({
            where: { scope_keyHash: { scope, keyHash } },
          }),
        ),
      );
      const retryAt = rows.reduce(
        (latest, row) => Math.max(latest, row?.lockedUntil?.getTime() ?? 0),
        0,
      );
      if (retryAt > now.getTime())
        throw new HttpException(
          {
            code: ApiErrorCode.rateLimited,
            message:
              "Too many Client sign-in requests. Please wait before trying again.",
            limitCategory: "CLIENT_REQUEST",
            retryAt: new Date(retryAt).toISOString(),
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      for (const [index, [scope, keyHash, maximum]] of keys.entries()) {
        const row = rows[index];
        const withinWindow =
          row &&
          now.getTime() - row.windowStartedAt.getTime() <
            this.config.throttleWindowSeconds * 1000;
        const failedAttempts = withinWindow ? row.failedAttempts + 1 : 1;
        const data = {
          failedAttempts,
          windowStartedAt: withinWindow ? row.windowStartedAt : now,
          lockedUntil:
            failedAttempts >= maximum
              ? new Date(now.getTime() + this.config.lockSeconds * 1000)
              : null,
          expiresAt: new Date(
            now.getTime() +
              (this.config.throttleWindowSeconds + this.config.lockSeconds) *
                1000,
          ),
        };
        await transaction.loginThrottle.upsert({
          where: { scope_keyHash: { scope, keyHash } },
          create: { scope, keyHash, ...data },
          update: data,
        });
      }
    });
  }

  async assertAllowed(emailLookup: string, sourceIp: string): Promise<void> {
    const now = new Date();
    const keys = this.keys(emailLookup, sourceIp);
    this.pruneMemory(now.getTime());
    const memory = this.ipAttempts.get(keys.ip);
    if (memory && memory.lockedUntil > now.getTime()) throw this.rateLimited();

    await this.prisma.loginThrottle.deleteMany({
      where: { expiresAt: { lt: now } },
    });
    const blocked = await this.prisma.loginThrottle.findFirst({
      where: {
        OR: [
          { scope: ThrottleScope.EMAIL, keyHash: keys.email },
          { scope: ThrottleScope.IP, keyHash: keys.ip },
        ],
        lockedUntil: { gt: now },
      },
      select: { id: true },
    });
    if (blocked) throw this.rateLimited();
  }

  async recordFailure(
    emailLookup: string,
    sourceIp: string,
    userId?: string,
  ): Promise<void> {
    const now = new Date();
    const keys = this.keys(emailLookup, sourceIp);
    this.recordMemoryFailure(keys.ip, now.getTime());
    const windowMilliseconds = this.config.throttleWindowSeconds * 1000;
    const expiresAt = new Date(
      now.getTime() + windowMilliseconds + this.config.lockSeconds * 1000,
    );
    await this.prisma.$transaction(async (transaction) => {
      for (const [scope, keyHash, maximum] of [
        [ThrottleScope.EMAIL, keys.email, this.config.accountMaxAttempts],
        [ThrottleScope.IP, keys.ip, this.config.ipMaxAttempts],
      ] as const) {
        const existing = await transaction.loginThrottle.findUnique({
          where: { scope_keyHash: { scope, keyHash } },
        });
        const withinWindow =
          existing &&
          now.getTime() - existing.windowStartedAt.getTime() <
            windowMilliseconds;
        const failures = withinWindow ? existing.failedAttempts + 1 : 1;
        const windowStartedAt = withinWindow ? existing.windowStartedAt : now;
        const lockedUntil =
          failures >= maximum
            ? new Date(now.getTime() + this.config.lockSeconds * 1000)
            : null;
        await transaction.loginThrottle.upsert({
          where: { scope_keyHash: { scope, keyHash } },
          create: {
            scope,
            keyHash,
            failedAttempts: failures,
            windowStartedAt,
            lockedUntil,
            expiresAt,
          },
          update: {
            failedAttempts: failures,
            windowStartedAt,
            lockedUntil,
            expiresAt,
          },
        });
      }
      if (userId) {
        const user = await transaction.user.findUnique({
          where: { id: userId },
          select: { failedLoginCount: true },
        });
        if (user) {
          const failedLoginCount = user.failedLoginCount + 1;
          await transaction.user.update({
            where: { id: userId },
            data: {
              failedLoginCount,
              authenticationLockedUntil:
                failedLoginCount >= this.config.accountMaxAttempts
                  ? new Date(now.getTime() + this.config.lockSeconds * 1000)
                  : null,
            },
          });
        }
      }
    });
  }

  async recordSuccess(
    emailLookup: string,
    sourceIp: string,
    userId: string,
  ): Promise<void> {
    const keys = this.keys(emailLookup, sourceIp);
    this.ipAttempts.delete(keys.ip);
    await this.prisma.$transaction([
      this.prisma.loginThrottle.deleteMany({
        where: {
          OR: [
            { scope: ThrottleScope.EMAIL, keyHash: keys.email },
            { scope: ThrottleScope.IP, keyHash: keys.ip },
          ],
        },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: { failedLoginCount: 0, authenticationLockedUntil: null },
      }),
    ]);
  }

  private keys(emailLookup: string, sourceIp: string) {
    return {
      email: this.key("email", emailLookup),
      ip: this.key("ip", sourceIp),
    };
  }

  private key(scope: string, value: string): string {
    return createHmac("sha256", this.config.throttleHashKey)
      .update(`${scope}\0${value}`, "utf8")
      .digest("base64url");
  }

  private recordMemoryFailure(key: string, now: number): void {
    const windowMilliseconds = this.config.throttleWindowSeconds * 1000;
    const existing = this.ipAttempts.get(key);
    const failures =
      existing && now - existing.windowStartedAt < windowMilliseconds
        ? existing.failures + 1
        : 1;
    this.ipAttempts.set(key, {
      failures,
      windowStartedAt:
        existing && now - existing.windowStartedAt < windowMilliseconds
          ? existing.windowStartedAt
          : now,
      lockedUntil:
        failures >= this.config.ipMaxAttempts
          ? now + this.config.lockSeconds * 1000
          : 0,
    });
    if (this.ipAttempts.size > this.maximumMemoryEntries) {
      const oldest = this.ipAttempts.keys().next().value as string | undefined;
      if (oldest) this.ipAttempts.delete(oldest);
    }
  }

  private pruneMemory(now: number): void {
    const maximumAge =
      (this.config.throttleWindowSeconds + this.config.lockSeconds) * 1000;
    for (const [key, value] of this.ipAttempts) {
      if (now - value.windowStartedAt > maximumAge) this.ipAttempts.delete(key);
    }
  }

  private rateLimited(): HttpException {
    return new HttpException(
      {
        code: ApiErrorCode.rateLimited,
        message: "Too many sign-in attempts. Wait briefly and try again.",
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}

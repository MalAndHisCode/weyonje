import { HttpException } from "@nestjs/common";

import { LoginThrottleService } from "../src/auth/login-throttle.service";
import { PrismaService } from "../src/database/prisma.service";
import { ThrottleScope } from "../src/generated/prisma/enums";
import { testAuthConfig } from "./support/auth-config";

describe("LoginThrottleService", () => {
  beforeEach(() =>
    jest.useFakeTimers().setSystemTime(new Date("2026-09-10T10:00:00Z")),
  );
  afterEach(() => jest.useRealTimers());
  it.each([false, true])(
    "protects identifiers and enforces both bounded limits, client request=%s",
    async (clientRequest) => {
      const records = new Map<
        string,
        {
          id: string;
          scope: ThrottleScope;
          keyHash: string;
          failedAttempts: number;
          windowStartedAt: Date;
          lockedUntil: Date | null;
          expiresAt: Date;
        }
      >();
      const key = (scope: ThrottleScope, keyHash: string) =>
        `${scope}:${keyHash}`;
      const loginThrottle = {
        deleteMany: jest.fn(async () => ({ count: 0 })),
        findFirst: jest.fn(async () =>
          [...records.values()].find(
            (record) =>
              record.lockedUntil && record.lockedUntil.getTime() > Date.now(),
          ),
        ),
        findUnique: jest.fn(
          async ({
            where,
          }: {
            where: {
              scope_keyHash: { scope: ThrottleScope; keyHash: string };
            };
          }) =>
            records.get(
              key(where.scope_keyHash.scope, where.scope_keyHash.keyHash),
            ) ?? null,
        ),
        upsert: jest.fn(
          async ({
            where,
            create,
            update,
          }: {
            where: {
              scope_keyHash: { scope: ThrottleScope; keyHash: string };
            };
            create: typeof records extends Map<string, infer V> ? V : never;
            update: Partial<
              typeof records extends Map<string, infer V> ? V : never
            >;
          }) => {
            const recordKey = key(
              where.scope_keyHash.scope,
              where.scope_keyHash.keyHash,
            );
            const previous = records.get(recordKey);
            records.set(
              recordKey,
              previous
                ? { ...previous, ...update }
                : { ...create, id: recordKey },
            );
          },
        ),
      };
      const user = {
        findUnique: jest.fn().mockResolvedValue({ failedLoginCount: 0 }),
        update: jest.fn().mockResolvedValue({}),
      };
      const prisma = {
        loginThrottle,
        user,
        $transaction: jest.fn(async (operation: (client: object) => unknown) =>
          operation({
            loginThrottle,
            user,
            $queryRaw: jest.fn().mockResolvedValue([]),
          }),
        ),
      } as unknown as PrismaService;
      const service = new LoginThrottleService(
        prisma,
        testAuthConfig({ accountMaxAttempts: 3, ipMaxAttempts: 3 }),
      );

      for (let attempt = 0; attempt < 3; attempt++) {
        if (clientRequest)
          await service.consumeClientRequest(
            "protected-email-lookup",
            "198.51.100.24",
          );
        else
          await service.recordFailure(
            "protected-email-lookup",
            "198.51.100.24",
            "user-1",
          );
      }

      expect([...records.values()]).toHaveLength(2);
      for (const record of records.values()) {
        expect(record.keyHash).not.toContain("protected-email-lookup");
        expect(record.keyHash).not.toContain("198.51.100.24");
        expect(record.keyHash).toMatch(/^[A-Za-z0-9_-]{43}$/);
        expect(record.lockedUntil).toBeInstanceOf(Date);
      }
      await expect(
        clientRequest
          ? service.consumeClientRequest(
              "protected-email-lookup",
              "198.51.100.24",
            )
          : service.assertAllowed("protected-email-lookup", "198.51.100.24"),
      ).rejects.toBeInstanceOf(HttpException);
      if (clientRequest) {
        await expect(
          service.consumeClientRequest(
            "protected-email-lookup",
            "198.51.100.24",
          ),
        ).rejects.toMatchObject({
          response: {
            limitCategory: "CLIENT_REQUEST",
            retryAt: expect.any(String),
          },
        });
        expect(user.update).not.toHaveBeenCalled();
        jest.advanceTimersByTime(testAuthConfig().lockSeconds * 1000);
        await expect(
          service.consumeClientRequest(
            "protected-email-lookup",
            "198.51.100.24",
          ),
        ).resolves.toBeUndefined();
      }
    },
  );
});

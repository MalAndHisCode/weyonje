import { AuthConfig } from "../../src/config/auth.config";

export function testAuthConfig(
  overrides: Partial<AuthConfig> = {},
): AuthConfig {
  return {
    issuer: "https://auth.example.test",
    audience: "weyonje-api-test",
    accessTokenSecret: Buffer.alloc(32, 1),
    accessTokenTtlSeconds: 600,
    refreshTokenTtlSeconds: 86_400,
    emailEncryptionKey: Buffer.alloc(32, 2),
    emailLookupKey: Buffer.alloc(32, 3),
    refreshTokenHashKey: Buffer.alloc(32, 4),
    throttleHashKey: Buffer.alloc(32, 5),
    accountMaxAttempts: 5,
    ipMaxAttempts: 20,
    throttleWindowSeconds: 900,
    lockSeconds: 900,
    ...overrides,
  };
}

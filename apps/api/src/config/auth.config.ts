import { registerAs } from "@nestjs/config";

import { decodeSecret, Environment, validateEnvironment } from "./environment";

export interface AuthConfig {
  issuer: string;
  audience: string;
  accessTokenSecret: Buffer;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  emailEncryptionKey: Buffer;
  emailLookupKey: Buffer;
  refreshTokenHashKey: Buffer;
  throttleHashKey: Buffer;
  accountMaxAttempts: number;
  ipMaxAttempts: number;
  throttleWindowSeconds: number;
  lockSeconds: number;
}

export function buildAuthConfig(env: Environment): AuthConfig {
  return {
    issuer: env.AUTH_ISSUER,
    audience: env.AUTH_AUDIENCE,
    accessTokenSecret: decodeRequired(env.ACCESS_TOKEN_SECRET),
    accessTokenTtlSeconds: env.ACCESS_TOKEN_TTL_SECONDS,
    refreshTokenTtlSeconds: env.REFRESH_TOKEN_TTL_SECONDS,
    emailEncryptionKey: decodeRequired(env.EMAIL_ENCRYPTION_KEY),
    emailLookupKey: decodeRequired(env.EMAIL_LOOKUP_KEY),
    refreshTokenHashKey: decodeRequired(env.REFRESH_TOKEN_HASH_KEY),
    throttleHashKey: decodeRequired(env.THROTTLE_HASH_KEY),
    accountMaxAttempts: env.AUTH_ACCOUNT_MAX_ATTEMPTS,
    ipMaxAttempts: env.AUTH_IP_MAX_ATTEMPTS,
    throttleWindowSeconds: env.AUTH_THROTTLE_WINDOW_SECONDS,
    lockSeconds: env.AUTH_LOCK_SECONDS,
  };
}

export const authConfig = registerAs("auth", () => {
  return buildAuthConfig(validateEnvironment(process.env));
});

function decodeRequired(value: string): Buffer {
  const decoded = decodeSecret(value, 32);
  if (!decoded) throw new Error("Validated authentication key is unavailable.");
  return decoded;
}

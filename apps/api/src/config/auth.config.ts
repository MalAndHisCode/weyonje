import { registerAs } from "@nestjs/config";

import { decodeSecret, Environment, validateEnvironment } from "./environment";

export interface AuthConfig {
  serviceProviderAutoApprovalEnabled: boolean;
  issuer: string;
  audience: string;
  accessTokenSecret: Buffer;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  emailEncryptionKey: Buffer;
  emailLookupKey: Buffer;
  piiEncryptionKey: Buffer;
  phoneLookupKey: Buffer;
  otpHashKey: Buffer;
  refreshTokenHashKey: Buffer;
  throttleHashKey: Buffer;
  accountMaxAttempts: number;
  ipMaxAttempts: number;
  throttleWindowSeconds: number;
  lockSeconds: number;
  otpTtlSeconds: number;
  otpResendSeconds: number;
  otpMaxAttempts: number;
  otpMaxRequestsPerHour: number;
}

export function buildAuthConfig(env: Environment): AuthConfig {
  return {
    serviceProviderAutoApprovalEnabled:
      env.SERVICE_PROVIDER_AUTO_APPROVAL_ENABLED,
    issuer: env.AUTH_ISSUER,
    audience: env.AUTH_AUDIENCE,
    accessTokenSecret: decodeRequired(env.ACCESS_TOKEN_SECRET),
    accessTokenTtlSeconds: env.ACCESS_TOKEN_TTL_SECONDS,
    refreshTokenTtlSeconds: env.REFRESH_TOKEN_TTL_SECONDS,
    emailEncryptionKey: decodeRequired(env.EMAIL_ENCRYPTION_KEY),
    emailLookupKey: decodeRequired(env.EMAIL_LOOKUP_KEY),
    piiEncryptionKey: decodeRequired(env.PII_ENCRYPTION_KEY),
    phoneLookupKey: decodeRequired(env.PHONE_LOOKUP_KEY),
    otpHashKey: decodeRequired(env.OTP_HASH_KEY),
    refreshTokenHashKey: decodeRequired(env.REFRESH_TOKEN_HASH_KEY),
    throttleHashKey: decodeRequired(env.THROTTLE_HASH_KEY),
    accountMaxAttempts: env.AUTH_ACCOUNT_MAX_ATTEMPTS,
    ipMaxAttempts: env.AUTH_IP_MAX_ATTEMPTS,
    throttleWindowSeconds: env.AUTH_THROTTLE_WINDOW_SECONDS,
    lockSeconds: env.AUTH_LOCK_SECONDS,
    otpTtlSeconds: env.OTP_TTL_SECONDS,
    otpResendSeconds: env.OTP_RESEND_SECONDS,
    otpMaxAttempts: env.OTP_MAX_ATTEMPTS,
    otpMaxRequestsPerHour: env.OTP_MAX_REQUESTS_PER_HOUR,
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

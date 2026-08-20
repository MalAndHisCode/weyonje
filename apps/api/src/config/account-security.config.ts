import { registerAs } from "@nestjs/config";

import { validateEnvironment } from "./environment";

export const accountSecurityConfig = registerAs("accountSecurity", () => {
  const env = validateEnvironment(process.env);
  return {
    challengeTtlSeconds: env.ACCOUNT_CHALLENGE_TTL_SECONDS,
    resendSeconds: env.ACCOUNT_CHALLENGE_RESEND_SECONDS,
    maximumAttempts: env.ACCOUNT_CHALLENGE_MAX_ATTEMPTS,
    maximumRequestsPerHour: env.ACCOUNT_CHALLENGE_MAX_REQUESTS_PER_HOUR,
    emailProvider: env.EMAIL_PROVIDER,
    environment: env.WEYONJE_ENVIRONMENT,
  };
});

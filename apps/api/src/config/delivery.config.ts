import { registerAs } from "@nestjs/config";

import { validateEnvironment } from "./environment";

export interface DeliveryConfig {
  batchSize: number;
  pollIntervalMilliseconds: number;
  claimLeaseSeconds: number;
  maxAttempts: number;
  backoffBaseSeconds: number;
  backoffMaximumSeconds: number;
  retentionDays: number;
}

export const deliveryConfig = registerAs("delivery", (): DeliveryConfig => {
  const env = validateEnvironment(process.env);
  return {
    batchSize: env.DELIVERY_BATCH_SIZE,
    pollIntervalMilliseconds: env.DELIVERY_POLL_INTERVAL_MILLISECONDS,
    claimLeaseSeconds: env.DELIVERY_CLAIM_LEASE_SECONDS,
    maxAttempts: env.DELIVERY_MAX_ATTEMPTS,
    backoffBaseSeconds: env.DELIVERY_BACKOFF_BASE_SECONDS,
    backoffMaximumSeconds: env.DELIVERY_BACKOFF_MAX_SECONDS,
    retentionDays: env.DELIVERY_RETENTION_DAYS,
  };
});

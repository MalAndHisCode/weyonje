import { registerAs } from "@nestjs/config";
import { LocationPolicyContract } from "@weyonje/contracts";

import { validateEnvironment } from "./environment";

export interface LocationConfig extends LocationPolicyContract {}

export const locationConfig = registerAs("location", (): LocationConfig => {
  const env = validateEnvironment(process.env);
  return {
    provisional: true,
    sampleIntervalSeconds: env.LOCATION_SAMPLE_INTERVAL_SECONDS,
    sampleDistanceMetres: env.LOCATION_SAMPLE_DISTANCE_METRES,
    arrivalRadiusMetres: env.LOCATION_ARRIVAL_RADIUS_METRES,
    arrivalMaximumAccuracyMetres: env.LOCATION_ARRIVAL_MAX_ACCURACY_METRES,
    staleAfterSeconds: env.LOCATION_STALE_AFTER_SECONDS,
    retentionDays: env.LOCATION_RETENTION_DAYS,
    backgroundTrackingEnabled: env.LOCATION_BACKGROUND_TRACKING_ENABLED,
    approvalNotice:
      "These provisional tracking values require KCCA approval before production use.",
  };
});

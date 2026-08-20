import { registerAs } from "@nestjs/config";
import { validateEnvironment } from "./environment";

export const pushConfig = registerAs("push", () => {
  const env = validateEnvironment(process.env);
  if (
    env.FCM_PROVIDER === "FIREBASE" &&
    (!env.FIREBASE_PROJECT_ID ||
      !env.FIREBASE_CLIENT_EMAIL ||
      !env.FIREBASE_PRIVATE_KEY)
  )
    throw new Error("Firebase push credentials are incomplete.");
  if (env.WEYONJE_ENVIRONMENT === "production" && env.FCM_PROVIDER === "FAKE")
    throw new Error("Fake push delivery is prohibited in production.");
  return {
    provider: env.FCM_PROVIDER,
    projectId: env.FIREBASE_PROJECT_ID,
    clientEmail: env.FIREBASE_CLIENT_EMAIL,
    privateKey: env.FIREBASE_PRIVATE_KEY.replaceAll("\\n", "\n"),
    environment: env.WEYONJE_ENVIRONMENT,
  };
});

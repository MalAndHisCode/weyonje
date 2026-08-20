import { registerAs } from "@nestjs/config";
import { validateEnvironment } from "./environment";

export const mapsConfig = registerAs("maps", () => {
  const env = validateEnvironment(process.env);
  return {
    serverApiKey: env.GOOGLE_MAPS_SERVER_API_KEY,
    timeoutMilliseconds: env.GOOGLE_MAPS_TIMEOUT_MILLISECONDS,
  };
});

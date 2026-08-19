import { registerAs } from "@nestjs/config";

export interface SmsConfig {
  provider: "FAKE" | "AFRICAS_TALKING";
  username: string;
  apiKey: string;
  senderId: string;
  baseUrl: string;
  timeoutMilliseconds: number;
}

export const smsConfig = registerAs("sms", (): SmsConfig => {
  const environment = process.env.WEYONJE_ENVIRONMENT?.trim();
  const provider = (
    process.env.SMS_PROVIDER ?? (environment === "production" ? "" : "FAKE")
  )
    .trim()
    .toUpperCase();
  if (provider !== "FAKE" && provider !== "AFRICAS_TALKING") {
    throw new Error("Invalid or missing configuration: SMS_PROVIDER");
  }
  if (provider === "FAKE") {
    if (environment === "production") {
      throw new Error(
        "Invalid configuration: SMS_PROVIDER=FAKE is prohibited in production",
      );
    }
    return {
      provider,
      username: "",
      apiKey: "",
      senderId: "",
      baseUrl: "",
      timeoutMilliseconds: 8_000,
    };
  }
  const baseUrl = process.env.AFRICASTALKING_API_BASE_URL ?? "";
  if (
    baseUrl !== "https://api.africastalking.com" &&
    baseUrl !== "https://api.sandbox.africastalking.com"
  ) {
    throw new Error(
      "Invalid or missing configuration: AFRICASTALKING_API_BASE_URL",
    );
  }
  const username = required("AFRICASTALKING_USERNAME");
  const apiKey = required("AFRICASTALKING_API_KEY");
  const senderId = required("AFRICASTALKING_SENDER_ID");
  return {
    provider,
    username,
    apiKey,
    senderId,
    baseUrl,
    timeoutMilliseconds: 8_000,
  };
});

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value || /<[^>]+>|placeholder|change[-_ ]?me/i.test(value)) {
    throw new Error(`Invalid or missing configuration: ${name}`);
  }
  return value;
}

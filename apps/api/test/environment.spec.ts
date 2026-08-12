import { validateEnvironment } from "../src/config/environment";

function validEnvironment() {
  return {
    NODE_ENV: "test",
    WEYONJE_ENVIRONMENT: "test",
    PORT: "3000",
    DATABASE_URL:
      "postgresql://runtime:private@db.test/weyonje?sslmode=require",
    DIRECT_URL: "postgresql://migrate:private@db.test/weyonje?sslmode=require",
    AUTH_ISSUER: "https://auth.example.test",
    AUTH_AUDIENCE: "weyonje-api-test",
    ACCESS_TOKEN_SECRET: Buffer.alloc(32, 1).toString("base64"),
    EMAIL_ENCRYPTION_KEY: Buffer.alloc(32, 2).toString("base64"),
    EMAIL_LOOKUP_KEY: Buffer.alloc(32, 3).toString("base64"),
    PII_ENCRYPTION_KEY: Buffer.alloc(32, 4).toString("base64"),
    PHONE_LOOKUP_KEY: Buffer.alloc(32, 5).toString("base64"),
    OTP_HASH_KEY: Buffer.alloc(32, 6).toString("base64"),
    REFRESH_TOKEN_HASH_KEY: Buffer.alloc(32, 7).toString("base64"),
    THROTTLE_HASH_KEY: Buffer.alloc(32, 8).toString("base64"),
    ACCESS_TOKEN_TTL_SECONDS: "600",
    REFRESH_TOKEN_TTL_SECONDS: "86400",
    AUTH_ACCOUNT_MAX_ATTEMPTS: "5",
    AUTH_IP_MAX_ATTEMPTS: "20",
    AUTH_THROTTLE_WINDOW_SECONDS: "900",
    AUTH_LOCK_SECONDS: "900",
    OTP_TTL_SECONDS: "600",
    OTP_RESEND_SECONDS: "60",
    OTP_MAX_ATTEMPTS: "5",
    OTP_MAX_REQUESTS_PER_HOUR: "5",
  };
}

describe("environment validation", () => {
  it("accepts separated, correctly sized keys", () => {
    expect(validateEnvironment(validEnvironment()).PORT).toBe(3000);
  });

  it("reports missing secrets without throwing a TypeError", () => {
    const environment = validEnvironment();
    delete (environment as Partial<typeof environment>).ACCESS_TOKEN_SECRET;

    expect(() => validateEnvironment(environment)).toThrow(
      "Invalid or missing configuration: ACCESS_TOKEN_SECRET",
    );
  });

  it.each([
    ["short key", { EMAIL_ENCRYPTION_KEY: Buffer.alloc(8).toString("base64") }],
    [
      "oversized encryption key",
      { EMAIL_ENCRYPTION_KEY: Buffer.alloc(64, 2).toString("base64") },
    ],
    [
      "reused key",
      { EMAIL_LOOKUP_KEY: Buffer.alloc(32, 2).toString("base64") },
    ],
    [
      "placeholder URL",
      { DATABASE_URL: "postgresql://user:pass@example.invalid/db" },
    ],
  ])("rejects %s", (_name, override) => {
    expect(() =>
      validateEnvironment({ ...validEnvironment(), ...override }),
    ).toThrow(/Invalid or missing configuration/);
  });
});

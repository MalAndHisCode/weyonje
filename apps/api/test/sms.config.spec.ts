import { smsConfig } from "../src/config/sms.config";

describe("SMS configuration", () => {
  const originalEnvironment = process.env;

  beforeEach(() => {
    process.env = { ...originalEnvironment };
    delete process.env.SMS_PROVIDER;
    delete process.env.SMS_ANDROID_APP_HASH;
    delete process.env.AFRICASTALKING_API_BASE_URL;
    delete process.env.AFRICASTALKING_USERNAME;
    delete process.env.AFRICASTALKING_API_KEY;
    delete process.env.AFRICASTALKING_SENDER_ID;
  });

  afterAll(() => {
    process.env = originalEnvironment;
  });

  it("defaults to the fake adapter in a development environment", () => {
    process.env.WEYONJE_ENVIRONMENT = "development";

    expect(smsConfig()).toMatchObject({ provider: "FAKE" });
  });

  it("prohibits the fake adapter in production", () => {
    process.env.WEYONJE_ENVIRONMENT = "production";
    process.env.SMS_PROVIDER = "FAKE";

    expect(() => smsConfig()).toThrow("prohibited in production");
  });

  it("requires authorised Africa's Talking configuration when selected", () => {
    process.env.WEYONJE_ENVIRONMENT = "development";
    process.env.SMS_PROVIDER = "AFRICAS_TALKING";

    expect(() => smsConfig()).toThrow("AFRICASTALKING_API_BASE_URL");
  });

  it("allows the provider default sender on the live route", () => {
    process.env.SMS_PROVIDER = "AFRICAS_TALKING";
    process.env.AFRICASTALKING_API_BASE_URL = "https://api.africastalking.com";
    process.env.AFRICASTALKING_USERNAME = "weyonje";
    process.env.AFRICASTALKING_API_KEY = "synthetic-key";
    expect(smsConfig().senderId).toBe("");
    process.env.AFRICASTALKING_SENDER_ID = "  ";
    expect(smsConfig().senderId).toBe("");
    process.env.AFRICASTALKING_SENDER_ID = "Weyonje";
    expect(smsConfig().senderId).toBe("Weyonje");
  });

  it("rejects unknown providers instead of falling back", () => {
    process.env.SMS_PROVIDER = "OTHER";
    expect(() => smsConfig()).toThrow("SMS_PROVIDER");
  });

  it("validates the optional trusted app hash even for development", () => {
    process.env.WEYONJE_ENVIRONMENT = "development";
    process.env.SMS_ANDROID_APP_HASH = "bad";
    expect(() => smsConfig()).toThrow("SMS_ANDROID_APP_HASH");
    process.env.SMS_ANDROID_APP_HASH = "AbCdef123+/";
    expect(smsConfig().androidAppHash).toBe("AbCdef123+/");
  });
});

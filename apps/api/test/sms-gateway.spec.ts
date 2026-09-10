import { AfricasTalkingSmsGateway } from "../src/registration/sms-gateway";
import { composeOtpMessage } from "../src/registration/otp-message";

const context = {
  challengeId: "73f3d97e-0f93-445d-bdbe-77abac7b42ac",
  ttlSeconds: 120,
};
const phone = "+256700000123";
const config = {
  provider: "AFRICAS_TALKING" as const,
  username: "sandbox",
  apiKey: "synthetic-key",
  senderId: "Weyonje",
  baseUrl: "https://api.sandbox.africastalking.com",
  timeoutMilliseconds: 10,
  androidAppHash: "AbCdef123+/",
};

describe("OTP SMS adapter", () => {
  afterEach(() => jest.restoreAllMocks());
  it("composes a bounded message with actual expiry, leading zero and trusted hash", () => {
    const message = composeOtpMessage(
      "001234",
      context.challengeId,
      120,
      config.androidAppHash,
    );
    expect(Buffer.byteLength(message)).toBeLessThanOrEqual(140);
    expect(message).toContain("Expires in 120s.");
    expect(message).toContain("Weyonje code: 001234");
    expect(message).toContain(`Ref: ${context.challengeId}`);
    expect(message.endsWith(config.androidAppHash)).toBe(true);
    expect(() =>
      composeOtpMessage("001234", context.challengeId, 120, "bad"),
    ).toThrow();
  });
  it.each([100, 101, 102])(
    "accepts explicit provider status %s for the intended recipient",
    async (statusCode) => {
      const send = jest.spyOn(globalThis, "fetch").mockResolvedValue(
        new Response(
          JSON.stringify({
            SMSMessageData: {
              Recipients: [
                { number: phone, messageId: "synthetic-id", statusCode },
              ],
            },
          }),
        ),
      );
      await expect(
        new AfricasTalkingSmsGateway(config).sendVerificationCode(
          phone,
          "001234",
          context,
        ),
      ).resolves.toBe("synthetic-id");
      const request = send.mock.calls[0]![1]!;
      expect(request.headers).toMatchObject({
        apiKey: "synthetic-key",
        "Content-Type": "application/x-www-form-urlencoded",
      });
      expect((request.body as URLSearchParams).get("username")).toBe("sandbox");
      expect((request.body as URLSearchParams).get("message")).toBe(
        composeOtpMessage(
          "001234",
          context.challengeId,
          120,
          config.androidAppHash,
        ),
      );
    },
  );
  it("omits from and accepts HTTP 201 with the provider default sender", async () => {
    const send = jest
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(
        new Response(
          JSON.stringify({
            SMSMessageData: {
              Recipients: [
                {
                  number: phone,
                  messageId: "synthetic-default-sender",
                  statusCode: 100,
                },
              ],
            },
          }),
          { status: 201 },
        ),
      );
    await expect(
      new AfricasTalkingSmsGateway({
        ...config,
        senderId: "",
      }).sendVerificationCode(phone, "001234", context),
    ).resolves.toBe("synthetic-default-sender");
    expect((send.mock.calls[0]![1]!.body as URLSearchParams).has("from")).toBe(
      false,
    );
    expect(send).toHaveBeenCalledTimes(1);
  });

  it.each([
    {},
    { SMSMessageData: { Recipients: [] } },
    {
      SMSMessageData: {
        Recipients: [{ messageId: "id", status: "Success", number: phone }],
      },
    },
    {
      SMSMessageData: {
        Recipients: [{ messageId: "id", statusCode: 500, number: phone }],
      },
    },
    {
      SMSMessageData: {
        Recipients: [
          { messageId: "id", statusCode: 101, number: "+256700000124" },
        ],
      },
    },
  ])(
    "rejects incomplete, rejected or wrong-recipient HTTP success safely",
    async (response) => {
      const send = jest
        .spyOn(globalThis, "fetch")
        .mockResolvedValue(new Response(JSON.stringify(response)));
      await expect(
        new AfricasTalkingSmsGateway(config).sendVerificationCode(
          phone,
          "001234",
          context,
        ),
      ).rejects.toMatchObject({ response: { code: "DEPENDENCY_UNAVAILABLE" } });
      expect(send).toHaveBeenCalledTimes(1);
    },
  );
  it("does not retry an ambiguous abort or expose the provider error", async () => {
    const send = jest
      .spyOn(globalThis, "fetch")
      .mockRejectedValue(new Error("sensitive provider response"));
    await expect(
      new AfricasTalkingSmsGateway(config).sendVerificationCode(
        phone,
        "001234",
        context,
      ),
    ).rejects.toMatchObject({
      response: {
        message:
          "SMS acceptance could not be confirmed. Wait before requesting a new code.",
      },
    });
    expect(send).toHaveBeenCalledTimes(1);
  });
});

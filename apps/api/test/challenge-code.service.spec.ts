import { ChallengeCodeService } from "../src/account-security/challenge-code.service";

describe("ChallengeCodeService", () => {
  const service = new ChallengeCodeService({
    otpHashKey: Buffer.alloc(32, 19),
  } as never);

  it("derives a stable six-digit code without persisting plaintext", () => {
    const id = "5a08a6f6-c4c0-448a-adff-4ba7f218c9de";
    const code = service.code(id);
    expect(code).toMatch(/^\d{6}$/);
    expect(service.code(id)).toBe(code);
    expect(service.hash(id, code)).not.toContain(code);
    expect(service.matches(id, code, service.hash(id, code))).toBe(true);
    expect(service.matches(id, "000000", service.hash(id, code))).toBe(
      code === "000000",
    );
  });

  it("domain-separates subject and challenge hashes", () => {
    const id = "5a08a6f6-c4c0-448a-adff-4ba7f218c9de";
    expect(service.subject(id)).not.toBe(service.hash(id, service.code(id)));
  });
});

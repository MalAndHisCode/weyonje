import { UnauthorizedException } from "@nestjs/common";

import { EmailSecurityService } from "../src/auth/email-security.service";
import { testAuthConfig } from "./support/auth-config";

describe("EmailSecurityService", () => {
  it("normalizes once and creates a deterministic keyed lookup", () => {
    const service = new EmailSecurityService(testAuthConfig());
    const normalized = service.normalize("  Usér@Example.COM  ");
    expect(normalized).toBe("usér@example.com");
    expect(service.lookup(normalized)).toBe(service.lookup(normalized));
    const otherKey = new EmailSecurityService(
      testAuthConfig({ emailLookupKey: Buffer.alloc(32, 8) }),
    );
    expect(otherKey.lookup(normalized)).not.toBe(service.lookup(normalized));
  });

  it("encrypts with fresh nonces and authenticates ciphertext", () => {
    const service = new EmailSecurityService(testAuthConfig());
    const first = service.encrypt("account@example.test");
    const second = service.encrypt("account@example.test");
    expect(first).not.toBe(second);
    expect(service.decrypt(first)).toBe("account@example.test");
    const tampered = first.split(".");
    const tag = Buffer.from(tampered[3]!, "base64url");
    tag[0] = tag[0]! ^ 1;
    tampered[3] = tag.toString("base64url");
    expect(() => service.decrypt(tampered.join("."))).toThrow(
      UnauthorizedException,
    );
  });

  it.each(["", "v2.a.b.c", "v1.bad.payload", "v1.@@.AA.AA"])(
    "rejects malformed payload %s",
    (payload) => {
      const service = new EmailSecurityService(testAuthConfig());
      expect(() => service.decrypt(payload)).toThrow(UnauthorizedException);
    },
  );
});

import { BadRequestException } from "@nestjs/common";

import { PhoneSecurityService } from "../src/registration/phone-security.service";
import { testAuthConfig } from "./support/auth-config";

describe("PhoneSecurityService", () => {
  it("normalizes valid Ugandan national and international numbers", () => {
    const service = new PhoneSecurityService(testAuthConfig());
    expect(service.normalize("0700 000 123")).toBe("+256700000123");
    expect(service.normalize("+256 700 000 123")).toBe("+256700000123");
  });

  it.each(["", "+254712345678", "12345"])(
    "rejects an invalid or non-Ugandan number %s",
    (phone) => {
      const service = new PhoneSecurityService(testAuthConfig());
      expect(() => service.normalize(phone)).toThrow(BadRequestException);
    },
  );

  it("uses independent lookup protection and fresh authenticated encryption", () => {
    const service = new PhoneSecurityService(testAuthConfig());
    const phone = "+256700000123";
    const first = service.encrypt(phone);
    const second = service.encrypt(phone);
    expect(first).not.toBe(second);
    expect(service.decrypt(first)).toBe(phone);
    expect(service.lookup(phone)).not.toContain(phone);
    expect(service.mask(phone)).toMatch(/^\+256 .+ 123$/);
  });
});

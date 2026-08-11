import { BadRequestException } from "@nestjs/common";

import {
  PASSWORD_MAX_BYTES,
  PasswordService,
} from "../src/auth/password.service";
import { testAuthConfig } from "./support/auth-config";

describe("PasswordService", () => {
  jest.setTimeout(30_000);
  const service = new PasswordService(testAuthConfig());

  it("hashes and verifies with Argon2id and unique salts", async () => {
    const password = "correct horse battery staple";
    const first = await service.hash(password);
    const second = await service.hash(password);
    expect(first).toContain("$argon2id$");
    expect(first).not.toBe(second);
    await expect(service.verify(first, password)).resolves.toBe(true);
    await expect(service.verify(first, "incorrect password")).resolves.toBe(
      false,
    );
    expect(service.needsUpgrade(first)).toBe(false);
  });

  it("rejects undersized provisioning passwords and oversized inputs", async () => {
    await expect(service.hash("too-short")).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(
      service.verify("hash", "x".repeat(PASSWORD_MAX_BYTES + 1)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("performs dummy verification for an unknown account", async () => {
    await expect(service.verifyDummy("not-the-account-password")).resolves.toBe(
      undefined,
    );
  });
});

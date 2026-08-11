import { UnauthorizedException } from "@nestjs/common";
import { SignJWT } from "jose";

import { TokenService } from "../src/auth/token.service";
import { testAuthConfig } from "./support/auth-config";

describe("TokenService", () => {
  const config = testAuthConfig();
  const service = new TokenService(config);

  it("issues minimal HS256 access claims and validates them", async () => {
    const issued = await service.issueAccessToken("user-1", "session-1");
    await expect(service.verifyAccessToken(issued.token)).resolves.toEqual({
      userId: "user-1",
      sessionId: "session-1",
    });
    expect(issued.token).not.toContain("email");
  });

  it.each<[string, { issuer?: string; audience?: string; secret?: Buffer }]>([
    ["issuer", { issuer: "https://wrong.example.test" }],
    ["audience", { audience: "wrong-audience" }],
    ["signature", { secret: Buffer.alloc(32, 9) }],
  ])("rejects an invalid %s", async (_name, override) => {
    const now = Math.floor(Date.now() / 1000);
    const token = await new SignJWT({ sid: "session-1" })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("user-1")
      .setIssuer(override.issuer ?? config.issuer)
      .setAudience(override.audience ?? config.audience)
      .setIssuedAt(now)
      .setExpirationTime(now + 60)
      .sign(override.secret ?? config.accessTokenSecret);
    await expect(service.verifyAccessToken(token)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it("rejects expired access tokens", async () => {
    const now = Math.floor(Date.now() / 1000);
    const token = await new SignJWT({ sid: "session-1" })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("user-1")
      .setIssuer(config.issuer)
      .setAudience(config.audience)
      .setIssuedAt(now - 120)
      .setExpirationTime(now - 60)
      .sign(config.accessTokenSecret);
    await expect(service.verifyAccessToken(token)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it.each([
    ["a future issue time", "HS256", 60, 120],
    ["the wrong algorithm", "HS384", 0, 60],
    ["an excessive lifetime", "HS256", 0, config.accessTokenTtlSeconds + 60],
  ])("rejects %s", async (_name, algorithm, issuedOffset, expiryOffset) => {
    const now = Math.floor(Date.now() / 1000);
    const token = await new SignJWT({ sid: "session-1" })
      .setProtectedHeader({ alg: algorithm })
      .setSubject("user-1")
      .setIssuer(config.issuer)
      .setAudience(config.audience)
      .setIssuedAt(now + (issuedOffset as number))
      .setExpirationTime(now + (expiryOffset as number))
      .sign(config.accessTokenSecret);
    await expect(service.verifyAccessToken(token)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});

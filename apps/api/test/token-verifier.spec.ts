import { UnauthorizedException } from "@nestjs/common";
import { exportJWK, generateKeyPair, SignJWT, createLocalJWKSet } from "jose";

import { IdentityConfig } from "../src/config/identity.config";
import { TokenVerifier } from "../src/identity/token-verifier";

describe("TokenVerifier", () => {
  const config: IdentityConfig = {
    issuer: "https://identity.example.test/realms/weyonje",
    jwksUri: "https://identity.example.test/certs",
    audience: "weyonje-api-test",
    algorithms: ["RS256"],
    roles: {
      client: "client",
      provider: "provider",
      kccaMobile: "kcca-mobile",
    },
  };
  let privateKey: Awaited<ReturnType<typeof generateKeyPair>>["privateKey"];
  let verifier: TokenVerifier;

  beforeAll(async () => {
    const pair = await generateKeyPair("RS256");
    privateKey = pair.privateKey;
    const jwk = await exportJWK(pair.publicKey);
    jwk.kid = "test-key";
    verifier = new TokenVerifier(config, createLocalJWKSet({ keys: [jwk] }));
  });

  async function token(
    overrides: {
      issuer?: string;
      audience?: string;
      subject?: string;
      expiresIn?: string | number;
    } = {},
  ) {
    let builder = new SignJWT({
      realm_access: { roles: ["client"] },
      resource_access: { "weyonje-api-test": { roles: ["resource-role"] } },
    })
      .setProtectedHeader({ alg: "RS256", kid: "test-key" })
      .setIssuer(overrides.issuer ?? config.issuer)
      .setAudience(overrides.audience ?? config.audience)
      .setIssuedAt()
      .setExpirationTime(overrides.expiresIn ?? "5m");
    if (overrides.subject !== "")
      builder = builder.setSubject(overrides.subject ?? "subject-1");
    return builder.sign(privateKey);
  }

  it("validates signature, issuer, audience, expiry, subject, and roles", async () => {
    await expect(verifier.verify(await token())).resolves.toEqual({
      subject: "subject-1",
      roles: new Set(["client", "resource-role"]),
    });
  });

  it.each([
    ["wrong issuer", { issuer: "https://identity.example.test/realms/other" }],
    ["wrong audience", { audience: "other-api" }],
    ["expired token", { expiresIn: Math.floor(Date.now() / 1000) - 60 }],
    ["missing subject", { subject: "" }],
  ])("rejects a %s with one safe contract", async (_name, overrides) => {
    await expect(
      verifier.verify(await token(overrides)),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});

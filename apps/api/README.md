# Weyonje API identity foundation

The API exposes `GET /v1/actors/me`. It verifies a Keycloak bearer token's signature, issuer, audience, allowed algorithm, expiry, and subject; then combines configured token roles with the Weyonje-owned `actor_profiles` linkage and eligibility record. The response contains only `actorType`, `access`, and provider `providerStatus` when applicable.

The API never accepts a mobile route name from identity data and defaults to denial for missing linkage, role mismatch, unknown values, inactive accounts, or absent KCCA mobile-monitoring permission.

## Configure and run

1. Copy the root `.env.example` to an ignored `.env`.
2. Replace all Keycloak and PostgreSQL placeholders. `KEYCLOAK_ISSUER` and `KEYCLOAK_JWKS_URI` must use HTTPS outside the isolated CI test.
3. Install dependencies from the repository root with `pnpm install`.
4. Run `pnpm --filter @weyonje/api migration:run`.
5. Start with `pnpm --filter @weyonje/api start:dev`.

Swagger UI is exposed at `/internal/docs` only outside production. The committed contract is `openapi/openapi.json`; update it with `pnpm openapi:generate` and verify it with `pnpm openapi:check`.

## Keycloak contract

An authorized identity administrator must configure:

- a realm represented by `KEYCLOAK_ISSUER`;
- an API audience represented by `KEYCLOAK_AUDIENCE`;
- RS256 signing (or another explicitly reviewed algorithm listed in `KEYCLOAK_ALLOWED_ALGORITHMS`);
- configurable Client, Service Provider, and KCCA mobile-monitor roles;
- a public mobile OIDC client with Standard Flow enabled, PKCE method `S256`, and no client secret; and
- the exact allow-listed redirect URI used by the Android build.

The API role names are configuration, not claims about an existing KCCA realm. KCCA identities must be externally provisioned; no staff self-registration is provided.

## Persistence

Migration `1786397000000-create-actor-profiles` creates one unique Keycloak-subject linkage and constrained actor/provider states. PostgreSQL stores no passwords or OIDC tokens. Provider approval/activation and KCCA provisioning workflows are not implemented by this slice; authorized administrators must populate and maintain the linkage through a separately approved operational process.

# Weyonje Current System State

> **Purpose:** Evidence-based snapshot of implemented repository reality. Requirements and proposed/external architecture are not treated as operational without code and validation evidence.

## Document control

| Field | Value |
| --- | --- |
| Document version | 3.0 |
| Last updated and verified | 2026-08-11 |
| Verified against | Local repository at `D:\Dev\weyonje`, branch `main`; no deployment, external service, or database was accessed or changed |
| System version | Mobile `0.1.0+1`; API and contracts `0.1.0` |

## Status legend

| Status | Meaning |
| --- | --- |
| **Implemented** | Present and validated in repository code. |
| **Partially Implemented** | A safe bounded capability exists while named downstream work remains. |
| **Not Implemented** | No functioning implementation is present. |
| **Deprecated** | Superseded and removed from the active foundation. |
| **Known Broken / Unstable** | Current evidence confirms a defect or unsuitable release state. |
| **Unknown / Not Yet Verified** | Repository readiness exists but live external validation is unavailable. |

## Current project summary

Weyonje is a pnpm TypeScript workspace containing an Android Flutter application, a NestJS/Fastify API, shared contracts, a Prisma PostgreSQL schema/migration, generated OpenAPI, and focused authentication tests. The implemented slice preserves `AUTH-001`, bounded `AUTH-002`, and implements native email/password `AUTH-003`, secure API-owned sessions, rotating refresh tokens, and authoritative role/eligibility routing.

Registration, password reset, email/SMS verification delivery, Provider approval, service requests, maps, notifications, role dashboards, web portal, worker, and production operations are **Not Implemented**. Neon Free and Koyeb Free are documented development targets only; neither is configured or verified.

Repository and Git-history inspection found the former TypeORM migration only in the single feature commit, its tests, and a feature workflow. There is no deployment manifest, environment address, migration record, or documented live database. The replacement therefore uses the approved clean development-only migration strategy. If an undisclosed database received the old migration, the checked-in replacement must not be applied there; a forward data-preserving migration is required.

## Implemented functionality

| Capability | Status | Current reality |
| --- | --- | --- |
| `AUTH-001` welcome/account access | **Implemented** | Existing approved logo/copy/actions, light theme, responsive scroll, semantics, 48dp controls, and no KCCA self-registration are retained. |
| `AUTH-002` account type | **Partially Implemented** | Client/Service Provider selection, required validation, no KCCA option, and no-data-collected registration-unavailable boundary are retained. |
| Native `AUTH-003` sign-in | **Implemented** | Persistent native Email address and obscured Password fields call `POST /v1/auth/sign-in`; duplicate requests are suppressed and safe invalid/rate/network states are shown. Live API/database use is unverified. |
| Launch/session bootstrap | **Implemented** | No stored session avoids the network. Checking, retrying, invalid, transient, authenticated, restricted, and denied states are explicit; obsolete requests are cancelled and resume revalidates. |
| Access-token/refresh handling | **Implemented** | Encrypted storage holds one validated access/refresh/expiry record. One controlled refresh rotates storage, concurrent refreshes coalesce, invalid refresh clears credentials, and transient failure preserves them. |
| Sign-out/revocation | **Implemented** | API revokes the current server session idempotently. Mobile always clears local credentials; network failure can leave server state active until revocation/absolute expiry. |
| Role-aware navigation | **Implemented** | Central GoRouter guards prevent protected-content flash and route eligible Client, eligible Provider, restricted Provider, eligible KCCA, and denied states. API remains authoritative. |
| Current actor | **Implemented** | Bearer-protected `GET /v1/actors/me` reads current session/user state and returns only `actorType`, `access`, and Provider `providerStatus` where applicable. |
| Downstream destinations | **Not Implemented** | Existing role destinations truthfully state that functionality is unavailable and load no protected work data. |

## Authentication and security behaviour

- Email normalization trims, uses Unicode NFKC, lowercases, validates structure/length, encrypts with versioned AES-256-GCM and a fresh 96-bit nonce, and indexes only a separate HMAC-SHA-256 lookup.
- Passwords use one-way Argon2id with OWASP's 19 MiB, two-iteration, single-lane minimum, unique salts, a 12-character development-provisioning minimum, a 1024-byte input ceiling, dummy unknown-account verification, and rehash detection.
- Access tokens are short-lived HS256 JWTs with only user id and session id. The API validates exact algorithm, signature, issuer, audience, issue/expiry, current session revocation/absolute expiry, login permission, verification, and password version.
- Refresh tokens are 384-bit opaque random values. Only HMAC hashes are stored. Rotation is transactional; consumed-token reuse revokes the session and all family tokens.
- Durable email/IP throttle records supplement a bounded in-memory IP limiter. User failed-attempt/temporary-lock state is separate. Invalid account existence, password, verification, login permission, and account lock return the same credential failure.
- Separate startup-validated secrets exist for email encryption, email lookup, access-token signing, refresh hashing, and throttling. The AES key must decode to exactly 32 bytes; every other secret requires at least 32 bytes. Placeholder, malformed, incorrectly sized, or reused secrets are rejected.

## Eligibility

- Active Client: `ELIGIBLE`; inactive Client: `DENIED`.
- Active `APPROVED` Service Provider: `ELIGIBLE`; approved inactive and `PENDING`, `REJECTED`, `INACTIVE`, or `DISABLED`: `RESTRICTED`, never Provider work.
- Active KCCA Staff with explicit mobile-monitoring permission: `ELIGIBLE`; inactive or unpermitted KCCA Staff: `DENIED`.
- Missing Provider status, Provider status on another actor, invalid monitoring combination, unknown actor, disabled login, unverified account, revoked/expired session, or password-version mismatch fails closed.

## Architecture and repository

```text
apps/api/
  prisma/                 # Prisma schema and reproducible SQL migration
  src/auth/               # crypto, password, throttling, tokens, sessions, endpoints
  src/database/           # Prisma service/module; only API persistence layer
  src/identity/           # current-actor eligibility endpoint/service
  scripts/                # OpenAPI and interactive dev-user provisioning
apps/mobile/              # native sign-in, secure session, launch/routing/screens/tests
packages/contracts/       # shared auth/actor/access/error contracts
docs/project-context/     # requirements, active rules/stack, verified state
```

Removed: Keycloak/Cloud-IAM integration, OIDC/PKCE/JWKS/browser authentication, Flutter AppAuth and redirect configuration, TypeORM/entity/data source/migration/CLI, Keycloak fixture/token tests, and `.github/workflows/identity-integration.yml`. No replacement GitHub Actions workflow exists.

## Data and migration

Prisma models are `User`, `AuthenticationSession`, `RefreshToken`, and `LoginThrottle`, with UUID identifiers and PostgreSQL enum types. Migration `20260811130000_native_authentication` creates unique protected email lookup and token hashes, ownership/cascade relationships, expiry indexes, non-negative counters, Provider-state consistency, KCCA-monitoring consistency, and session/token expiry constraints. `DATABASE_URL` is pooled runtime traffic; `DIRECT_URL` is migration/provisioning administration.

Database-dependent integration remains **Unknown / Not Yet Verified** because no approved `TEST_DATABASE_URL`/`TEST_DIRECT_URL` or Neon project was supplied. No migration was applied and no external database was contacted.

## API and configuration

Committed OpenAPI documents `POST /v1/auth/sign-in`, `POST /v1/auth/refresh`, bearer-protected `POST /v1/auth/sign-out`, and bearer-protected `GET /v1/actors/me`, including native request/response schemas and safe failures. It contains no real credentials or data.

Required API settings: `NODE_ENV`, `WEYONJE_ENVIRONMENT`, `PORT`, `DATABASE_URL`, `DIRECT_URL`, `AUTH_ISSUER`, `AUTH_AUDIENCE`, `ACCESS_TOKEN_SECRET`, both token TTLs, `EMAIL_ENCRYPTION_KEY`, `EMAIL_LOOKUP_KEY`, `REFRESH_TOKEN_HASH_KEY`, `THROTTLE_HASH_KEY`, and bounded throttle/lock settings. Mobile configuration contains only `WEYONJE_API_BASE_URL`.

## Development hosting readiness

- **Configured but unverified:** Neon Free is the documented development store; pooled/direct TLS addresses must be created and entered privately.
- **Configured but unverified:** one stateless Koyeb Free Node 24 Web Service can build the root pnpm monorepo natively, run compiled API code on supplied `PORT`/`0.0.0.0`, and keep no durable local state. Frankfurt is preferred when available/suitable.
- Free services can sleep/cold-start and have no production uptime guarantee. Argon2id parameters are not weakened for the Free host; if resource testing fails, local development remains the safe fallback.
- No Neon/Koyeb/GitHub resource, secret, deployment, domain, or paid service was created or modified.

## Validation status

Local validation on 2026-08-11 completed Prisma format/validation/generation, TypeScript format/lint/type-check, root build, generated OpenAPI drift check, Flutter format/analyze, 38 Flutter tests, and an Android debug APK build using the placeholder compile-time configuration. API testing passed 14 suites/66 tests; the one opt-in PostgreSQL suite (two tests) skipped transparently because no approved `TEST_DATABASE_URL`/`TEST_DIRECT_URL` was supplied. The production pnpm audit reported no known vulnerabilities after patched NestJS/Fastify resolution and a `js-yaml` security override. `git diff --check` and known-secret pattern scanning found no content errors or credential patterns; only Windows line-ending notices were emitted.

Routine automated checks use deterministic external-boundary fakes and do not contact Neon/Koyeb. The new compact, large, keyboard-viewport, loading, error, and landscape visual references were rendered and inspected without clipping or unreachable actions. Business Process DOCX text/tables were structurally reviewed; visual DOCX rendering was unavailable because LibreOffice/`soffice` is absent. `CURRENT_SYSTEM_STATE_TEMPLATE.md` was read and remains immutable.

## Known limitations and risks

| Item | Status | Impact |
| --- | --- | --- |
| External Neon/Koyeb/mobile-to-API integration | **Unknown / Not Yet Verified** | Repository readiness does not prove live sign-in, migration, cold-start, or host capacity. |
| Registration/recovery/delivery/approval/downstream workflows | **Not Implemented** | Only secure authentication entry and truthful boundaries exist. |
| Password change/admin revocation UI | **Not Implemented** | Schema/session password-version and revocation mechanisms exist, but no operational interface is in scope. |
| Android release signing | **Known Broken / Unstable** | Release build still uses debug signing and is unsuitable for distribution. |
| Application ID confirmation | **Unknown / Not Yet Verified** | Must be confirmed before release. |
| Production monitoring, backup, recovery, audit-event history, and HA | **Not Implemented** | Koyeb/Neon slice is development-only. |

## Required external development setup

1. Create a Neon Free PostgreSQL project and privately copy its pooled and direct TLS connection addresses.
2. Generate five independent random base64 development secrets and store them only in ignored local configuration or Koyeb secret settings.
3. Apply Prisma migrations from an approved workstation through `DIRECT_URL`.
4. Create synthetic Client, each Provider-status case, and permitted/unpermitted KCCA development users through the interactive provisioning command.
5. Push reviewed code to a normal private GitHub repository, then manually create one Koyeb Free Web Service with the documented root build/run commands and environment values.
6. Put the Koyeb HTTPS URL in the mobile compile-time configuration and build Android.
7. Wake sleeping Koyeb/Neon services before testing, then verify valid/invalid credentials, refresh/reuse/revocation, and every Client/Provider/KCCA eligibility outcome on an emulator or physical device.

## Evidence boundary

Implementation evidence is the live repository source, generated Prisma client/OpenAPI, migration SQL, and local check output dated 2026-08-11. The Business Process Specification and Mobile Screen Flow remain requirements/context and were not edited to force implementation alignment. `CURRENT_SYSTEM_STATE_TEMPLATE.md` was not modified.

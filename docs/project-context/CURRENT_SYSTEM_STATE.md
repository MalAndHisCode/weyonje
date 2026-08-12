# Weyonje Current System State

> **Purpose:** Evidence-based snapshot of implemented repository reality. Requirements and proposed/external architecture are not treated as operational without code and validation evidence.

## Document control

| Field | Value |
| --- | --- |
| Document version | 4.0 |
| Last updated and verified | 2026-08-12 |
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

Weyonje is a pnpm TypeScript workspace containing an Android Flutter application, a NestJS/Fastify API, shared contracts, Prisma PostgreSQL schema/migrations, generated OpenAPI, and focused authentication/registration tests. The implemented repository slice includes `AUTH-001`, `AUTH-002`, Client and Service Provider registration, phone verification, Client SMS-code sign-in, Provider/KCCA email-password sign-in, secure API-owned sessions, rotating refresh tokens, Provider approval APIs, and authoritative role/eligibility routing.

Password reset, email verification, service requests, maps, role dashboards, KCCA Provider-review UI, outbound registration-status notification delivery, web portal, worker, and production operations are **Not Implemented**. Africa's Talking SMS delivery, Neon Free, and Koyeb Free are configured as repository targets but no account, credential, database, deployment, or live end-to-end delivery was created or verified.

Repository and Git-history inspection found the former TypeORM migration only in the single feature commit, its tests, and a feature workflow. There is no deployment manifest, environment address, migration record, or documented live database. The replacement therefore uses the approved clean development-only migration strategy. If an undisclosed database received the old migration, the checked-in replacement must not be applied there; a forward data-preserving migration is required.

## Implemented functionality

| Capability | Status | Current reality |
| --- | --- | --- |
| `AUTH-001` welcome/account access | **Implemented** | Approved identity/copy, responsive scroll, semantics, and 48dp controls are retained. Create Account opens `AUTH-002`; Client sign-in opens phone-code access; Provider/KCCA sign-in opens email/password access. KCCA self-registration is absent. |
| `AUTH-002` account type | **Implemented** | Exactly one of Client or Service Provider is required. The group/options expose accessible single-selection state and descriptions; inline live validation, duplicate-navigation suppression, back behaviour, centralized auth guards, and real typed registration destinations are implemented. No record is created on this page. |
| Client registration | **Implemented** | Individual/organization conditional forms submit to `POST /v1/registrations/clients`; phone is mandatory, email is optional, and no Client password is collected. Submission persists protected profile data and starts phone verification. Live database/SMS use is unverified. |
| Service Provider registration | **Implemented** | Mandatory ESS licence, company, phone, email, password, address, type, and contact fields submit to `POST /v1/registrations/service-providers`; phone verification leaves the account `PENDING` for KCCA approval. Live database/SMS use is unverified. |
| Phone verification and Client sign-in | **Implemented** | Six-digit, expiring, attempt-limited, resend-delayed, hourly-rate-limited codes are HMAC-stored and delivered through an Africa's Talking adapter. Client login requests and verifies a phone code; successful verification converges on the existing session model. External delivery is unverified. |
| Native Provider/KCCA sign-in | **Implemented** | Persistent native Email address and obscured Password fields call `POST /v1/auth/sign-in`; Client accounts are excluded from password sign-in, duplicate requests are suppressed, and safe invalid/rate/network states are shown. Live API/database use is unverified. |
| Provider registration review API | **Implemented** | Explicitly permitted KCCA actors can list phone-verified pending Providers and approve/reject once. Decisions are immutable audit records; approval assigns a Provider number, rejection retains a reason, and in-system notification records are created. No KCCA review UI or outbound status delivery exists. |
| Launch/session bootstrap | **Implemented** | No stored session avoids the network. Checking, retrying, invalid, transient, authenticated, restricted, and denied states are explicit; obsolete requests are cancelled and resume revalidates. |
| Access-token/refresh handling | **Implemented** | Encrypted storage holds one validated access/refresh/expiry record. One controlled refresh rotates storage, concurrent refreshes coalesce, invalid refresh clears credentials, and transient failure preserves them. |
| Sign-out/revocation | **Implemented** | API revokes the current server session idempotently. Mobile always clears local credentials; network failure can leave server state active until revocation/absolute expiry. |
| Role-aware navigation | **Implemented** | Central GoRouter guards prevent protected-content flash and route eligible Client, eligible Provider, restricted Provider, eligible KCCA, and denied states. API remains authoritative. |
| Current actor | **Implemented** | Bearer-protected `GET /v1/actors/me` reads current session/user state and returns actor/access plus Provider status and, where applicable, assigned Provider number or latest rejection reason. |
| Downstream destinations | **Not Implemented** | Existing role destinations truthfully state that functionality is unavailable and load no protected work data. |

## Authentication and security behaviour

- Email normalization trims, uses Unicode NFKC, lowercases, validates structure/length, encrypts with versioned AES-256-GCM and a fresh 96-bit nonce, and indexes only a separate HMAC-SHA-256 lookup.
- Ugandan phone numbers are normalized with `libphonenumber-js`, encrypted with a separate versioned AES-256-GCM key, and indexed only by a separately keyed HMAC. Client email is nullable; Service Provider and KCCA email/password credentials remain mandatory in their applicable creation paths.
- Passwords use one-way Argon2id with OWASP's 19 MiB, two-iteration, single-lane minimum, unique salts, a 12-character development-provisioning minimum, a 1024-byte input ceiling, dummy unknown-account verification, and rehash detection.
- Phone codes are cryptographically random six-digit values; only a challenge-bound HMAC is stored. Default expiry is 10 minutes, resend delay 60 seconds, attempts five, and requests five per phone/purpose/hour. Successful verification consumes a code once. Unknown Client phone numbers receive the same challenge-shaped flow and cannot create a session, reducing account enumeration.
- Access tokens are short-lived HS256 JWTs with only user id and session id. The API validates exact algorithm, signature, issuer, audience, issue/expiry, current session revocation/absolute expiry, login permission, verification, and password version.
- Refresh tokens are 384-bit opaque random values. Only HMAC hashes are stored. Rotation is transactional; consumed-token reuse revokes the session and all family tokens.
- Durable email/IP throttle records supplement a bounded in-memory IP limiter. User failed-attempt/temporary-lock state is separate. Invalid account existence, password, verification, login permission, and account lock return the same credential failure.
- Separate startup-validated secrets exist for email/phone encryption and lookup, OTP hashing, access-token signing, refresh hashing, and throttling. Both AES keys must decode to exactly 32 bytes; every other secret requires at least 32 bytes. Placeholder, malformed, incorrectly sized, or reused secrets are rejected. Africa's Talking credentials and origin/sender settings are server-only.

## Eligibility

- Active Client: `ELIGIBLE`; inactive Client: `DENIED`.
- Active `APPROVED` Service Provider: `ELIGIBLE`; approved inactive and `PENDING`, `REJECTED`, `INACTIVE`, or `DISABLED`: `RESTRICTED`, never Provider work.
- A phone-verified pending Provider can authenticate only to the restricted account-status boundary. Approval requires an active KCCA actor with the separate `providerApprovalPermitted` capability; mobile-monitoring permission does not imply approval authority.
- Active KCCA Staff with explicit mobile-monitoring permission: `ELIGIBLE`; inactive or unpermitted KCCA Staff: `DENIED`.
- Missing Provider status, Provider status on another actor, invalid monitoring combination, unknown actor, disabled login, unverified account, revoked/expired session, or password-version mismatch fails closed.

## Architecture and repository

```text
apps/api/
  prisma/                 # Prisma schema and reproducible SQL migrations
  src/auth/               # crypto, password, throttling, tokens, sessions, endpoints
  src/database/           # Prisma service/module; only API persistence layer
  src/identity/           # current-actor eligibility endpoint/service
  src/registration/       # registration, phone protection/OTP/SMS, Provider review
  scripts/                # OpenAPI and interactive dev-user provisioning
apps/mobile/              # account choice, registration, verification, sign-in/session/routing/tests
packages/contracts/       # shared auth, registration, actor/access/error contracts
docs/project-context/     # requirements, active rules/stack, verified state
```

Removed: Keycloak/Cloud-IAM integration, OIDC/PKCE/JWKS/browser authentication, Flutter AppAuth and redirect configuration, TypeORM/entity/data source/migration/CLI, Keycloak fixture/token tests, and `.github/workflows/identity-integration.yml`. No replacement GitHub Actions workflow exists.

## Data and migration

Prisma models are `User`, `ClientProfile`, `ServiceProviderProfile`, `PhoneChallenge`, `ProviderApprovalDecisionRecord`, `RegistrationNotification`, `AuthenticationSession`, `RefreshToken`, and `LoginThrottle`, with UUID identifiers and PostgreSQL enum types. Migration `20260811130000_native_authentication` establishes native sessions; `20260812150000_registration_phone_auth` adds nullable Client email/password support, protected phone fields, profiles, phone challenges, Provider review/audit records, in-system notifications, indexes, relationships, and consistency constraints. `DATABASE_URL` is pooled runtime traffic; `DIRECT_URL` is migration/provisioning administration.

Database-dependent integration remains **Unknown / Not Yet Verified** because no approved `TEST_DATABASE_URL`/`TEST_DIRECT_URL` or Neon project was supplied. No migration was applied and no external database was contacted.

## API and configuration

Committed OpenAPI documents Provider/KCCA sign-in, Client phone-code request/verify/resend, token refresh/sign-out, Client and Service Provider registration/phone verification/resend, current actor, Provider status, and KCCA pending-provider/decision endpoints. It contains no real credentials or data.

Required API settings: the existing environment/database/authentication settings; eight independent secrets (`ACCESS_TOKEN_SECRET`, `EMAIL_ENCRYPTION_KEY`, `EMAIL_LOOKUP_KEY`, `PII_ENCRYPTION_KEY`, `PHONE_LOOKUP_KEY`, `OTP_HASH_KEY`, `REFRESH_TOKEN_HASH_KEY`, `THROTTLE_HASH_KEY`); bounded login/OTP settings; and `AFRICASTALKING_API_BASE_URL`, `AFRICASTALKING_USERNAME`, `AFRICASTALKING_API_KEY`, and `AFRICASTALKING_SENDER_ID`. Mobile configuration still contains only `WEYONJE_API_BASE_URL`; no SMS credential enters Flutter.

## Development hosting readiness

- **Configured but unverified:** Neon Free is the documented development store; pooled/direct TLS addresses must be created and entered privately.
- **Configured but unverified:** one stateless Koyeb Free Node 24 Web Service can build the root pnpm monorepo natively, run compiled API code on supplied `PORT`/`0.0.0.0`, and keep no durable local state. Frankfurt is preferred when available/suitable.
- Free services can sleep/cold-start and have no production uptime guarantee. Argon2id parameters are not weakened for the Free host; if resource testing fails, local development remains the safe fallback.
- No Neon/Koyeb/GitHub resource, secret, deployment, domain, or paid service was created or modified.

## Validation status

Local validation on 2026-08-12 completed Prisma format/validation/generation, TypeScript format/lint/type-check, root build, generated OpenAPI drift check, Flutter format/analyze, 51 Flutter tests, and an Android debug APK build using a placeholder compile-time API origin. API testing passed 17 suites/81 tests; the one opt-in PostgreSQL suite (two tests) skipped transparently because no approved `TEST_DATABASE_URL`/`TEST_DIRECT_URL` was supplied. The production pnpm audit reported no known vulnerabilities. Database-dependent migration and SMS-provider delivery were not executed.

Routine automated checks use deterministic external-boundary fakes and do not contact Neon, Koyeb, or Africa's Talking. AUTH-002 unselected, selected, validation, compact portrait, large portrait, landscape, and large-text visual references were generated and inspected alongside adjacent welcome/sign-in states without clipping or unreachable actions. Business Process DOCX text/tables were structurally reviewed; visual DOCX rendering was unavailable because LibreOffice/`soffice` is absent. `CURRENT_SYSTEM_STATE_TEMPLATE.md` was read and remains immutable.

## Known limitations and risks

| Item | Status | Impact |
| --- | --- | --- |
| External Neon/Koyeb/mobile-to-API integration | **Unknown / Not Yet Verified** | Repository readiness does not prove live sign-in, migration, cold-start, or host capacity. |
| Live registration/database/SMS integration | **Unknown / Not Yet Verified** | Repository implementation and deterministic tests do not prove migrated Neon persistence or Africa's Talking delivery. |
| KCCA Provider-review and notification UI | **Not Implemented** | Authoritative list/decision APIs, audit data, and in-system notification records exist; no review console, notification inbox, push, or outbound status message exists. |
| Password recovery and email verification | **Not Implemented** | Client access uses verified phone codes; Provider/KCCA password recovery and email verification remain absent. |
| Password change/admin revocation UI | **Not Implemented** | Schema/session password-version and revocation mechanisms exist, but no operational interface is in scope. |
| Android release signing | **Known Broken / Unstable** | Release build still uses debug signing and is unsuitable for distribution. |
| Application ID confirmation | **Unknown / Not Yet Verified** | Must be confirmed before release. |
| Production monitoring, backup, recovery, audit-event history, and HA | **Not Implemented** | Koyeb/Neon slice is development-only. |

## Required external development setup

1. Create a Neon Free PostgreSQL project and privately copy its pooled and direct TLS connection addresses.
2. Generate eight independent random base64 development secrets and store them only in ignored local configuration or Koyeb secret settings; both AES keys must decode to exactly 32 bytes and no values may be reused.
3. Apply Prisma migrations from an approved workstation through `DIRECT_URL`.
4. Create an Africa's Talking application, use sandbox credentials for development, configure the API base URL/username/API key, and obtain/configure a sender ID that is valid for the selected environment; keep every credential server-side.
5. Create synthetic Client, each Provider-status case, and permitted/unpermitted KCCA development users through approved local/API workflows.
6. Push reviewed code to a normal private GitHub repository, then manually create one Koyeb Free Web Service with the documented root build/run commands and environment values.
7. Put the Koyeb HTTPS URL in the mobile compile-time configuration and build Android.
8. Wake sleeping services before testing, then verify Client registration/sign-in SMS, Provider submission/approval/rejection/status, credentials, refresh/reuse/revocation, and every Client/Provider/KCCA eligibility outcome on an emulator or physical device.

## Evidence boundary

Implementation evidence is the live repository source, generated Prisma client/OpenAPI, migration SQL, deterministic tests, inspected goldens, and local check output dated 2026-08-12. The Business Process Specification and Mobile Screen Flow remain requirements/context and were not edited to force implementation alignment. No external resource was created or changed. `CURRENT_SYSTEM_STATE_TEMPLATE.md` was not modified.

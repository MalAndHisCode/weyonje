# Weyonje Current System State

> **Purpose:** Evidence-based snapshot of implemented repository reality. Requirements and proposed architecture are not treated as implemented without code and validation evidence.

## Document control

| Field | Value |
| --- | --- |
| Document version | 2.0 |
| Last updated and verified | 2026-08-11 |
| Verified against | Local repository at `D:\Dev\weyonje`, branch `main`; no deployment or external environment was changed |
| System version | Mobile `0.1.0+1`; API and contracts `0.1.0` |

## Status legend

| Status | Meaning |
| --- | --- |
| **Implemented** | Present and validated in repository code. |
| **Partially Implemented** | A safe bounded capability exists, while named downstream work remains. |
| **Not Implemented** | No functioning implementation is present. |
| **Known Broken / Unstable** | Current evidence confirms a defect. |
| **Unknown / Not Yet Verified** | Repository evidence is insufficient or live external validation is unavailable. |

## Current project summary

Weyonje now has a pnpm TypeScript workspace, an Android Flutter application, a NestJS/Fastify API, shared identity contracts, one PostgreSQL migration, OpenAPI generation, and focused automated tests. The implemented product slice is the secure entry and routing boundary for `AUTH-001`, bounded `AUTH-002`, and bounded `AUTH-003`.

No registration forms, provider-approval workflow, service-request workflow, maps, notifications, role dashboard, web portal, worker, or deployment is implemented. Live mobile-to-Keycloak-to-API authentication remains **Unknown / Not Yet Verified** until authorized Keycloak, PostgreSQL, HTTPS API, and Android signing/environment configuration exist.

## Implemented functionality

| Capability | Status | Current reality |
| --- | --- | --- |
| `AUTH-001` welcome and account access | **Implemented** | Approved logo/copy, primary Create account and secondary Sign in actions, no KCCA registration, responsive scrolling, semantics, 48dp controls, and approved light theme. |
| Launch/session bootstrap | **Implemented** | Explicit checking, unauthenticated, retryable transient error, invalid-session feedback, authenticated, restricted, and denied states. No stored session causes no network call. Obsolete lifecycle requests are cancelled and resume is revalidated without duplicate work. |
| `AUTH-002` account type | **Partially Implemented** | Real Client/Service Provider selection and validation. Continue reaches a truthful boundary that collects no data because registration is not implemented. Invalid deep-link account types are rejected. |
| `AUTH-003` sign in | **Partially Implemented** | Real system-browser Authorization Code Flow with PKCE through AppAuth, secure token storage, refresh-once handling, and authoritative current-actor resolution. Live identity integration awaits external setup. |
| Role-aware navigation | **Implemented** | Central GoRouter guards prevent protected-content flash and cross-role destinations. Client, approved active Provider, permitted KCCA Staff, restricted Provider, and denied states resolve separately. |
| Downstream role screens | **Not Implemented** | Role destinations are explicit unavailable boundaries; they claim only that session/access was verified and load no protected feature data. |
| Current-actor API | **Implemented** | `GET /v1/actors/me` validates Keycloak token properties and returns the minimum actor/access/provider-status routing contract. |
| Identity linkage/eligibility | **Implemented** | PostgreSQL entity and migration enforce unique `sub`, actor types, provider status, activation, and explicit KCCA mobile permission. Passwords/tokens are not persisted. |

## Architecture and structure

```text
.github/workflows/identity-integration.yml
apps/
  api/                    # NestJS/Fastify identity API, tests, migration, OpenAPI
  mobile/                 # Flutter Android app, auth screens/state/routes/tests
  web/                    # reserved; not implemented
  worker/                 # reserved; not implemented
packages/
  contracts/              # shared TypeScript identity/access enums and errors
docs/project-context/     # adopted requirements, rules, and this snapshot
```

- Mobile: Forui light theme, Riverpod state, GoRouter guards, one Dio client, AppAuth, and secure storage.
- API: strict TypeScript, NestJS/Fastify, JOSE verification, TypeORM/PostgreSQL, stable error codes, JSON logging, bounded request/body limits, Helmet, and non-production Swagger.
- Contracts: actor types `CLIENT`, `SERVICE_PROVIDER`, `KCCA_STAFF`; access `ELIGIBLE`, `RESTRICTED`, `DENIED`; provider states `PENDING`, `APPROVED`, `REJECTED`, `INACTIVE`, `DISABLED`.

## Identity and authorization behaviour

Keycloak is authoritative for token validity and configured token role. Weyonje PostgreSQL is authoritative for subject linkage, actor type, activation, provider status, and KCCA mobile-monitoring permission. The API requires both authorities to agree and defaults to denial.

- Client: active linked profile plus configured Client role is eligible.
- Service Provider: configured Provider role plus linked, active, `APPROVED` profile is eligible. Pending, rejected, inactive, disabled, missing, and unknown states cannot reach provider work.
- KCCA Staff: configured mobile-monitor role plus linked, active profile with `mobile_monitoring_permitted=true` is eligible.
- Missing/invalid bearer tokens, bad signature/issuer/audience/algorithm/expiry/subject, unknown linkage, and role mismatch are rejected without profile enumeration.

The mobile app stores only access, refresh, ID token, and access-token expiry in Android encrypted storage. It clears unusable authentication material after unrecoverable invalidation, preserves it on temporary failures, and never places tokens in widgets or application logs.

## Routes and API contract

Mobile route contracts: `/launch`, `/welcome`, `/account-type`, `/sign-in`, `/session-error`, `/access-denied`, `/provider-account-status`, `/register/:accountType/unavailable`, `/client`, `/provider`, and `/kcca-monitoring`.

API contract: bearer-authenticated `GET /v1/actors/me`; generated OpenAPI is committed at `apps/api/openapi/openapi.json`. Responses contain no names, phone numbers, email addresses, Keycloak subject, or mobile route names.

## Configuration and dependencies

Root `.env.example` defines environment, API port, Keycloak issuer/JWKS/audience/algorithms/role names, and PostgreSQL connection values. Mobile `config/auth.example.json` defines HTTPS API base URL, HTTPS issuer, public client ID, and custom redirect URI. All values are placeholders; secrets belong in ignored local `.env` files or an approved deployment secret store.

Direct mobile additions are Dio, Flutter AppAuth, Riverpod, secure storage, and GoRouter alongside existing Forui. Direct API foundations are NestJS/Fastify, JOSE 5.x, TypeORM, PostgreSQL, class validation/transformation, Swagger, Jest, and strict TypeScript. The root uses pnpm `11.16.0` and Node `>=24`.

Android minimum API inherits Flutter 3.44.8's default of 24, which also satisfies secure-storage requirements. The AppAuth redirect scheme is manifest-configured and defaults to `ug.go.kcca.weyonje.auth`. Release builds still use debug signing and the application-ID confirmation TODO remains.

## Validation status

Verified locally on 2026-08-11:

- Dart formatting completed; `flutter analyze` reported no issues.
- Flutter widget/model/visual regression tests passed, including launch states, both actions, role routing, every documented Provider restriction, lifecycle resume, duplicate retry, large text/small viewport, semantics, touch targets, and no protected flash.
- `flutter build apk --debug` completed successfully and produced the ignored debug APK artifact.
- Rendered golden states were inspected at 360x640 and 412x915; the unchanged approved logo is legible and controls remain reachable. Flutter's deterministic Ahem test font means golden text appears as blocks while layout and image rendering remain inspectable.
- API Jest unit, guard, HTTP contract, token, service, and migration tests passed locally; external-service tests are skipped unless explicitly enabled.
- API TypeScript typecheck/build and OpenAPI generation/drift check passed.
- The Linux workflow is present but was not run from this local task. It is configured to use pinned Keycloak `26.6.4` and PostgreSQL `18.4-alpine`, verify OIDC discovery/JWKS with PKCE `S256`, and apply/reverse the real migration.
- The Business Process DOCX text and tables were reviewed. Visual page rendering was unavailable because LibreOffice/`soffice` is not installed; no implementation claim depends on document page layout.

## External services and remaining setup

**Unknown / Not Yet Verified:** An authorized administrator must provide a non-production Keycloak realm/public PKCE client, exact redirect allow-list, roles/audience mapper, HTTPS JWKS/issuer access, PostgreSQL database and least-privilege API account, HTTPS API endpoint/network access, actor-profile records, and Android release signing. Until then, live browser sign-in and live role routing cannot be verified or used.

The committed CI fixture contains no users, administrative credentials, or client secrets. It validates only an isolated realm's public discovery/signing-key surface and the PostgreSQL migration.

## Known limitations and technical debt

| Item | Status | Impact |
| --- | --- | --- |
| Registration/downstream workflows absent | **Not Implemented** | `AUTH-002` stops at a no-data-collected boundary; role destinations expose no downstream functionality. |
| External identity/database/API environment absent | **Unknown / Not Yet Verified** | Live end-to-end sign-in cannot be claimed. |
| Android release signing uses debug keys | **Known Broken / Unstable** | Not suitable for production distribution. |
| Application ID uniqueness TODO | **Unknown / Not Yet Verified** | Must be confirmed before release/Keycloak redirect registration. |
| No approved dark palette | **Not Implemented** | App intentionally uses the approved light scheme in all system modes. |
| Border token has low standalone contrast | **Known limitation** | Controls use filled surfaces/focus treatment and do not rely on the border alone. |
| Web, worker, operational workflows, telemetry, backup, and deployment | **Not Implemented** | Outside this authentication-entry slice. |

## Evidence and documentation boundary

The master `CURRENT_SYSTEM_STATE_TEMPLATE.md` was read and remains unchanged. The expected Markdown screen-flow file was absent; the repository instead contains the pre-existing untracked `MOBILE_APPLICATION_SCREEN_FLOW_SPECIFICATION.txt`, which was reviewed and applied. Brand Identity Guidelines, Mobile UI/UX Design Rules, AI Coding Agent Rules, Business Process Specification, Technology Stack proposal, live repository, and the explicit task contract were applied in the required precedence order.

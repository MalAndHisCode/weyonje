# Weyonje Current System State

> Evidence-based repository snapshot. “Implemented” means connected repository behavior; credential-dependent behavior is separately marked unverified.

## Document control

| Field | Value |
| --- | --- |
| Document version | 8.1 |
| Last updated | 2026-09-10 |
| Verified against | Local repository at `D:\Dev\weyonje`; no deployment, shared database or billing action; ignored SMS configuration validated without exposing values; Railway process and installed APK not verified |
| System version | Mobile `0.1.0+1`; API/contracts `0.1.0` |

## Current project summary

Weyonje is a pnpm monorepo containing a Flutter Android application, NestJS/Fastify API, Prisma/PostgreSQL persistence, shared TypeScript contracts, and generated OpenAPI. Authentication is native Weyonje authentication. Railway remains the confirmed GitHub-connected deployment target. PostgreSQL remains authoritative; no Valkey, Redis, BullMQ, Firebase Authentication, or Firebase database was introduced.

The established Client request, marketplace and Call Centre ingress, atomic Provider acceptance, collection, feedback/follow-up, disposal, persisted GPS, Socket.IO hint, and REST-reconciliation behavior is preserved. Revision 6.0 added a PostgreSQL delivery worker, recovery and verification challenges, authorised KCCA administration, Google Maps adapters, foreground journey coordination with a bounded encrypted offline queue, FCM installation lifecycle, and scheduled reminder creation.

## Capability status

| Capability | Status | Repository reality |
| --- | --- | --- |
| Native authentication/registration | **Implemented locally; live SMS unverified** | Automatic six-box Client verification, pending registration recovery and atomic OTP/account/session completion extend existing native endpoints. Provider review and role eligibility remain server-authoritative. |
| Password recovery | **Implemented; live email/SMS unverified** | Provider/KCCA recovery supports registered phone or email, non-enumerating requests, throttling, expiry, attempt limits, supersession, HMAC-only secrets, one-time use, password rules, session revocation, audit events, guarded fake SMS/email, and mobile request/code/password/success states. |
| Email verification | **Implemented; access gating unresolved** | Authenticated request, phone/email method selection, resend, supersession, expiry, one-time verification, `emailVerifiedAt`, audit events, mobile flow and deep-link route exist. No new Provider/KCCA access block was imposed because the Business Process Specification does not clearly approve that rule. |
| PostgreSQL reliable delivery | **Implemented locally; production worker unprovisioned** | Leased `FOR UPDATE SKIP LOCKED` claims, attempts, retry/backoff, dead letters, abandoned-claim recovery, cleanup, graceful shutdown, worker entry point, health endpoint and per-event isolation exist. In-app completion is deduplicated by source outbox ID. External exactly-once delivery still depends on provider idempotency semantics. |
| Persisted reminders | **Implemented for newly created scheduled requests** | Validated offsets create scheduled in-app/push outbox events in the business transaction. ASAP requests create none. Delivery rechecks current time, request status and scheduled timestamp. Existing workflows currently expose no timing-change/cancel command, so rescheduling/cancellation hooks are not exercised by a public command. |
| KCCA manual Call Centre entry | **Partially Implemented** | Separate KCCA permission protects mobile routing and server queries. Mobile UI can find an existing Client, enter manual contact/service/location/timing data, select an active approved Provider, enter whole-number UGX price, create/assign, and list statuses. Existing API feedback/reassignment operations remain available; dedicated mobile feedback/reassignment detail controls are incomplete. |
| KCCA Provider administration | **Implemented** | Mobile status lists show registration/ESS/contact details and confirmation actions for approve, reject with reason, activate, deactivate and disable. Server permission is independent of UI. Approval/status histories are append-only and Provider in-app/push notifications are durable. |
| KCCA disposal administration | **Partially Implemented** | Mobile list/create/edit/activate/deactivate exists. Server records catalogue audits and immutable assignment history and refuses reassignment after the disposal journey starts. Dedicated history rendering and request assignment controls in the disposal-site screen are incomplete. |
| Google Maps | **Partially Implemented; live calls unverified** | `google_maps_flutter` displays destination/Provider markers, tap selection and decoded Routes polylines with distance/ETA. Authenticated server adapters provide Places text search, reverse geocoding and Routes guidance without exposing the server credential. Request and journey screens keep address/coordinate fallbacks. KCCA administration map embeddings remain incomplete. |
| Android foreground/background tracking | **Partially Implemented; device behavior unverified** | An authorised active Provider journey starts a foreground service with persistent disclosure, restores the active session after process restart, uses API policy, preserves sample UUID/device time, and stores at most 200 encrypted samples for 24 hours before chronological upload. It stops on server-reconciled completion, logout or lost app eligibility. Force-stop survival is not claimed. OEM/battery/process-removal behavior and permission UX require physical-device validation and final KCCA approval. |
| FCM push | **Implemented behind adapter; live FCM unverified** | Android permission, token registration/refresh/delete, per-installation/environment association, encrypted token storage, stale-token invalidation, open/terminated hint routing, private lock-screen visibility, fake push and Firebase Admin delivery exist. Push always routes to REST notification reconciliation. No Firebase project/config/credentials were used. |
| In-app notifications/Socket.IO | **Implemented** | PostgreSQL notifications remain authoritative. Socket.IO remains an authenticated hint channel with REST reconciliation. |

## Mobile Identity, UI and Architecture Boundaries

**Implemented (2026-09-10):** Android display name is `Weyonje`. Legacy square/round icons and API 26 adaptive icons use the complete unchanged PNG, with white backgrounds and all artwork inside launcher mask bounds. Application ID/namespace remain `ug.go.kcca.weyonje.weyonje`; signing, integration identifiers, deep links, splash and platform targets are unchanged. `apps/mobile/tool/generate_launcher_icons.py` regenerates all five densities with Python/Pillow; the mobile README records exact source dimensions, alpha bounds and safe sizing. The small tagline is retained but may be illegible at launcher size.

**Implemented:** The welcome screen retains its logo and heading, removes the explanatory paragraph, and presents **Create Account**, **Client Sign In**, **Provider Sign In**, **KCCA Sign In** in that order. Create Account is primary; sign-in actions share secondary emphasis. `/sign-in?entry=provider` and `/sign-in?entry=kcca` select headings and introductory copy in the same form. Missing/invalid context at the compatible `/sign-in` route selects the generic heading. Context is never sent to the repository/API or used as authorization. The server-resolved actor determines all successful destinations and restricted Provider handling. Recovery returns to the selected form through the existing back stack; direct-entry back safely falls back to welcome.

**Implemented:** Standard mobile forms, selections, buttons, radios, switches, sliders, cards, tiles, dialogs and progress indicators now compose Forui 0.25.0. `lib/theme/` remains the single palette/typography/style owner, with explicit 48 dp text/select/button constraints and padded radio/switch targets because Forui's defaults are smaller. `WeyonjeSelect` preserves stable values, duplicate display names and validators; `WeyonjeDialog` provides a scrollable Forui dialog body. Existing button/page/logo/alert boundaries remain. Page headings wrap at enlarged text, forms scroll above keyboards, and authored headings/action labels use conventional Title Case. The Choose Account Type descriptions and Client Registration authored form labels use Title Case as a scoped presentation exception; this does not introduce application-wide runtime title-casing. Native date/time pickers, maps and platform permission controls remain. Existing Forui-bundled Inter/Lucide and light-only behavior are retained; no new theme mode or dependency was introduced.

The earlier branding change was limited to presentation and packaging. Subsequent phone-flow changes below extend existing auth controllers, SMS delivery and completion transactions. Workers, schema and deployment configuration remain unchanged; the phone-challenge contract correction is recorded below.

## Client Phone Registration and Sign-In — 2026-09-10

**Implemented locally:** Service Provider description is exactly **Receive and Handle Service Requests**. Client registration preserves conditional fields, required/optional indicators, optional email, normalized phones and post-verification numbering. Repeating registration for an unverified Client resumes its original pending profile without unauthenticated profile replacement. Both Client flows retain their purpose-specific endpoints. Unknown/inactive Client sign-in creates no account and adds no eligibility disclosure.

**Implemented locally:** `WeyonjeOtpField` wraps pinned Forui 0.25.0 `FOtpField`. Manual entry/paste, numeric keyboard, leading zeroes and one-time-code autofill share a guarded automatic six-digit server request. Only text edits clear invalid styling. Checking, red invalid input, expiry/exhaustion, transient failure with explicit retry and green server-confirmed success have distinct feedback and live-region messages. Success remains visible for 650 ms before existing actor routing; leaving cancels the transition. Actor-resolution failure after secure storage uses existing session-error retry without replaying the OTP.

**Implemented; physical retrieval unverified:** A focused Dart/native boundary starts SMS Retriever before delivery/resend, buffers up to four transient UUID-scoped candidates, ignores obsolete references and disposes receivers/timers. Google's `play-services-auth-api-phone:18.3.1` is the only new runtime dependency. No SMS-reading permission, Flutter package, extra design system or identity store was introduced. Manual input remains available without services/hash/receipt. Package/signing configuration is unchanged; debug identity was derived from its real public certificate. Proper production release signing remains **Not Implemented**.

**Implemented locally:** Reusable OTP composition uses configured TTL, validates the trusted 11-character server hash and enforces 140 UTF-8 bytes. Africa's Talking must explicitly accept the intended recipient with a message ID; this does not prove handset receipt. Unconfirmed acceptance retains a challenge for controlled resend, with no blind timeout retry. Fake is prohibited in production. The only new environment variable is optional server-owned `SMS_ANDROID_APP_HASH`; credentials/live settings were unchanged. See `docs/PHONE_VERIFICATION_SETUP.md` for setup, official references and remaining external steps.

### OTP input correction — 2026-09-10

**Implemented:** Confirmed cause was the shared phone screen copying developmentVerificationCode from the challenge response on initial load and resend, then triggering six-digit verification. PhoneChallengeService exposed the value when configured FAKE. Removed those fill paths and the development hint; removed the field from the mobile phone model, API DTO, shared phone contract and regenerated OpenAPI. Legacy response extras are ignored rather than parsed. Provider registration shares this protection; unrelated account-security contracts are preserved. No runtime fake repository or synthetic SMS injection was found.

New challenges remain empty without current matching SMS or deliberate input, including debug/fake environments. Typing, paste, supported OTP autofill and generation/UUID-matched native SMS remain allowed; early retrieval buffering, automatic verification, error/success feedback, guarded routing and session restoration are retained. SmsRetrieval now ignores already-consumed candidates until the next generation, preventing duplicate delivery from overwriting manual edits. Provider acceptance alone never creates credentials. Restoring a previously stored server-valid session remains a separate legitimate path.

## Data and migrations

**Phone-flow transaction update (2026-09-10):** No schema/migration change. Issuance serializes protected phone/purpose requests with a PostgreSQL advisory transaction lock before limits/cooldown/supersession. Correct-code consumption atomically rechecks remaining attempts, expiry and one-time status and shares the transaction with activation, account numbering/Provider notification, native session and refresh-hash creation. Completion failure rolls back those writes; wrong-code decrements remain durable. Lost responses after commit require fresh sign-in if credentials were not saved. Consumed OTPs cannot be replayed. Actual PostgreSQL lock/rollback testing remains unavailable without isolated URLs.

Historical forward-only migrations added after the established workflow migration:

- `20260820110000_reliable_delivery_foundation`: email delivery channel, leased claims, dead letters and immutable delivery attempts.
- `20260820130000_account_recovery_verification`: recovery/verification challenges and security events.
- `20260820150000_kcca_administration_history`: Provider status history, disposal assignment history, device installations, Provider-account notification type and in-app source-outbox deduplication.

The last migration backfills Provider decision history and current disposal assignments. It adds nullable columns and new tables/indexes rather than rewriting workflow tables. Migrations were formatted/validated locally but were not applied to any shared database. The opt-in isolated PostgreSQL test remains dependent on `TEST_DATABASE_URL` and `TEST_DIRECT_URL`.

## Permissions and business invariants

- `mobileMonitoringPermitted`, `providerApprovalPermitted`, and `callCentreOperationsPermitted` are exposed separately to KCCA mobile routing and enforced again in API services. KCCA administration does not imply journey monitoring.
- Provider work still requires approved, active, login-enabled status. All such Providers see eligible marketplace requests; first valid acceptance wins atomically.
- Scheduled timing is mandatory as `ASAP` or a future timestamp. Prices are non-negative whole-number UGX.
- Feedback remains 1–5. Negative feedback creates a separate follow-up. `LEFT_INCOMPLETE` permits disposal because waste was collected; `NOT_DONE_AT_ALL` does not.
- KCCA alone controls disposal-site catalogue and assignment. Providers see only assigned sites for authorised work.
- Email verification foundations do not block existing Client phone flows or impose an unapproved access gate.

## Configuration and topology

**Implemented locally (2026-09-10):** `MapsModule` imports `AuthModule` so its controller's `AccessTokenGuard` can resolve the exported token and session services. This fixes the missing dependency reported in the supplied Railway startup log. Authentication remains enforced; no environment variables, credentials, database schema or deployment settings changed. Railway recovery is **not yet verified**; the fix has not been deployed by this task.

The API process serves HTTP/WebSocket traffic. Production reliable processing requires a separate Railway service using the same build and variables with run command `pnpm --filter @weyonje/api start:worker`. Development can run `start:worker:dev`. Running the worker inside the API is intentionally unsupported.

New `.env.example` families cover delivery batch/lease/backoff/retention, account-challenge TTL/resend/attempt/rate limits, fake/unconfigured email, reminder offsets, server Maps key/timeout, FCM provider and Firebase service credentials. Mobile compile-time flags include API URL, environment, Maps enablement and FCM enablement. The Android Maps SDK key is supplied as a Gradle property/manifest placeholder, not as a Dart or server key.

**SMS configuration correction (2026-09-10):** The root ignored .env passes smsConfig validation: AFRICAS_TALKING, live endpoint, present credentials, blank optional sender and configured debug hash. No variable or secret values changed. Nest previously defaulted to the process working directory, missing that file under the documented pnpm API command; AppModule now resolves the repository-root .env from source/compiled layouts, with process-variable precedence. The general environment whitelist also stripped file-loaded SMS keys; those keys now pass through to the existing SMS validator. Loading the compiled AppModule from apps/api resolves AFRICAS_TALKING and the existing live endpoint without starting the API or connecting to a database. The configured APK targets the Railway HTTPS API in development mode through NativeAuthRepository. Railway's actual provider and installed-APK configuration remain **Unknown**; local settings do not configure that server. Sandbox simulator receipt requires deliberate paste/input and is not handset receipt. No live service switch or SMS send occurred.

## Provisional location and retention policy

The API supplies the adopted development defaults: 15-second interval, 25-metre movement, 75-metre arrival radius, 50-metre maximum arrival accuracy, 60-second stale threshold and 90-day server retention. The offline mobile queue is bounded to 200 samples and 24 hours. These values, foreground disclosure, consent, final retention/purge, arrival rules, battery policy and production background behavior require KCCA/privacy approval. A journey-position purge processor is **not implemented**.

## External and live validation status

| Integration | State |
| --- | --- |
| Google Maps Platform | **Unknown / Not Yet Verified.** Requires authorised non-production Google Cloud project, billing/quota budget and alerts, Maps SDK for Android, Places API (New), Geocoding API, Routes API, restricted Android key and separate restricted server key. |
| Firebase/FCM | **Unknown / Not Yet Verified.** Requires authorised Firebase project, Android app registration/config, Railway service credentials and physical-device foreground/background/terminated tests. |
| SMS/email | **Live SMS adapter configured locally.** User-generated live key saved in ignored .env; default sender supported by omitting from. One connection test accepted (HTTP 201/status 100, UGX 27), with user-provided dashboard Sent record from AFRICASTKNG. Local provider selects Africa's Talking. No deployed settings changed; live registration/sign-in completion and physical autofill remain unverified. Production fake is prohibited. Live email provider remains unselected. |
| Railway worker | **Not Implemented externally.** Code and command exist; creating the worker service, variables, health monitoring and capacity is an external authorisation. |
| PostgreSQL migrations | **Not applied.** Isolated test URLs were unavailable; shared Neon/Railway data was untouched. |
| Android background behavior | **Unknown / Not Yet Verified.** Requires physical Android testing for battery restrictions, process removal, restart and force-stop expectations. |

## Historical Validation Evidence — 2026-08-20

- Baseline before edits: root typecheck passed; 20 API suites/97 tests passed with isolated PostgreSQL skipped; OpenAPI drift passed.
- Changed API: Prisma format/generation and validation, root TypeScript checks/build, and OpenAPI generation/drift pass. The final API run passed 21 suites and 103 tests; one suite/three tests were intentionally skipped because isolated PostgreSQL URLs were unavailable.
- Mobile: Dart formatting and analysis pass with no issues. The full Flutter run passed 55 tests. Four affected sign-in goldens were intentionally refreshed and visually inspected. The final route-enabled debug APK was built at `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (239,176,990 bytes; SHA-256 `23A82D0F886D348BEDEBBDC031F79879A4C92E40C7031FECFCBE25E611EFC151`).
- DOCX structural extraction completed. Visual DOCX rendering was unavailable because LibreOffice/`soffice` is absent.

## Mobile Validation Evidence — 2026-09-10

- Focused copy update: removed the introductory paragraphs from Choose Account Type and Client Registration; applied the requested Title Case to account-type descriptions and Client Registration labels, including conditional organization/contact fields. Registration controllers, models, routing, validators and payloads were unchanged. The master template was not modified.

- Formatting check (`dart format --output=none --set-exit-if-changed lib test`) and `flutter analyze --no-pub` passed.
- Full mobile suite: **85 tests passed**, including authentication, actor resolution, repository behavior, shared selection validation, touch sizing, loading lockout and keyboard-safe dialogs. New entry tests cover both contexts, missing/invalid context, cross-role credentials, restricted Provider states and recovery/back navigation. Tests use local fake data; production services were not contacted.
- **22 Flutter-rendered visual cases** were inspected: compact/large phones, portrait/landscape, 2× text, keyboard, loading/error states, account choice, and representative Client, Provider and KCCA dashboards. Goldens intentionally load the app's already-bundled fonts instead of Ahem rectangles; this also changes existing account-choice/session-error images. Scrolling naturally moves content above the viewport; persistent headings remain visible and actions are reachable. Physical-device keyboard/focus behavior remains unverified.
- Debug APK built with `flutter build apk --debug --no-pub` at `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. AAPT verified the installed label, unchanged package ID, launcher and round-icon references; 15 packaged PNGs matched generated resources pixel-for-pixel. Circle, rounded-square and square mask previews retained all artwork. Source logo, lockfile, Gradle identity/signing and master state template remained unchanged.
- No connected Android device was available (`flutter devices` listed desktop/browser targets only), so launcher/app-drawer installation and physical-device behavior were **not verified**. No application was uninstalled or cleared. The existing `flutter_foreground_task` dependency emits a future Kotlin Gradle Plugin compatibility warning; the debug build succeeds. No dependency upgrade was attempted.
- API/integration/deployment results in the historical section were not rerun or newly validated by this mobile-only change. Existing external-service, release-signing, background execution and operational limitations remain as recorded above.

## Historical Phone Flow Validation — 2026-09-10 (before input correction)

- API: `pnpm --filter @weyonje/api test --runInBand` passed **23 suites / 124 tests**; **one suite / four isolated PostgreSQL tests skipped** because isolated URLs are absent. Coverage includes retained Provider/password flows, provider acceptance/rejection/malformed responses, no blind timeout retry, fake configuration, purpose isolation, expiry, exhaustion, conditional concurrent consumption and pending Client recovery.
- `pnpm typecheck` and `pnpm build` passed, including Prisma validation/generation. No shared/test migration was applied. API contracts are unchanged.
- Final `flutter test --no-pub --reporter compact` passed **106 tests**, including abandoned/overlapping flows and unconfirmed-delivery recovery. Dart formatting checked 61 files with no changes; full Flutter analysis and final targeted Dart analysis passed. Eleven account-choice/verification renders were inspected, including compact, 2× text and keyboard layouts; clipping and a programmatic cursor assertion were corrected. `pnpm openapi:check` passed without contract changes.
- Final `flutter build apk --debug --no-pub` passed. APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (239,199,435 bytes; SHA-256 `830F5C7D432E89993C3821B2D8DD02A61DF43A722865C1DD245C1ABF0901885D`). Manifest inspection confirmed the existing application ID and no SMS-reading permissions. A pre-existing `flutter_foreground_task` Kotlin Gradle Plugin future-compatibility warning remains. No connected Android device was present in `adb devices -l`. Provider acceptance, handset receipt, physical retrieval and live verification remain separately **Not Verified**.
- Business Process DOCX was structurally inspected for Client/Provider registration requirements; no source document was edited. The immutable state template remains unchanged.

## Phone Input Correction Validation — 2026-09-10

- **Passed:** `dart format --output=none --set-exit-if-changed lib test` (61 files unchanged), `flutter analyze --no-pub` (no issues), and `flutter test --no-pub --reporter expanded` (**120 tests**). The focused phone suite passes 23 cases. Coverage includes both purposes, legacy extra fields (including malformed values), empty initial/resend input, no verification/session write while waiting, deliberate leading-zero paste/manual input, early and matching SMS, obsolete generations/references, duplicate delivery after editing, errors, cancellation and delayed server-success routing.
- **Passed:** `pnpm --filter @weyonje/api test` (**23 suites / 131 tests**); **four isolated PostgreSQL tests skipped** because TEST_DATABASE_URL and TEST_DIRECT_URL are absent. Fake gateways cover all five phone-challenge HTTP endpoints without exposing codes. Nest file-loading tests cover retained SMS keys and process-variable precedence. No database migration or shared-data operation ran.
- **Passed:** `pnpm typecheck`, `pnpm build`, `pnpm openapi:generate`, `pnpm openapi:check`, Prettier checks on changed API sources/tests, and `git diff --check`. The generated phone schema loses only its development-code property; the unrelated account-security schema retains its existing contract.
- **Visual verification:** Existing Flutter goldens matched without updates. Waiting, red invalid, green success, 2× text and keyboard-open renders were inspected; text wraps and controls remain scrollable/reachable. These are simulated layout checks, not physical keyboard/TalkBack evidence.
- **Debug APK passed:** `flutter build apk --debug --no-pub --dart-define-from-file=config/auth.local.json --build-number=20260910`. Artifact: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`; version 0.1.0 / code 20260910, 171411948 bytes, SHA-256 `066E875740BFF9D0F67F977C81E075AA229ADD9CB37D621B73A7B2E0977A35D5`. It explicitly targets `https://weyonje-api-production.up.railway.app` with mobile environment development and NativeAuthRepository. Manifest label/package remain Weyonje / ug.go.kcca.weyonje.weyonje; no READ_SMS or RECEIVE_SMS permission. Existing flutter_foreground_task Kotlin Gradle Plugin future-compatibility warning remains.
- **External limits:** No connected Android device, SMS send, simulator/handset receipt, physical autofill, full external authentication, or Railway variable/process verification in this correction. Operator deployment and authorized device testing remain separate steps; existing live credentials were preserved, with no new paid service switch. Root .env values were unchanged; .env.example comments now explain fake waiting behavior. The current-state master template is unchanged.

## Current Priorities and Remaining Limitations

### Railway startup fix validation — 2026-09-10

- `pnpm build` and `pnpm --filter @weyonje/api typecheck` passed.
- Focused `maps.module.spec.ts` and `access-token.guard.spec.ts`: **2 suites, 8 tests passed**. The real Maps/Auth module imports initialize under Nest/Fastify; requests without authentication return 401, and a locally signed token reaches the Maps handler after session authentication. Database/session and Maps operations use local fakes; no external service was contacted.
- This verifies the affected module startup and guard wiring, not full production startup or Railway recovery. Deployment and a subsequent health/startup check remain outstanding. Earlier API and mobile evidence above was not rerun by this fix.

The requested mobile changes are **Implemented** with local build, widget and rendered visual verification. Next device-dependent checks are installation/launcher rendering on an authorized Android device and physical keyboard, accessibility and platform integration behavior. Full-logo tagline legibility at small launcher sizes is inherently limited. External integration and infrastructure maturity remain **Partially Implemented / Unverified** as identified in the capability and external-validation tables; this change does not resolve those gaps.

## Change History

| Date | Version | Change | Evidence |
| --- | --- | --- | --- |
| 2026-09-10 | 8.1 | Remove response-driven OTP verification and resolve local API root configuration | Regression suites and contract checks; device/Railway verification pending |
| 2026-09-10 | 8.0 | Automatic phone verification, Android Retriever, provider acceptance and atomic completion | Local code/tests/build; external SMS/device/database evidence pending |
| 2026-09-10 | 7.0 | Fix MapsModule authentication dependency import causing Railway startup failure | Build, API typecheck and 8 focused tests passed; Railway recovery pending deployment |
| 2026-09-10 | 7.0 | Android launcher identity, Forui controls/touch sizing, Title Case, four welcome actions and presentation-only Provider/KCCA sign-in context | Mobile sources, 85 tests, 22 visual cases, debug APK and packaged-resource inspection |
| 2026-08-20 | 6.0 | Reliable delivery, account security and operational integrations | Historical validation above |

## References

- `apps/mobile/README.md`: regeneration procedure, routing, UI conventions and local commands.
- `MOBILE_APPLICATION_TRACEABILITY_AND_DECISIONS.md`: adopted requirements and retained business boundaries.
- `AI_CODING_AGENT_RULES.md`, `MOBILE_UI_UX_DESIGN_RULES.md`, `BRAND_IDENTITY_GUIDELINES.md`: current Forui, writing and launcher packaging rules.
- `CURRENT_SYSTEM_STATE_TEMPLATE.md`: immutable structure and status/evidence rules; unchanged.

## Authority boundary

No external account, database, deployment, Railway setting, Google/Firebase resource, credential, billing configuration, real message, Git commit, push or destructive data action was performed. `CURRENT_SYSTEM_STATE_TEMPLATE.md` remains unchanged.

### Default SMS sender integration follow-up (2026-09-10)

The optional sender configuration omits the provider `from` field when blank. Local live settings use this supported route for the shared registration/sign-in SMS service. API regression suite: 124 passed, four isolated PostgreSQL tests skipped; targeted Flutter authentication/verification suite: 67 passed. API typecheck passed. No additional SMS sends or deployment performed.

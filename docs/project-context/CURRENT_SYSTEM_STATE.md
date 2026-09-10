# Weyonje Current System State

> Evidence-based repository snapshot. “Implemented” means connected repository behavior; credential-dependent behavior is separately marked unverified.

## Document control

| Field | Value |
| --- | --- |
| Document version | 7.0 |
| Last updated | 2026-09-10 |
| Verified against | Local repository at `D:\Dev\weyonje`; no deployment, shared database, external account, billing action, or secret was accessed or changed |
| System version | Mobile `0.1.0+1`; API/contracts `0.1.0` |

## Current project summary

Weyonje is a pnpm monorepo containing a Flutter Android application, NestJS/Fastify API, Prisma/PostgreSQL persistence, shared TypeScript contracts, and generated OpenAPI. Authentication is native Weyonje authentication. Railway remains the confirmed GitHub-connected deployment target. PostgreSQL remains authoritative; no Valkey, Redis, BullMQ, Firebase Authentication, or Firebase database was introduced.

The established Client request, marketplace and Call Centre ingress, atomic Provider acceptance, collection, feedback/follow-up, disposal, persisted GPS, Socket.IO hint, and REST-reconciliation behavior is preserved. Revision 6.0 added a PostgreSQL delivery worker, recovery and verification challenges, authorised KCCA administration, Google Maps adapters, foreground journey coordination with a bounded encrypted offline queue, FCM installation lifecycle, and scheduled reminder creation.

## Capability status

| Capability | Status | Repository reality |
| --- | --- | --- |
| Native authentication/registration | **Implemented** | Existing session rotation, phone verification, Provider review and role eligibility remain server-authoritative. |
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

The change remains inside mobile presentation, launcher packaging, tests and documentation. Auth controllers, session lifecycle, API contracts, worker/database/integration/deployment code are unchanged. No environment variables were added or changed.

## Data and migrations

Forward-only migrations added after the established workflow migration:

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

## Provisional location and retention policy

The API supplies the adopted development defaults: 15-second interval, 25-metre movement, 75-metre arrival radius, 50-metre maximum arrival accuracy, 60-second stale threshold and 90-day server retention. The offline mobile queue is bounded to 200 samples and 24 hours. These values, foreground disclosure, consent, final retention/purge, arrival rules, battery policy and production background behavior require KCCA/privacy approval. A journey-position purge processor is **not implemented**.

## External and live validation status

| Integration | State |
| --- | --- |
| Google Maps Platform | **Unknown / Not Yet Verified.** Requires authorised non-production Google Cloud project, billing/quota budget and alerts, Maps SDK for Android, Places API (New), Geocoding API, Routes API, restricted Android key and separate restricted server key. |
| Firebase/FCM | **Unknown / Not Yet Verified.** Requires authorised Firebase project, Android app registration/config, Railway service credentials and physical-device foreground/background/terminated tests. |
| SMS/email | **Temporarily Disabled/Fake.** Fake SMS/email/push are prohibited in the Weyonje production environment. No real message was sent. Live email provider remains unselected. |
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

## Current Priorities and Remaining Limitations

### Railway startup fix validation — 2026-09-10

- `pnpm build` and `pnpm --filter @weyonje/api typecheck` passed.
- Focused `maps.module.spec.ts` and `access-token.guard.spec.ts`: **2 suites, 8 tests passed**. The real Maps/Auth module imports initialize under Nest/Fastify; requests without authentication return 401, and a locally signed token reaches the Maps handler after session authentication. Database/session and Maps operations use local fakes; no external service was contacted.
- This verifies the affected module startup and guard wiring, not full production startup or Railway recovery. Deployment and a subsequent health/startup check remain outstanding. Earlier API and mobile evidence above was not rerun by this fix.

The requested mobile changes are **Implemented** with local build, widget and rendered visual verification. Next device-dependent checks are installation/launcher rendering on an authorized Android device and physical keyboard, accessibility and platform integration behavior. Full-logo tagline legibility at small launcher sizes is inherently limited. External integration and infrastructure maturity remain **Partially Implemented / Unverified** as identified in the capability and external-validation tables; this change does not resolve those gaps.

## Change History

| Date | Version | Change | Evidence |
| --- | --- | --- | --- |
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

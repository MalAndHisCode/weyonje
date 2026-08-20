# Weyonje Current System State

> Evidence-based repository snapshot. “Implemented” means connected repository behavior; credential-dependent behavior is separately marked unverified.

## Document control

| Field | Value |
| --- | --- |
| Document version | 6.0 |
| Last updated | 2026-08-20 |
| Verified against | Local repository at `D:\Dev\weyonje`; no deployment, shared database, external account, billing action, or secret was accessed or changed |
| System version | Mobile `0.1.0+1`; API/contracts `0.1.0` |

## Current project summary

Weyonje is a pnpm monorepo containing a Flutter Android application, NestJS/Fastify API, Prisma/PostgreSQL persistence, shared TypeScript contracts, and generated OpenAPI. Authentication is native Weyonje authentication. Railway remains the confirmed GitHub-connected deployment target. PostgreSQL remains authoritative; no Valkey, Redis, BullMQ, Firebase Authentication, or Firebase database was introduced.

The established Client request, marketplace and Call Centre ingress, atomic Provider acceptance, collection, feedback/follow-up, disposal, persisted GPS, Socket.IO hint, and REST-reconciliation behavior is preserved. This revision adds a PostgreSQL delivery worker, recovery and verification challenges, authorised KCCA administration, Google Maps adapters, foreground journey coordination with a bounded encrypted offline queue, FCM installation lifecycle, and scheduled reminder creation.

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

## Validation evidence

- Baseline before edits: root typecheck passed; 20 API suites/97 tests passed with isolated PostgreSQL skipped; OpenAPI drift passed.
- Changed API: Prisma format/generation and validation, root TypeScript checks/build, and OpenAPI generation/drift pass. The final API run passed 21 suites and 103 tests; one suite/three tests were intentionally skipped because isolated PostgreSQL URLs were unavailable.
- Mobile: Dart formatting and analysis pass with no issues. The full Flutter run passed 55 tests. Four affected sign-in goldens were intentionally refreshed and visually inspected. The final route-enabled debug APK was built at `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (239,176,990 bytes; SHA-256 `23A82D0F886D348BEDEBBDC031F79879A4C92E40C7031FECFCBE25E611EFC151`).
- DOCX structural extraction completed. Visual DOCX rendering was unavailable because LibreOffice/`soffice` is absent.

## Authority boundary

No external account, database, deployment, Railway setting, Google/Firebase resource, credential, billing configuration, real message, Git commit, push or destructive data action was performed. `CURRENT_SYSTEM_STATE_TEMPLATE.md` remains unchanged.

# Weyonje Mobile Application Traceability and Decision Register

> **Status:** Active implementation register
>
> **Updated:** 2026-08-20
>
> **Evidence boundary:** Local repository and synthetic/fake validation only unless explicitly stated.

## Evidence precedence

Working code/migrations are implementation truth, followed by `CURRENT_SYSTEM_STATE.md`, the approved decisions in the 2026-08-20 continuation brief, adopted repository rules, then the screen-flow and Business Process specifications. Authentication is native Weyonje authentication, persistence is Prisma/PostgreSQL, hosting is Railway, Maps is Google Maps Platform, and FCM is push-only. No older Keycloak, TypeORM, Koyeb, Render, API-only KCCA UI, or Valkey/BullMQ assumption applies.

## Screen and capability traceability

| Area | Mobile | API/persistence | Current verification / remaining work |
| --- | --- | --- | --- |
| Existing authentication, Client registration, Provider registration, phone verification and role routing | **Implemented** | Native sessions, throttling, encryption/HMAC, eligibility | Existing flow tests preserved. |
| KCCA password recovery | **Implemented** | Challenge tables, HMAC secret, fake SMS/email outbox, throttling, expiry, attempts, supersession, one-time use, session revocation, security audit | Challenge/migration tests pass; HTTP/service security matrix and live delivery remain incomplete. |
| Email verification | **Implemented foundation** | Phone/email challenge, resend/supersession, verification timestamp, audit, fake delivery | No access gate imposed pending a KCCA rule for Provider/KCCA unverified-email eligibility. |
| Client request location | **Partially Implemented** | Authenticated Places/reverse/Routes server adapter | Client request entry uses explicit Yes/No, a compact non-interactive preview and a full-screen tap picker with direct numeric entry; read-only Service Location shows coordinates without geocoding. Journey route polyline/distance/ETA remain. Live keys, quota/error validation, KCCA map embedding and broader map widget tests remain. |
| Client/Provider journey tracking | **Partially Implemented** | Persisted idempotent samples, Socket.IO hints, REST snapshot | Map markers and foreground service/offline queue exist; physical background/OEM/permission validation remains. |
| Manual Call Centre request entry | **Partially Implemented** | Separate permission; Client lookup, eligible Provider query, request list/create/detail/assignment/feedback | Mobile create/find/assign/list exists. Dedicated mobile feedback and permitted reassignment detail controls remain. |
| KCCA Provider administration | **Implemented** | Separate permission; filtered lists/detail/decision/status endpoints; append-only histories; durable notification/outbox | Mobile pending/approved/rejected/inactive/disabled lists and confirmed actions exist. Additional widget/authorization HTTP tests remain. |
| KCCA disposal-site administration | **Partially Implemented** | Catalogue audit, active-only assignment, immutable assignment history, post-start reassignment rejection | Mobile list/create/edit/activate/deactivate exists. Map embedding, assignment selection and history rendering remain. |
| KCCA monitoring | **Implemented** | Separate monitoring permission and Socket.IO/REST authorization | Administration permissions no longer accidentally grant monitoring. Map/route enrichment remains partial. |
| Notifications and FCM | **Implemented behind fake/live boundary** | Encrypted per-installation tokens, Firebase Admin/fake gateways, invalid-token removal, delivery attempts | Firebase project/config and device foreground/background/terminated tests remain external. Foreground messages reconcile through in-app REST rather than displaying sensitive payload authority. |
| Scheduled reminders | **Implemented for creation/delivery/withdrawal eligibility** | Transactional scheduled outbox events, offset config, restart-safe claims, eligibility recheck, in-app/push | Client withdrawal now exercises CANCELLED delivery exclusion; timing is not editable. Already dispatched messages cannot be recalled. |
| Reliable delivery | **Implemented locally** | PostgreSQL leases, skip-locked claims, attempt history, backoff, dead-letter, crash lease recovery, cleanup, health, worker | Two-processor real PostgreSQL test is opt-in and skipped without isolated URLs. Railway worker service is not created. |

## Phone Verification Input Correction — 2026-09-10

**Implemented:** The user’s no-bypass requirement and Business Process Client registration steps 5–8 require SMS/input before verification and number assignment. Confirmed cause: initial/resend screen fill from developmentVerificationCode, exposed by the fake-provider API, triggered automatic submission without SMS. Removed the fill/hint and phone-contract field; legacy extras are ignored even in debug. Deliberate manual/paste, supported platform autofill and current matching SMS still submit six digits automatically. Existing server verification, red/checking/green states, expiry, cooldown, cancellation, session recovery and Provider restrictions are preserved. Duplicate consumed SMS candidates cannot overwrite manual edits. API root .env loading is explicit and SMS keys survive the general whitelist before SMS-specific validation, so the documented local command uses existing authorized settings; Railway settings remain separate. See current state for regression/build evidence.

## Phone Verification Completion — 2026-09-10

- **Implemented locally:** Native registration/Client sign-in endpoints and session authority are retained. Shared Forui six-box verification submits complete changed input, preserves leading zeroes/manual/paste, announces checking/error/success and shows green success for 650 ms before actor routing. Resend, expiry, exhaustion, transient failures, abandonment and saved-session recovery have distinct guarded behavior.
- **Implemented locally:** Service Provider description is exactly **Receive and Handle Service Requests**. Client conditional fields and post-verification account numbering remain unchanged.
- **Implemented; device evidence pending:** First-party SMS Retriever starts before request/resend, buffers UUID-scoped transient candidates and needs no broad SMS permission. Optional trusted server hash comes from actual package/certificate identity. Existing package/signing configuration is preserved.
- **Implemented locally:** Provider-neutral TTL/hash composition, strict Africa's Talking recipient acceptance, guarded fake, no blind retries, resumable pending registration, issuance locks and atomic OTP/account/session completion. No outbox, identity-store or schema redesign.
- **Configured but device/deployment unverified (rechecked 2026-09-10):** The earlier invalid-username finding is superseded: ignored local settings pass SMS validation and select Africa’s Talking live, with existing credentials and no custom sender. Historical connection-test acceptance is recorded in the setup guide. Mobile local defines target Railway, whose resolved SMS provider is not verified by local settings. No device or isolated PostgreSQL URLs are available; handset receipt, physical autofill and complete external authentication remain unverified.

## Adopted decisions

### D-17 — Provider Phone Sign-In and Temporary Automatic Approval — 2026-09-11

The current user-authorized requirement supersedes earlier Provider password and mandatory manual-review decisions. Provider registration keeps required email/business fields but stores no password; the backend rejects Provider password authentication/recovery. The existing Provider route now uses typed shared phone OTP UI and explicit Provider-purpose endpoints. Registered account phone and server eligibility remain authoritative.

The exact Service Provider Sign In labels, scoped registration Title Case and red KCCA Approval Required heading without explanatory paragraph are adopted. The heading remains exact even while manual review is temporarily bypassed by SERVICE_PROVIDER_AUTO_APPROVAL_ENABLED. This flag defaults false, is true only in authorized local configuration, and does not change KCCA administration controls or historical accounts. Approval, WSP numbering, null-human system provenance, history/audit/notifications and session completion are atomic after registration OTP verification. Disabled policy retains review notifications/manual decisions.

Pending registration recovery preserves stored profiles. Historical hashes/sessions remain; older Provider apps require an update. Migration → API → explicit target policy → mobile is the rollout order. See PHONE_VERIFICATION_SETUP.md and current-state revision 9.5 for tests and limits; no shared migration, remote activation or live SMS is claimed.


### Mobile Branding and Access Entry Update — 2026-09-10

- **Implemented:** Android display name `Weyonje`; complete-logo legacy, round and adaptive launcher resources, preserving application ID `ug.go.kcca.weyonje.weyonje`, source asset, signing, deep links and splash configuration.
- **Implemented:** Four welcome actions in the requested order, with no explanatory paragraph. Historical 2026-09-10 behavior (superseded by D-17): `/sign-in?entry=provider` and `/sign-in?entry=kcca` shared the native email/password form and `/v1/auth/sign-in`. Missing/invalid `entry` preserves the compatible generic form. Context never reaches authentication or authorization code. Cross-role credentials follow the server-resolved actor and restricted Provider state. Recovery back navigation preserves the selected entry.
- **Implemented:** Forui 0.25.0 standard controls, central semantic palette and touch sizing, shared select/dialog wrappers, and authored Title Case headings/actions. Native pickers/maps/platform integrations remain in place. Existing typography/icon dependencies and light-only behavior remain.
- **Implemented:** Choose Account Type descriptions and Client Registration form labels use scoped conventional Title Case, including conditional labels and Required/Optional indicators. This is a presentation exception for these two screens only; no runtime title-casing or application-wide field-label policy was introduced.
- These adopted requirements supersede the former combined welcome action, account-creation paragraph, sentence-case heading/button guidance, and minimum-logo-size restriction for Android launcher packaging only.
- Validation: see the dated mobile validation evidence in `CURRENT_SYSTEM_STATE.md`; earlier API/integration validation below remains historical.

| ID | Decision | Applied behavior |
| --- | --- | --- |
| D-01 | Authentication | Native Weyonje sessions only; no Keycloak/OIDC/PKCE/Firebase Auth. |
| D-02 | Persistence | Prisma/PostgreSQL only; no TypeORM or second authoritative database. |
| D-03 | Hosting | Railway API plus a smallest-safe separate Railway worker in production. Repository code/commands only; no service was created. |
| D-04 | Reliable work | PostgreSQL outbox and worker; no Valkey/BullMQ. |
| D-05 | Fake delivery | SMS/email/push fakes only outside Weyonje production; plaintext codes are neither logged nor stored. Phone challenge responses never expose codes, including fake delivery; unrelated account-security fake contracts are unchanged. |
| D-06 | Maps | Google Maps SDK key is Android-restricted. Places/Geocoding/Routes use a separate server credential through authenticated Weyonje endpoints. PostgreSQL samples, not Google routes, are journey history. |
| D-07 | FCM | FCM is a hint/delivery channel only. Device tokens are protected and revoked/invalidated. REST notifications remain authoritative. |
| D-08 | Location | Start follows explicit authorised journey action; provisional 15-second/25-metre policy comes from API. Foreground service does not claim force-stop survival. Offline queue is encrypted, chronological, 200 samples/24 hours. |
| D-09 | Timing/reminders | Every request carries ASAP or scheduled; the redesigned Client form selects ASAP without timing controls. Only scheduled requests create reminders. Default provisional offsets are 1440 and 120 minutes. |
| D-10 | Call Centre | Authorised KCCA mobile manual entry is approved. It is not a separate external system. Permission is enforced in API and routing. |
| D-11 | Provider administration | Existing Provider state model is extended with append-only status history; no parallel approval model. |
| D-12 | Disposal | KCCA owns catalogue/assignment. Assignment change is refused after the disposal journey starts and every change is retained. |
| D-13 | Feedback | Rating is whole-number 1–5. Negative follow-up is separate. `LEFT_INCOMPLETE` permits disposal; `NOT_DONE_AT_ALL` does not. |
| D-14 | Marketplace/price | All approved active Providers see eligible marketplace work; acceptance is atomic. UGX price is an integer from 0 through 1,000,000,000. |
| D-15 | Email verification gate | Token/delivery/UI foundation is implemented, but no new access restriction is enforced until KCCA confirms whether Provider or KCCA access must wait for email verification. |

## External validation gates

- Google Cloud: authorised non-production project, billing/quota budget and alerts, enabled Maps SDK for Android/Places API (New)/Geocoding API/Routes API, Android package plus signing-certificate restriction, separate server-key restriction, and live failure/quota tests.
- Firebase: authorised project and Android app, non-secret Android configuration supplied outside source control, Railway service-account variables, key ownership/rotation, and real-device foreground/background/terminated tests.
- Railway: explicit authorisation to create a worker service, set private variables, apply migrations, configure monitoring and validate graceful shutdown/backlog.
- PostgreSQL: separately isolated `TEST_DATABASE_URL` and `TEST_DIRECT_URL` for migration, locks, competing processors and cleanup. Never use a shared database.
- KCCA/privacy: final location frequency, distance/arrival thresholds, consent/disclosure, background behavior, offline/server retention and purge policy.
- Business decision: whether unverified Provider or KCCA email blocks access. The foundation remains non-blocking meanwhile.

## Historical Validation Register — 2026-08-20

- Baseline root typecheck, API tests and OpenAPI drift passed before changes; isolated PostgreSQL was skipped.
- Current Prisma format/generate and API TypeScript checks pass.
- Current OpenAPI generation and drift check pass.
- Focused challenge/environment/migration tests: 13 passed.
- Full Flutter test suite: 55 passed, including intentionally refreshed and visually inspected sign-in goldens.
- Dart analysis: no issues.
- Final route-enabled debug APK build passed; its path, byte count and SHA-256 are recorded in `CURRENT_SYSTEM_STATE.md`.
- Live Maps, Firebase, email, Railway worker, shared migration and physical Android background tests were not performed.
- Business Process DOCX was structurally reviewed; page rendering was unavailable because `soffice` is absent.

This register no longer contains the former approval gate that prohibited authorised KCCA mobile Call Centre, Provider, or disposal administration.

## Client Sign-In to Registration and OTP Recovery — 2026-09-10

**Adopted user change / implemented locally:** Explicit Client-code submission distinguishes genuine normalized-phone absence and opens existing Client Registration with editable in-memory prefill. This supersedes the former unknown-number dummy sign-in challenge behavior and intentionally reveals only the registration distinction. Registration remains an explicit form submission, consistent with Client Self-Registration steps 4–8. Existing ineligible accounts cannot bypass state through registration; pending recovery preserves the stored profile.

The existing request operation gains a typed registration-required alternative; existing eligible challenge fields remain unchanged. Separate protected phone/IP request counters reuse AUTH policies and the existing table with transaction locks. Safe retryAt/limitCategory errors survive API filtering and mobile parsing. OTP failed-delivery accounting, hourly limits, cooldowns, expiry, attempts and atomic one-time completion are retained. No issuance loop was found; missing recovery timing and clearing a resend wait during code editing are addressed. The exact live incident remains unconfirmed.

Requested copy changes retain six-digit input/accessibility and distinct provider-error feedback. The no-response-autofill correction, matching SMS scope, manual/paste input, server-success transition and Provider/KCCA authority are unchanged. No deployment, schema or dependency change was made. Current state records validation and configuration evidence.

## Client Request Form and Warm Resume — 2026-09-11

**Implemented locally:** REQ-CL-001 now presents Request for a Service, Client Details (name, phone, nonempty email only), Location Details (exact Title Case question, explicit Yes/No, map, read-only Service Location), Service Details (mandatory Pit Latrine/Septic Tank), Additional Contact Details (paired optional name/conditional phone), Submit Request, secondary Check My Requests. Client details now use individually labeled read-only Forui text boxes. This user decision supersedes text-only Client form entry and undefined toilet requiredness in the original specification. The existing picker route remains compatible and returns explicitly selected coordinates immediately; it does not create a request.

**Adopted timing decision:** The replacement form submits AS_SOON_AS_POSSIBLE and omits requestedServiceAt. Other APIs, Call Centre, historical records and scheduled reminders keep existing timing support. No nullable scheduling change or historical backfill.

**Boundaries:** Authenticated GET /v1/client/profile returns only clientName, phoneNumber and optional emailAddress; creation derives authoritative account data independently. A Client-specific DTO/service check requires toilet type without altering shared Call Centre rules. Foreground access checks run at entry, resume and submit. Yes captures once and locks manual selection; No opens a full-screen map with immediate explicit tap return and cancellation preserving the prior point. Obsolete acquisition and dismissed-picker callbacks are discarded. Service Location displays coordinates without geocoding; inline maps are previews only. Request UUID survives unchanged retries; uncertain submission locks edits for same-key recovery. My Requests navigation preserves the mounted form and never interprets list contents as proof of rollback.

**Confirmed resume defect:** LaunchChecking during warm revalidation triggered /launch and discarded the mounted request route. Background checks now preserve authenticated state on transient failure, while invalid/revoked/denied outcomes retain safe routing. Cancellation/generations and refresh coalescing protect logout and account changes. In-memory route/draft/scroll preservation is implemented; process-death drafts are Not Implemented.

**External status:** The user confirmed weyonje-dev. Four required Google APIs and an Android debug credential restricted by verified package/SHA-1 and Maps SDK for Android are configured. Trial untouched. Server credentials await approved fixed egress; Railway Trial lacks the documented Pro static-egress feature and its production-named service reports an invalid ams region. Quota editing/alerts were disabled in the inspected Geocoding UI. Local Android key installation and Maps-enabled APK are complete following the user's no-extra-expense instruction. Server integration is deferred; backend deployment and physical-device checks remain pending. The user will test the APK on their own phone. See ../CLIENT_REQUEST_AND_MAPS_SETUP.md and CURRENT_SYSTEM_STATE.md for configuration and final validation evidence.


## Client Coordinate Picker and Submission Correction — 2026-09-11

REQ-CL-001/002 now use bold semantic section headings, a compact non-interactive preview and Select Location on Map. The picker fills the safe screen; taps return immediately, gestures never select the camera center, and explicit numeric entry provides accessibility. Reload Map, Choose Location in Full Screen, Confirm Location and Retry Address are removed from this Client flow. No new server Maps credential is needed.

Confirmed local submission defect: mobile serialized scheduleMode as ASAP; strict HTTP enum validation rejected it before service creation and the exception filter hid the field. Mobile now sends AS_SOON_AS_POSSIBLE. Safe owned validation messages retain the existing error contract. Real-service HTTP tests with isolated persistence fakes cover creation, details, retry and invalid input; native-map/device and live rollout evidence remain separate. No validation weakening, migration, dependency or configuration change. See CURRENT_SYSTEM_STATE.md for final validation results.


## Client Presentation and Incident Diagnostics — 2026-09-11

REQ-CL-001/003: Labeled read-only profile boxes preserve optional email and authenticated identity authority. Selecting **No** places Select Location on Map immediately above its preview. Check My Requests always follows Submit Request with secondary emphasis, guards navigation/submission overlap and returns to the same draft/key. When entered from the form the list offers Return to Request; empty/failed lists do not unlock or allocate a fresh attempt. The redundant warning is removed in favor of one actionable uncertain-status alert; definite rejection and success keep separate semantics.

The later Railway deployment a77cc5c2 (commit c153536) is verified, superseding earlier rollout assumptions. The reported unexpected POST exception remains unresolved because its logs omit the underlying exception/stage. Safe stage/category/Prisma-code diagnostics and regression tests now cover transactional failures and post-commit read/mapping recovery; the prior schedule enum correction is retained but does not explain this incident. No schema/config/dependency change or deployment was performed. See CURRENT_SYSTEM_STATE.md for validation, fake-versus-PostgreSQL limitations and precise remaining evidence.

## Client Request Management — 2026-09-11

**Adopted user requirement; implemented locally:** REQ-CL-001/003/004 and Client Dashboard gain saved read-only details/map, modest Recent Requests spacing, explicit edit mode and confirmed withdrawal. This supersedes the original specification's absence of Client cancellation. Only an active Client's own unaccepted PENDING MOBILE_APP request qualifies; linked Call Centre requests do not. Provider contact/location disclosure and later workflow actions remain unchanged.

**Integrity decision:** Delete means auditable PENDING → CANCELLED withdrawal, retaining the row/reference/history. No physical deletion, restoration or reassignment is exposed. Conditional update also checks workflow evidence and the authoritative millisecond updatedAt token; edits advance it monotonically, so no migration is needed. Serializable operation/request/actor-scoped idempotency reuses bounded conflict retry and returns current details on replay. Audit/history and mutation commit atomically. A stale draft cannot overwrite a newer edit or accepted/cancelled work. Uncertain outcomes retain their payload/key; HTTP failures and empty lists do not unlock them.

**Compatibility decision:** New requests from the shared generator use KCCA- with the existing random suffix/UUID/unique constraint. Historical WRQ- references remain valid and unchanged. Any renumbering is a separate reviewed data operation. Edit replaces coordinates/location mode/toilet/paired contacts with explicit null clearing and preserves scheduling, identity, ID and reference. Existing create and Call Centre contracts retain their semantics.

**Evidence boundary:** HTTP/persistence-fake tests cover authorization, validation, round trips, cancellation, stale versions, idempotency, rollback and post-commit recovery. Opt-in real PostgreSQL race tests were added for edit/accept, withdrawal/accept and competing edits; isolated test URLs remain unavailable. Widget renders use a fake map and do not establish native Google tiles or physical accessibility. See CURRENT_SYSTEM_STATE.md revision 9.4 for completed gates and rollout limits. No environment, dependency, migration or external deployment change.

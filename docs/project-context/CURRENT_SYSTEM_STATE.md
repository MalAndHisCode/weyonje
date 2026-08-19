# Weyonje Current System State

> Evidence-based repository snapshot. Requirements, proposed hosting, and external services are not treated as operational without validation evidence.

## Document control

| Field | Value |
| --- | --- |
| Document version | 5.0 |
| Last updated | 2026-08-19 |
| Verified against | Local repository at `D:\Dev\weyonje`; no deployment, external account, live database, billing action, or secret was accessed or changed |
| System version | Mobile `0.1.0+1`; API/contracts `0.1.0` |

## Current project summary

Weyonje is an Android Flutter application backed by a NestJS/Fastify modular-monolith API and PostgreSQL/Prisma persistence. The repository implements native authentication and registration plus the mobile Client, Service Provider, and permitted KCCA operational journeys described by the supplied mobile flow.

The implemented development slice now includes service-request creation, marketplace/Call Centre ingress, atomic Provider acceptance, Provider jobs, collection confirmation and 1–5 feedback, separate negative follow-up cases, KCCA-controlled disposal-site assignment, disposal completion, persisted journey positions, in-app notifications/outbox, authenticated Socket.IO update hints, and REST reconciliation. The committed OpenAPI is generated from authentication, registration, actor, and workflow controllers.

This is still a development implementation. Railway is the user-confirmed deployment target, connected directly to GitHub with the service rooted at the repository root. Its live settings, deployment health, logs, migration state, WebSocket behaviour, and capacity were not inspected in this task. Neon remains an unverified database target. Google Maps, FCM/push, Africa's Talking operational delivery, production background tracking, outbox processing, scheduled reminders, retention purge, production load, and production operations have not been authorised or validated.

`AI_CODING_AGENT_RULES.md` still contains historical Koyeb-specific guidance. The user's Railway correction supersedes those hosting assumptions for current work; the supplied source document is intentionally left unchanged and should be revised separately by its owner.

## Implemented mobile flows

| Flow | Status | Repository reality |
| --- | --- | --- |
| Welcome, account type, registration, verification, sign-in, session recovery | **Implemented** | Existing native authentication/registration flows remain guarded, accessible, tested, and server-authoritative. |
| Client dashboard | **Implemented** | Loads pending/active/action-needed counts, recent requests, request entry, history, notifications, and sign-out. |
| Request a Service | **Implemented** | Requires text or coordinate location and either ASAP or a requested service date/time; supports toilet type and paired additional contact fields; uses an idempotency key. |
| Request Location Picker | **Partially Implemented** | Device location and validated coordinate entry work. The Google Maps boundary is explicit and truthfully unavailable until an authorised project/key is configured; no fabricated map/place data is shown. |
| Client requests/details | **Implemented** | Owned history/detail, schedule, status, Provider/price when available, tracking links, feedback action, disposal state, and separate follow-up state are rendered. |
| Collection feedback | **Implemented** | Mandatory 1–5 whole-number rating, outcome, and text feedback. Negative outcomes create a follow-up case. `LEFT_INCOMPLETE` records waste collected and does not block disposal; `NOT_DONE_AT_ALL` records no disposal work. |
| Provider dashboard/marketplace/request details | **Implemented** | Every approved, active Provider can see eligible mobile marketplace records. Before acceptance, exact location and Client contact PII are withheld. Call Centre assignments remain Provider-specific. |
| Atomic acceptance/rejection | **Implemented** | Conditional database transition gives first valid acceptance the request. Idempotency records replay retries and conflicting payload reuse fails safely. Call Centre assignments may be rejected/reassigned. |
| Provider jobs/job details | **Implemented** | Accepted jobs expose state-valid initiation, collection reporting, confirmation waiting, disposal start/tracking/completion, KCCA site, and follow-up messaging. |
| Journey/disposal tracking | **Implemented with provisional policy** | Device samples persist in PostgreSQL; API detects arrival from consecutive qualifying samples; Client/Provider/KCCA use authenticated Socket.IO hints and authoritative REST snapshots. Without Google Maps, coordinates/status are shown instead of a false map. |
| KCCA monitoring | **Implemented** | Read-only mobile list is protected by KCCA monitoring permission. Call Centre/disposal administration is intentionally API-only, not mobile UI. |
| In-app notifications | **Implemented** | Notifications persist durably, can be marked read, and every in-app notification also creates a transactional outbox record. |

## Implemented server and data capabilities

- Prisma models and forward-only migration `20260819120000_service_workflows` cover requests, assignments, status history, journeys/positions, collection reports, feedback, follow-up cases, disposal sites/assignments, notifications, outbox, idempotency, and audit events.
- Database constraints enforce request-origin ownership, location shape/ranges, ASAP-versus-scheduled shape, non-negative whole-number UGX price bounds, 1–5 ratings, feedback/outcome-to-waste consistency, negative-only follow-up cases, coordinate/accuracy ranges, and unique journey samples.
- Permission-protected Call Centre APIs use `callCentreOperationsPermitted`, valid only for KCCA Staff. Local provisioning supports `--call-centre-operations`.
- KCCA controls the active disposal-site catalogue and request assignment. Providers may view assigned sites but cannot choose or change them.
- Important state transitions create audit/status records and durable notifications/outbox records in the same database transaction.
- Push and operational-SMS boundaries are provider-neutral and deliberately unconfigured. Existing registration/Client-login verification SMS remains behind the Africa's Talking adapter.
- Socket.IO authenticates the native API access token/session, joins only actor/permission rooms, emits participant/KCCA update hints, and directs clients to reconcile authoritative state through REST.
- No Valkey, Redis, BullMQ, or separate worker is introduced in this slice.

## Confirmed decisions

| Decision | Confirmed behaviour |
| --- | --- |
| Rating | Mandatory whole-number `1–5`. |
| Negative collection feedback | Collection outcome and dispute/follow-up are separate records. A negative result never erases or mutates disposal state. If waste was collected (`LEFT_INCOMPLETE`), disposal remains available. |
| Requested service time | A request must choose `ASAP` or provide a future requested service date and time. The current scheduled horizon is 90 days. |
| Agreed price | UGX integer in `0..1,000,000,000`; no negative or fractional value. |
| Disposal destination | KCCA-controlled active approved-site catalogue and KCCA assignment; no Provider selection. |
| Marketplace eligibility | All approved, active Providers can see eligible mobile requests because no Provider-Type matching matrix is documented. Pre-acceptance response is deliberately minimal. |
| Acceptance concurrency | Atomic first-acceptance-wins with idempotent retries and stable `REQUEST_ALREADY_ACCEPTED`/`IDEMPOTENCY_CONFLICT` errors. |
| Call Centre | Native bearer authentication plus separate KCCA permission protects request creation, assignment/reassignment, feedback, disposal catalogue, and site assignment APIs. |
| Notifications/realtime | Durable in-app notification/outbox, SMS only for documented processes, provider-neutral push boundary, authenticated Socket.IO hints, REST reconciliation. |
| Worker infrastructure | No Valkey/BullMQ in this development slice. Reassess reliable dispatch/scheduling architecture before production. |
| External services | Use adapters/unconfigured implementations/fakes until non-production resources and credentials are separately authorised. |

## Provisional location policy

These values are environment-backed through the API and are not permanent hard-coded production rules.

| Setting | Initial development value | Approval state |
| --- | ---: | --- |
| Sample interval | 15 seconds | **Requires KCCA approval** |
| Sample distance | 25 metres | **Requires KCCA approval** |
| Arrival radius | 75 metres | **Requires KCCA approval** |
| Maximum accuracy for automatic arrival | 50 metres | **Requires KCCA approval** |
| Consecutive qualifying arrival samples | 2 | **Requires KCCA approval**; currently encoded in workflow service and must be externalised with the final policy |
| Stale-location threshold | 60 seconds | **Requires KCCA approval** |
| Background tracking flag | Enabled for active journeys in development configuration | **Requires KCCA/privacy/Android approval**; durable OS background execution and persistent notification are not production-complete |
| Precise-position retention | 90 days | **Requires KCCA legal/privacy approval**; purge processing is not implemented |

The mobile app stops its active tracking subscriptions when the tracking screen is disposed or the journey ceases to be active. Android permissions are declared, but reliable long-running background execution, persistent disclosure notification, logout-wide cancellation, battery behaviour, and OEM testing remain unresolved production work.

## Unresolved production decisions and limitations

| Item | Current status / production decision required |
| --- | --- |
| Location/legal policy | KCCA must approve arrival thresholds, sampling frequency/distance, stale threshold, background behaviour, consent/disclosure, retention, purge, access/audit, and incident handling. |
| Provider-Type matching | No mapping is documented. Universal approved/active eligibility is deliberate until KCCA approves a matrix. |
| Google Maps UX | Project, billing/quota, Android restrictions, service area, place search/geocoding, privacy terms, and failure policy are unapproved. Coordinate/device fallback is development-only. |
| Reliable outbox processing | Events persist transactionally, but no durable dispatcher, retry scheduler, dead-letter operation, or worker hosting exists. This is the principal no-Valkey/BullMQ limitation to reassess before production. |
| Scheduled reminders | Approaching-service reminders and durable scheduled execution are not implemented without an approved scheduler/worker boundary. |
| Socket.IO scale | One process works for development. Multi-instance fan-out, sticky sessions, reconnect/soak/load limits, and host WebSocket behaviour are unverified. |
| Push delivery | Provider-neutral gateway exists; FCM project, credentials, device-token lifecycle, consent, delivery policy, and non-production validation are absent. |
| Operational SMS | No live outbox processor is configured. KCCA must approve the exact event/channel matrix; only documented flows may use SMS. |
| Call Centre integration | APIs exist, but no live Call Centre system, service account, authorised client, contract test environment, or operational UI exists. |
| Disposal catalogue | API exists; no authorised production catalogue/site coordinates or governance process has been supplied. |
| Password recovery/email verification | Still not implemented for Provider/KCCA accounts. |
| Release readiness | Release signing, application ID confirmation, store/privacy declarations, accessibility/device QA, security review, monitoring, backups, recovery, HA, and production capacity remain unresolved. |

## Unverified integrations and development targets

| Integration | Repository boundary | Verification state |
| --- | --- | --- |
| Neon PostgreSQL | Prisma pooled runtime/direct migration configuration | **Unverified development target.** No project/database was accessed; migration not applied. |
| Railway | GitHub-connected service rooted at repository root | **Configured externally, user-confirmed.** This task did not inspect or change the Railway project, Variables, build/start settings, domain, logs, migration state, health, WebSocket behaviour, or capacity. |
| Google Maps | Explicit mobile map-selection boundary | **Unconfigured/unverified.** No project, key, billing, SDK metadata, or live call. |
| FCM / push | Provider-neutral server gateway with unconfigured implementation | **Unconfigured/unverified.** No Firebase resource or credential. |
| Africa's Talking | Existing verification SMS adapter; operational SMS boundary disabled | **Unverified.** No credential or live delivery used in this implementation pass. |
| Call Centre | Permission-protected REST contract | **Synthetic only.** No external caller or credential configured. |
| Socket.IO hosting | Authenticated in-process gateway | **Locally compiled only.** No Railway runtime or multi-instance validation in this task. |

## Validation evidence

Local checks cover Prisma format/validation/generation, TypeScript compilation, migration assertions, API unit tests, OpenAPI generation/drift, Flutter analysis, authentication/widget/visual tests, and Android debug compilation. The opt-in PostgreSQL suite remains skipped without separately approved isolated `TEST_DATABASE_URL` and `TEST_DIRECT_URL`; real constraint, migration, and acceptance-concurrency behaviour is therefore not yet database-verified.

The Business Process DOCX was structurally extracted and reviewed. Visual render verification could not be performed because LibreOffice/`soffice` is unavailable in this environment.

## Evidence and authority boundary

No external account, database, deployment, credential, billing configuration, Git commit, push, or production change was made. The Business Process Specification and mobile/AI/UI/brand source documents remain requirements/context and were not rewritten to make implementation appear compliant. `CURRENT_SYSTEM_STATE_TEMPLATE.md` remains unchanged.

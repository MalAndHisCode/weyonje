# Weyonje Mobile Application Traceability and Decision Register

> **Status:** Pre-implementation inspection register  
> **Prepared:** 2026-08-19  
> **Evidence boundary:** Local repository only. No external service, database, deployment, secret, billing account, or live integration was accessed or changed.

## 1. Source precedence and inspection findings

The repository is the implementation truth. `CURRENT_SYSTEM_STATE.md` records the adopted direction; `MOBILE_APPLICATION_SCREEN_FLOW_SPECIFICATION.txt` is the mobile implementation contract; and `BUSINESS_PROCESS_SPECIFICATION.docx` is the requirements baseline. `AI_CODING_AGENT_RULES.md`, `MOBILE_UI_UX_DESIGN_RULES.md`, and `BRAND_IDENTITY_GUIDELINES.md` constrain implementation.

`TECHNOLOGY_STACK.md` is absent. The implementation must therefore rely on the repository, current-state document, and applicable project rules. No `AGENTS.md` file is present.

The confirmed repository baseline is a pnpm monorepo with a Flutter Android application, NestJS/Fastify API, Prisma/PostgreSQL persistence, shared TypeScript contracts, and generated OpenAPI JSON. Authentication is native Weyonje authentication. The existing auth, registration, phone verification, session rotation, logout, role routing, `/me`, throttling, encryption, hashing, provider approval, and eligibility protections are adopted behaviour and must be preserved.

Inspection also found documentation and contract drift that must be corrected during implementation:

- Root and mobile READMEs still say registration and verification are not implemented, although repository code and tests implement them.
- `CURRENT_SYSTEM_STATE.md` says registration and Provider-review endpoints are present in committed OpenAPI, but `apps/api/openapi/openapi.json` and `scripts/openapi-document.ts` currently expose only authentication and `/v1/actors/me`.
- There is no generated Dart API client in the repository; the Flutter authentication client uses handwritten models and endpoint calls.
- The three role destinations are explicit unavailable pages. No downstream service-request, job, journey, feedback, disposal, or monitoring data model exists.
- The Business Process DOCX was structurally extracted in full. Visual rendering could not run because LibreOffice/`soffice` is unavailable.

## 2. Screen traceability

Status meanings: **Implemented** = functional repository behaviour with focused tests; **Partial** = some required behaviour exists but the screen contract is incomplete; **Not implemented** = route absent or route ends at the truthful unavailable boundary.

| Screen | Current mobile status | Current backend/persistence | Existing verification | Required completion | Decision dependencies |
| --- | --- | --- | --- | --- | --- |
| `AUTH-001` Welcome and Account Access | **Implemented** | Session bootstrap, role resolution, Client code sign-in and Provider/KCCA credential sign-in exist | Flutter flow and visual tests | Preserve behaviour; update only shared navigation needed by completed flows | None |
| `AUTH-002` Choose Account Type | **Implemented** | No record is created until form submission | Flutter selection, validation, repeated-navigation, responsive, large-text, and golden tests | Preserve behaviour | None |
| `REG-CL-001` Client Registration | **Implemented** | Client/profile persistence, protected phone/email data, verification challenge, Client number assignment | API service tests and Flutter flow/repository tests | Align OpenAPI/generated client and add broader validation/widget coverage without regressing optional email | None; adopted phone rules remain authoritative |
| `REG-SP-001` Service Provider Registration | **Implemented** | Provider/profile persistence, password hashing, phone verification, pending review and review notifications | API service tests and Flutter flow/repository tests | Align OpenAPI/generated client; preserve KCCA-controlled approval boundary | None; adopted password and approval rules remain authoritative |
| `REG-001` Phone Verification | **Implemented** | Six-digit challenge, expiry, attempts, resend delay/rate limit, HMAC storage, one-time consumption, Africa's Talking adapter | API phone security/challenge tests and Flutter flow/repository tests | Preserve adopted resend and security behaviour despite older screen-spec uncertainty; align contracts/client generation | None |
| `AUTH-003` Sign In | **Implemented** | Client phone-code sign-in; Provider/KCCA email-password sign-in; rotating server sessions | API HTTP/service/session tests; Flutter repository, flow, navigation, and visual tests | Preserve role-specific methods and session protections | None |
| `REG-SP-002` Provider Account Status | **Partial** | `/me` and provider status endpoint expose own status, number, and rejection reason | Eligibility and routing tests | Add explicit refresh, approved/active continuation, loading/error states, and notification-driven refresh while retaining work restrictions | Notification delivery decision affects live updates only |
| `HOME-CL-001` Client Dashboard | **Not implemented** | No request summary API or request persistence | Only verifies routing to an unavailable boundary | Real dashboard with Client number, request entry, owned request summaries, loading/empty/error/offline/session states | Service-request model and scheduling |
| `HOME-SP-001` Provider Work Dashboard | **Not implemented** | No marketplace, assignment, or jobs API | Only verifies routing to an unavailable boundary and restricted-provider denial | Real approved-provider work entry and required-action summaries | Eligibility/matching, Call Centre ingress, notifications |
| `HOME-KCCA-001` KCCA Monitoring Dashboard | **Not implemented** | KCCA mobile eligibility exists; no monitoring data API | Only verifies routing boundary and unpermitted denial | Read-only authorized journey monitoring list and notifications; no back-office controls | Call Centre ingress, real-time transport, notifications |
| `REQ-CL-001` Request a Service | **Not implemented** | No service-request model or endpoint | None | Persist owned request, profile snapshot/contact data, conditional location, toilet type, schedule, idempotency, Pending history and outbox | Schedule; location policy; toilet/provider matching |
| `REQ-CL-002` Request Location Picker | **Not implemented** | No location model or Google adapter | None | Google map picker behind an app-owned adapter, text alternative, permission/map failure recovery, confirmed coordinates returned to form | Google setup; service area/search policy; location policy |
| `REQ-CL-003` My Requests | **Not implemented** | No owned request listing/query | None | Paginated Client-owned summaries with status/action, stale/offline indication and safe refresh | Workflow state decisions |
| `REQ-CL-004` Client Request Details | **Not implemented** | No request detail, assignment, price, status history, or outstanding-action API | None | Owned detail view with valid actions, notifications, tracking and feedback links | Price, schedule, negative feedback, notifications |
| `REQ-SP-001` Pending Service Requests | **Not implemented** | No marketplace/assignment query | None | Eligible marketplace plus provider-specific Call Centre assignments, stale/taken handling, pagination and refresh | Matching, Call Centre ingress, atomic acceptance |
| `REQ-SP-002` Provider Request Details | **Not implemented** | No request decision, assignment, price, audit, or notification command | None | Authorized details, Client contact action, mobile price acceptance, Call Centre accept/reject, atomic/idempotent commands | Price, matching, Call Centre ingress, notifications |
| `JOB-SP-001` My Jobs | **Not implemented** | No Provider-owned job query or job state machine | None | Provider-owned accepted/active/confirmation/disposal/completed list and outstanding actions | Schedule and workflow decisions |
| `JOB-SP-002` Provider Job Details | **Not implemented** | No journey start, collection report, confirmation gate, or status history | None | Idempotent server transitions, permission recovery, foreground tracking lifecycle, confirmation gate | Location policy, negative feedback, real-time transport |
| `TRACK-001` Journey to Request Tracking | **Not implemented** | No journey session, position, arrival, or authorized snapshot/stream API | None | Authorized Client/KCCA tracking, freshness/accuracy/last-update states, textual alternative, arrival event | Location policy, real-time transport, Google setup |
| `FEED-001` Collection Confirmation and Feedback | **Not implemented** | No collection report, feedback, rating, or transition model | None | Client-owned, single-submit feedback with exact work outcome, rating validation, audit and disposal gate | Rating scale and negative-outcome rules |
| `DISP-001` Disposal Journey Monitoring | **Not implemented** | No disposal site, assignment, journey, position history, stopover, arrival, or completion model | None | Provider/KCCA authorized journey, actual route history, textual alternative, provider-only idempotent completion and final notifications | Disposal-site control, location policy, real-time transport, notifications |

## 3. Cross-cutting capability traceability

| Capability | Current status | Required work and tests |
| --- | --- | --- |
| Server workflow state machines | **Not implemented** for waste workflows | Central request/assignment/job/collection/disposal transitions; actor, eligibility, ownership, origin and current-state validation; stable errors; transition matrix unit tests |
| Atomic marketplace acceptance | **Not implemented** | Database-guarded first-writer-wins acceptance plus same-provider idempotent replay and competing-provider conflict tests against PostgreSQL |
| Idempotency | **Not implemented** for consequential business commands | Actor/operation-scoped keys and persisted result/fingerprint; conflicting key reuse rejection; retry tests |
| Business audit/history | **Provider approval only** | Append-only request status, assignment, price, collection, feedback, disposal and consequential-command audit records |
| Notifications/outbox | **Registration notification records only** | General notification and transactional outbox models, policy, deduplication, retry state, deterministic channel fakes, mobile inbox/poll or push integration according to approval |
| Maps/location | **Not implemented** | Project-owned Google and device-location adapters, journey sessions/positions, ordering/accuracy/freshness/arrival rules, consent/permission lifecycle and retention |
| Real-time updates | **Not implemented** | Approved transport with REST reconciliation, authorization, reconnect/order/deduplication tests |
| Call Centre integration boundary | **Not implemented** | Server-only creation, assignment/reassignment and feedback commands with separate permissions and synthetic integration tests; no mobile back-office UI |
| Contracts/OpenAPI/Dart client | **Drift/incomplete** | Add registration and all new endpoints to OpenAPI, establish one reproducible generated Dart client and fail drift checks |
| PostgreSQL integration | **Partially tested, currently skipped** | New forward migration plus opt-in isolated PostgreSQL tests for constraints, transactions, concurrency and migrations; never use shared Neon data |
| Mobile non-success states | **Strong for authentication, absent downstream** | Controller/repository/widget/navigation coverage for loading, empty, stale, offline, timeout, retry, session expiry, permission denial and duplicate prevention |
| End-to-end workflows | **Not implemented** | Deterministic full Client, Provider and KCCA scenarios at API/mobile boundaries; live provider claims remain blocked without authorized environments |

## 4. Decision register and recommendations

These items are not resolved by the supplied sources. The recommendations are deliberately bounded and preserve the current modular monolith and development hosting direction. They require product/architecture approval before dependent production behaviour is encoded.

| ID | Undefined decision | Recommended project answer | Why this is the smallest coherent choice |
| --- | --- | --- | --- |
| `D-01` | Rating scale and labels | Mandatory whole-number **1–5** rating: 1 Very poor, 2 Poor, 3 Fair, 4 Good, 5 Excellent; show number and label as well as stars | Familiar, accessible, easy to validate and aggregate; logo yellow may be used only as the selected visual cue |
| `D-02` | Consequences of Completed / Left Incomplete / Not Done at all | **Confirmed:** record the collection outcome and a negative follow-up case separately. `COMPLETED` and `LEFT_INCOMPLETE` both record that waste was collected, so disposal remains available; `NOT_DONE_AT_ALL` records that no waste was collected and therefore has no disposal work. Negative feedback never mutates or erases the disposal record | Implements the approved separation between service dispute/follow-up and the physical disposal workflow |
| `D-03` | Scheduled date and time | **Confirmed:** every request must choose either `ASAP`, with no requested instant, or `SCHEDULED`, with one future requested service date/time. Scheduled values persist as UTC and are presented locally; the current validation horizon is 90 days | Implements the required service time while preserving the approved “as soon as possible” choice |
| `D-04` | Agreed price | **Confirmed:** currency is **UGX** and agreed prices are non-negative whole shillings. The database and API accept `0..1,000,000,000`; no fractional amount is accepted. Mobile-originated acceptance supplies the price, while a Call Centre request uses the externally agreed value if supplied | Integer storage avoids floating-point errors and exactly implements the approved non-negative whole-UGX rule |
| `D-05` | Disposal-site selection | KCCA owns an active disposal-site catalogue and the external KCCA process assigns one site before disposal can start. Providers may view but not choose/change it. Implement catalogue/assignment server boundaries and synthetic fixtures, not a mobile administration UI | Disposal destination is a regulatory control and should not be selected ad hoc by the Provider or Google |
| `D-06` | Location frequency, accuracy, arrival, stale data, background rules, retention and consent | **Provisional configuration, not permanent policy:** start with 15 seconds/25 metres, two arrival samples within 75 metres at no worse than 50-metre accuracy, stale after 60 seconds, background enabled only for an active journey, and 90-day retention. Values are environment-backed and returned by the API. Arrival thresholds, tracking frequency, background behaviour, consent/notification details, retention, and purge operation all require KCCA approval before production | Gives testable initial values while keeping policy changeable and explicitly unapproved for production |
| `D-07` | Provider eligibility/matching and Provider Type | Initially expose mobile marketplace requests to every approved, active Provider; keep Provider Type visible/auditable but do not infer a Gulper/Emptier-to-toilet mapping. Call Centre assignments remain visible only to the selected Provider. Add a policy port so KCCA can approve a mapping later | The sources define types but no matching matrix; universal eligibility avoids encoding a false mapping |
| `D-08` | Competing acceptance | First valid database transition from Pending wins via a conditional atomic update/transaction. The same Provider's idempotent retry returns the original result; another Provider receives stable `REQUEST_ALREADY_ACCEPTED` conflict and no private winner details | Directly satisfies the specification and is safe under retries and concurrency |
| `D-09` | Call Centre request/assignment/reassignment/feedback ingress | Add server APIs/use cases protected by a separate `callCentreOperationsPermitted` capability on an existing native KCCA/service account. They create Call Centre requests, assign/reassign after rejection, and submit externally collected feedback. Provide no mobile controls and use deterministic fakes/synthetic accounts in tests | Reuses native auth and explicit permissions without inventing a web portal or new identity system |
| `D-10` | Notification channels and FCM | Persist an in-app notification and outbox event for every important transition. Use Africa's Talking SMS only where the process explicitly requires SMS. Build a provider-neutral push adapter and fake; do not enable live FCM until an organizational Firebase project, credentials, Android configuration, privacy approval and delivery policy are authorized | Business transitions remain durable even while live push is externally blocked |
| `D-11` | Real-time transport | Use authenticated Socket.IO on the existing NestJS service for foreground update hints, delivered only to authenticated participant/KCCA-monitor actor rooms, with REST snapshots as the authoritative reconciliation source after connect/reconnect. Persist positions in PostgreSQL; Socket.IO is delivery only | Keeps one modular-monolith API and avoids a second authoritative store while satisfying near-real-time monitoring |
| `D-12` | Valkey/BullMQ worker | Do **not** require Valkey/BullMQ or a separate worker for this development slice. Implement the transactional PostgreSQL outbox, delivery contracts and deterministic processors/tests. Treat reliable scheduled reminders and live external delivery as deployment-blocked until worker hosting is approved | Matches the current single-service Railway development boundary and the explicit instruction not to lock into unapproved infrastructure |
| `D-13` | Neon/Railway workload suitability | Railway is the user-confirmed GitHub-connected deployment target, with the service rooted at the repository root. Keep Neon suitability and Railway runtime/capacity unverified until the actual environment passes migration, cold-start, connection, concurrency, WebSocket, load, and soak checks | Records the real deployment choice without claiming runtime evidence that was not inspected in this task |
| `D-14` | External accounts, billing, credentials and live verification | Implement only adapters, placeholders, restricted-key documentation and fakes. Live Google Maps requires an authorized Google Cloud project, billing/quota controls and Android key restrictions; live FCM requires authorization; live Africa's Talking and Neon remain unverified. Railway configuration exists by user confirmation but was not accessed or changed. No agent-created account, billing change, secret, deployment or external write is permitted | Directly observes the task authorization boundary |

## 5. Baseline validation on 2026-08-19

- `pnpm typecheck`: passed.
- `pnpm test`: 17 suites and 81 tests passed; the opt-in isolated PostgreSQL suite (2 tests) skipped because approved test database URLs were not supplied.
- `pnpm openapi:check`: passed against the committed but incomplete OpenAPI document; this is a drift result, not proof of endpoint completeness.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 51 tests passed.
- DOCX structural extraction: completed; visual render unavailable because LibreOffice/`soffice` is absent.

No migration, build, deployment, external call, resource creation, secret handling, commit, push, or paid action was performed during this inspection.

## 6. Approval gate

Implementation may proceed immediately on source-aligned, reversible foundations such as correcting OpenAPI coverage, establishing generated-client drift checks, and modelling generic idempotency/outbox primitives. Features that encode decisions `D-01` through `D-14` must wait for the grouped approval or amendments recorded by the project owner.

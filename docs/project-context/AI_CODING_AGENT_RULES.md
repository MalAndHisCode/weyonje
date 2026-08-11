# Weyonje AI Coding Agent Rules

These rules govern AI-assisted changes to the Weyonje mobile and web system. Apply them together with the latest approved requirements, architecture decisions, technology stack, repository instructions, and `CURRENT_SYSTEM_STATE.md`. Where sources conflict, stop and surface the conflict rather than choosing silently.

## 1. Requirements, Scope, and Decision Control

### Business-Requirement Traceability

- Trace every implemented behaviour to an approved requirement, issue, acceptance criterion, or documented decision before changing code.
- Preserve the documented actors, decisions, controls, notifications, outcomes, and exceptional paths; do not implement only the successful path.
- State which requirement each pull request satisfies and identify any requirement that remains incomplete.

### Assumption and Uncertainty Management

- Separate confirmed facts, reasonable implementation assumptions, hypotheses, and unknowns in plans and reviews.
- Ask for a decision when missing information materially affects behaviour, security, data, cost, or architecture; do not encode guesses as permanent rules.
- Use the smallest reversible assumption only when work can proceed safely, and document it for review.

### Scope and Excluded-Technology Control

- Implement only the requested scope and do not add speculative features, generic platforms, or infrastructure “for later.”
- Do not introduce microservices, Kubernetes, Firebase databases or authentication, self-hosted OpenStreetMap infrastructure, extra message brokers, payments, file storage, or other excluded capabilities without an approved decision.
- Reject dependency additions that merely duplicate an existing stack capability.

### Architecture-Decision Compliance

- Inspect current architecture decisions and existing patterns before proposing or making changes.
- Use the approved modular monolith, monorepo, Windows development, manual quality gates, Neon/Koyeb authentication development slice, Google Maps integration, and documented production approach consistently.
- Create an architecture decision record before a material deviation; do not smuggle architectural changes into feature work.

### Implemented State Versus Planned State

- Describe only verified, working behaviour as implemented.
- Label proposed, incomplete, disabled, deprecated, and unknown behaviour explicitly in code comments, documentation, and reports.
- Update `CURRENT_SYSTEM_STATE.md` whenever a change alters implemented functionality, architecture, integrations, configuration, operations, risks, or known issues.

## 2. Architecture and Repository Design

### Modular-Monolith Architecture

- Organise backend code by business capability with explicit public interfaces and private internals.
- Prevent circular dependencies, direct cross-module table manipulation, shared mutable state, and catch-all utility modules.
- Keep transactions within an owning use case; coordinate cross-module work through explicit application services or events.

### Separation of Client and Server Responsibilities

- Keep authoritative validation, permissions, pricing rules, workflow transitions, and audit decisions on the server.
- Let mobile and web clients validate for usability but never trust client validation or hidden controls as security.
- Treat every client request as untrusted and independently authorise it.

### Domain Modelling and Business Invariants

- Use one consistent vocabulary and representation for clients, providers, approvals, requests, assignments, journeys, confirmations, feedback, and ratings.
- Encode invariants at the appropriate domain, application, and database layers rather than scattering conditional checks through controllers and screens.
- Model histories and decisions explicitly when they must be auditable; do not overwrite evidence with the latest value.

### Workflow and State-Machine Design

- Define all allowed states, transitions, preconditions, authorised actors, side effects, and terminal states centrally.
- Reject invalid or repeated transitions safely and make valid retries idempotent where required.
- Test every transition, prohibited transition, cancellation path, and concurrency conflict.

### Monorepo Structure and Package Boundaries

- Keep mobile, web, API, worker, shared packages, infrastructure, tests, and documentation in clearly owned locations.
- Share contracts and truly platform-neutral utilities only; do not create a shared package for code used once or leak backend internals into clients.
- Use repository-level commands and one reviewed lockfile for TypeScript workspaces.

### Repository Hygiene and Generated Files

- Commit source, migrations, lockfiles, approved generated clients, configuration templates, tests, and documentation; exclude caches, builds, local databases, credentials, and environment-specific files.
- Generate files only through documented commands and never hand-edit generated output.
- Review `.gitignore`, `.gitattributes`, and line-ending behaviour so Windows changes remain valid on Linux runners.

## 3. General Code Quality and Maintainability

### Language and Runtime Standards

- Use strict TypeScript, sound Dart null safety, parameterised SQL, Node.js 24 LTS, and OpenJDK 21 LTS as selected.
- Avoid `any`, unchecked casts, force unwraps, dynamic maps, stringly typed states, and ignored compiler warnings unless a narrow exception is justified and tested.
- Pin toolchain versions and honour repository configuration instead of relying on global defaults.

### Code Clarity and Simplicity

- Prefer explicit, readable control flow, meaningful domain names, small cohesive functions, and shallow nesting.
- Remove dead code and stale comments; do not leave placeholder implementations presented as complete.
- Add abstraction only when it removes demonstrated duplication or isolates a genuine boundary.

### Duplication and Reuse Boundaries

- Reuse established components, validation, contracts, and utilities before creating new ones.
- Consolidate duplicated rules at their authoritative layer, but do not force unrelated behaviours into generic helpers.
- Keep platform-specific behaviour platform-specific when sharing it would create branching complexity.

### Error Handling and Failure Semantics

- Distinguish validation, authentication, authorisation, conflict, dependency, timeout, cancellation, and unexpected failures.
- Preserve useful internal diagnostics while returning safe, consistent, non-sensitive messages to users and clients.
- Retry only transient and idempotent operations with bounded backoff; never hide permanent failures or retry unsafe writes blindly.

### Configuration-Driven Behaviour

- Keep URLs, credentials, keys, limits, feature settings, timeouts, and environment differences outside source code.
- Validate required configuration at startup and fail with a clear safe error when it is missing or malformed.
- Provide non-secret templates and document ownership and purpose for every setting.

### Static Analysis, Formatting, and Pre-Commit Quality Gates

- Run ESLint, Prettier, Dart Analyzer, Flutter lints, Commitlint, and relevant pre-commit checks before declaring work complete.
- Fix findings rather than suppressing rules; allow narrow suppression only with a documented technical reason.
- Keep the documented local commands reproducible and treat the recorded manual quality gate as authoritative until automation is explicitly approved.

### Dependency Selection and Maintenance

- Add a dependency only after checking need, maintenance, licence, security, size, platform support, and compatibility with pinned runtimes.
- Pin versions through approved manifests and lockfiles; never make unrelated lockfile changes.
- Review Renovate changes individually, test upgrades, remove unused packages, and respond promptly to material vulnerabilities.

## 4. Flutter Mobile Application

### Flutter Application Architecture

- Organise mobile code by feature and separate presentation, state coordination, domain models, and data access.
- Keep widgets focused and composable; move reusable application behaviour into owned components instead of coupling screens directly to third-party widgets.
- Keep authoritative business rules on the server.

### Forui Design-System Usage

- Apply the approved Weyonje theme, tokens, typography, spacing, and component variants consistently through Forui and application wrappers.
- Do not scatter literal colours, sizes, or one-off styles through screens.
- Preserve accessibility and test application wrappers when adapting third-party components.

### Riverpod State Management

- Give every provider a clear owner, lifecycle, input, and invalidation rule.
- Represent loading, data, empty, refreshing, and error states explicitly; do not use nullable values to encode several states.
- Dispose short-lived state, avoid global mutable providers, and keep domain rules out of providers.

### Mobile Navigation and Deep Linking

- Define GoRouter routes centrally with typed parameters and explicit authentication and role guards.
- Validate deep-link identifiers on the server and provide safe handling for missing, expired, or unauthorised targets.
- Test cold start, restored navigation, notification links, logout, and back-button behaviour.

### Mobile API Communication

- Use one configured Dio layer for base URLs, authentication, timeouts, cancellation, correlation IDs, and error mapping.
- Cancel obsolete requests and prevent duplicate submissions caused by taps, retries, or lifecycle changes.
- Never duplicate endpoint construction or token handling in widgets.

### Mobile Data Models and Code Generation

- Generate immutable Freezed and JSON models from reviewed contracts where appropriate.
- Preserve nullability and enum compatibility; handle unknown server values safely instead of crashing or silently mapping them.
- Regenerate and review output through repository commands whenever contracts change.

### Mobile Authentication and Secure Storage

- Use native bounded email/password fields against the Weyonje API; never send credentials in URLs or retain them after submission.
- Store only access token, rotating refresh token, and required expiry metadata in platform secure storage; remove them on logout, revocation, account disablement, or unrecoverable refresh failure.
- Coalesce refresh attempts, rotate stored credentials atomically, preserve recoverable sessions on transient failure, and revalidate API authority after lifecycle restoration.

### Offline Data and Synchronisation

- Use encrypted Drift/SQLite storage only for approved bounded caches and temporary journey-position queues.
- Keep PostgreSQL authoritative, attach stable identifiers and timestamps to queued writes, and reconcile retries idempotently.
- Define retention, size limits, conflict behaviour, and secure deletion for local data.

### Mobile Permissions and Privacy Prompts

- Request location and notification permissions only when the related feature is invoked and explain the purpose beforehand.
- Handle denial, permanent denial, restricted settings, and later revocation without crashes or deceptive prompts.
- Never request permissions not required by approved functionality.

### Background Location Tracking

- Start foreground tracking only for an authorised active journey and display the required persistent notification.
- Stop tracking on completion, cancellation, logout, invalid assignment, or loss of authorisation, including after process recovery.
- Record accuracy and timestamps, bound sampling and offline queues, and reject implausible positions without concealing them.

### Mobile Platform Lifecycle and Device Compatibility

- Design for backgrounding, process death, device restart, weak networks, battery restrictions, and interrupted authentication.
- Test supported Android versions and representative manufacturer restrictions on physical devices.
- Restore only safe state and revalidate server authority after resuming.

### Mobile Notifications

- Register, rotate, associate, and revoke FCM device tokens safely per user and device.
- Deduplicate notifications and handle foreground, background, terminated, permission-denied, and deep-link states.
- Treat push delivery as best effort and retain important notifications in the Weyonje database.

### Mobile Crash and Diagnostic Reporting

- Tag GlitchTip/Sentry events with release and environment information and enough safe context to reproduce failures.
- Remove tokens, OTPs, phone numbers, feedback text, and precise coordinates from events and breadcrumbs.
- Do not use crash reporting as a substitute for user-visible error handling.

## 5. React Web Portal

### React Application Architecture

- Organise portal code by feature with small components, focused hooks, and clear separation of interface, server state, and domain presentation.
- Avoid oversized page components, prop drilling, global mutable stores, and effects used for derived state.
- Reuse established layouts and feature patterns before creating alternatives.

### Web Design System and Component Usage

- Use Tailwind tokens and application-owned shadcn/Radix components consistently.
- Preserve semantic HTML, keyboard behaviour, focus management, responsive layouts, and visible interaction states when customising primitives.
- Do not copy arbitrary component code without aligning it to the Weyonje theme and accessibility rules.

### Web Routing and Access Guards

- Define TanStack Router routes and parameters centrally and validate them before use.
- Guard routes for user experience, but enforce all permissions again in the API.
- Provide deliberate unauthenticated, unauthorised, not-found, and expired-link states.

### Server-State Management

- Define stable TanStack Query keys, ownership, stale times, invalidation, and refetch behaviour.
- Use optimistic updates only when rollback is reliable and the server remains authoritative.
- Prevent stale or out-of-order responses from overwriting newer state.

### Forms and Browser-Side Validation

- Use React Hook Form and Zod for accessible client feedback while treating server validation as authoritative.
- Preserve entered values appropriately, map server field errors consistently, and focus or announce the first relevant error.
- Prevent duplicate submissions and test success, validation, conflict, timeout, and permission failures.

### Operational Tables and Data Lists

- Use server-side filtering, sorting, and pagination for data that can grow.
- Provide accessible headings, actions, loading, empty, error, and permission states without rendering unauthorised data briefly.
- Keep URL query parameters shareable and validated where filters form part of operational navigation.

### Web Authentication

- Treat future web authentication as an API-owned session integration and do not select a separate identity framework without an approved decision.
- Do not store privileged secrets or unnecessarily persist access tokens in browser storage.
- Handle renewal, expiry, multi-tab logout, invalid credentials, and unauthorised routes predictably.

### Real-Time Web Updates

- Authenticate every Socket.IO connection and subscribe only to server-authorised rooms.
- Handle reconnects, missed events, duplicates, ordering, and stale state by reconciling with the REST API.
- Release subscriptions when screens or sessions end.

### Frontend Monitoring and Privacy

- Configure Grafana Faro with environment and release identifiers and useful performance signals.
- Redact form data, tokens, phone numbers, and precise locations from events, URLs, and breadcrumbs.
- Sample deliberately and document retention and access.

## 6. Backend API and Business Logic

### NestJS Module and Dependency Design

- Keep controllers thin, application services use-case focused, and repositories or adapters behind explicit interfaces.
- Use dependency injection deliberately; do not use service locators, hidden globals, or unrestricted cross-module imports.
- Put shared infrastructure in narrow modules rather than a universal `common` dumping ground.

### Fastify and HTTP-Layer Configuration

- Configure trusted proxies, request-size limits, timeouts, secure serialization, headers, CORS, and graceful shutdown explicitly.
- Return one safe error format and never expose stack traces or internal objects to clients.
- Validate behaviour behind the actual Koyeb development proxy and any approved production Nginx proxy, including client IP handling.

### Input Validation and Data Transformation

- Use explicit DTOs, allow-list known properties, reject malformed or unexpected input, and normalise values once at the boundary.
- Avoid implicit coercion that changes meaning; validate identifiers, enums, dates, phone numbers, coordinates, and lengths.
- Test validation at HTTP and service boundaries.

### Business-Service and Transaction Design

- Place business decisions in cohesive services and make the transaction boundary explicit.
- Protect concurrent assignment, approval, confirmation, and completion with database constraints, locking, or atomic updates as appropriate.
- Do not perform irreversible external calls inside a database transaction; use the transactional outbox.

### API Error and Response Contracts

- Map domain outcomes consistently to documented HTTP status codes and stable error codes.
- Distinguish unauthenticated, forbidden, missing, conflict, validation, throttled, dependency, and internal failures.
- Do not reveal whether protected records exist when that would leak information.

### Date, Time, and Telephone Handling

- Store instants in UTC and convert to Africa/Kampala only at presentation or approved reporting boundaries.
- Use `date-fns` for reviewed date operations and avoid ambiguous local-date parsing.
- Normalise and validate Ugandan numbers with `libphonenumber-js` before lookup, uniqueness checks, or SMS delivery.

## 7. API Contracts and Integrations

### REST API Design

- Use resource-oriented URLs, correct HTTP methods and status codes, stable error codes, and documented pagination, filtering, and sorting.
- Preserve backward compatibility or introduce an approved versioning and migration plan before breaking clients.
- Never expose database entities directly as public response contracts.

### OpenAPI Contract Management

- Treat the reviewed OpenAPI document generated by NestJS as the authoritative client contract.
- Generate Dart and TypeScript clients through one reproducible command and fail the documented drift check when generated output differs.
- Review schema changes for compatibility, nullability, security, examples, and error responses.

### Idempotency and Duplicate-Request Protection

- Require idempotency protection for retryable high-value writes such as request creation, journey start, confirmations, and completion.
- Scope keys to the authenticated actor and operation, persist results for an approved period, and reject conflicting reuse.
- Test retries before, during, and after transaction completion.

### Webhook Security and Processing

- Verify provider signatures or credentials before parsing or acting on webhook data.
- Protect against replay, duplicates, unexpected ordering, oversized payloads, and unknown event types.
- Persist safe provider identifiers and process accepted events idempotently without logging secrets or OTPs.

### External-Service Abstraction

- Isolate Google Maps, Africa’s Talking, and Firebase behind focused adapters owned by the relevant module; native authentication remains an owned API capability.
- Keep provider DTOs and error codes out of domain logic and translate them at the integration boundary.
- Provide deterministic fakes for routine tests without reproducing the vendor SDK internally.

### External Dependency Resilience

- Set explicit connection and request timeouts and use bounded retries only for transient safe operations.
- Define degraded behaviour for unavailable maps, SMS, push, Neon, GitHub, or Koyeb services.
- Surface persistent failures operationally and prevent one failing dependency from exhausting threads, queues, or connection pools.

## 8. Identity, Authentication, and Authorization

### Native Credential and Session Security

- Normalize and validate email once, store it with AES-256-GCM authenticated encryption, and locate it only through a separately keyed non-reversible HMAC lookup.
- Hash passwords with reviewed Argon2id parameters, unique salts, bounded input, dummy unknown-account verification, and upgrade detection; never encrypt or log passwords.
- Validate access-token algorithm, signature, issuer, audience, issue/expiry, current server session, password version, and current database authority on protected requests.

### Refresh, Revocation, and Abuse Protection

- Store only keyed refresh-token hashes, rotate every successful refresh atomically, and revoke the session family when a consumed token is reused.
- Revoke the current server session on sign-out and make administrative/password-version invalidation possible without trusting client state.
- Apply durable protected email/IP throttles plus bounded in-memory IP protection and return non-enumerating failures.

### Role and Permission Modelling

- Define coarse roles centrally and map every privileged action to an explicit server-side permission rule.
- Grant the minimum access required and default to denial for unknown roles or missing claims.
- Test each role against allowed and forbidden actions, including role changes during an active session.

### Object-Level Authorization

- Check record ownership and relationship on every read, update, subscription, export, and download.
- Never accept client-supplied provider, client, request, or journey identifiers as proof of access.
- Prevent enumeration through response content, timing, list endpoints, and WebSocket rooms.

### Registration, Verification, and Provider Approval

- Coordinate phone verification, identity creation, profile creation, approval, rejection, and activation as explicit recoverable steps.
- Keep providers unable to receive work until approved and record reasons and decision history in Weyonje.
- Make retries safe so partial failures cannot create duplicate identities or contradictory account states.

### Session and Account Lifecycle

- Define behaviour for logout, expiry, revocation, disabled accounts, rejected providers, lost devices, recovery, and role changes.
- Recheck authoritative account status for sensitive operations instead of relying indefinitely on cached client state.
- Revoke or dissociate device tokens and stored credentials when access ends.

## 9. Data, Persistence, and Geospatial Processing

### PostgreSQL Data Modelling

- Use stable identifiers, explicit relationships, appropriate normalisation, clear ownership, UTC timestamps, and deliberate history tables.
- Select data types and nullability from business meaning rather than convenience.
- Name schemas, tables, columns, constraints, and indexes consistently and document non-obvious choices.

### Database Integrity and Constraints

- Enforce critical uniqueness, references, value ranges, and mutually exclusive conditions in PostgreSQL as well as application code.
- Use transactions for multi-record invariants and design constraints to withstand concurrent requests.
- Return meaningful conflict results instead of leaking raw database errors.

### Prisma and SQL Usage Boundaries

- Use Prisma as the API's only database access layer and reviewed parameterised SQL through Prisma for complex spatial, reporting, locking, or performance-sensitive work.
- Never concatenate user input into SQL or hide important queries behind opaque abstractions.
- Keep persistence models from becoming public API contracts.

### Database Migration Safety

- Commit every schema change as a reviewed migration and never use automatic schema synchronisation outside disposable development contexts.
- Prefer expand-migrate-contract changes that remain compatible during rolling deployment.
- Assess locks, table rewrites, data volume, rollback or forward recovery, backups, and deployment order before release.

### Query Performance and Indexing

- Paginate unbounded lists and select only required columns and relations.
- Review execution plans for material queries and add relational or spatial indexes based on measured access patterns.
- Prevent N+1 queries, unbounded joins, excessive connection use, and per-position database chatter.

### PostGIS and Geospatial Data Modelling

- Use documented coordinate reference systems and consistent geometry types for service points, disposal sites, and journey tracks.
- Create appropriate spatial indexes and validate coordinates, accuracy, and geometry before storage.
- Keep Google-calculated routes separate from Weyonje-owned actual GPS history.

### Arrival and Geofence Detection

- Implement arrival checks with PostGIS distance functions using an approved radius and coordinate system.
- Require accuracy thresholds and multiple samples or dwell time where needed to limit false arrivals.
- Make arrival events idempotent and test GPS drift, boundary positions, delayed samples, and impossible jumps.

### Journey-Position Storage and Retention

- Preserve authenticated journey ownership, device timestamps, server receipt times, accuracy, and chronological order.
- Batch positions, deduplicate retries, bound frequency, and reject or flag implausible data without rewriting history silently.
- Apply approved retention and access controls to precise location history.

### Valkey Data Ownership and Expiry

- Store only short-lived OTP state, rate limits, caches, latest positions, Socket.IO coordination, and BullMQ data in Valkey.
- Set explicit expiry or retention behaviour for every non-queue key and use collision-resistant namespacing.
- Never rely on Valkey as the sole durable record of business or journey history.

## 10. Background Processing and Notifications

### BullMQ Queue Design

- Give queues and jobs versioned names, validated payloads, stable identifiers, timeouts, and explicit ownership.
- Configure bounded retries, backoff, concurrency, stalled-job handling, deduplication, and dead-letter review per job type.
- Make handlers idempotent and emit safe operational metrics for age, failures, and backlog.

### Transactional Outbox Reliability

- Write notification and integration intentions in the same PostgreSQL transaction as the business change.
- Process outbox records with idempotent workers, explicit status, retry metadata, and recovery of abandoned work.
- Do not mark an event complete until its required durable handoff is confirmed.

### OTP Generation and Verification Security

- Generate OTPs with a cryptographically secure source and store only a keyed HMAC with expiry and attempt count.
- Enforce one-time use, resend and verification throttles, constant-time comparison where applicable, and generic responses that resist enumeration.
- Never log, persist, return, or expose OTP values beyond the authorised delivery step.

### Notification Policy and Channel Selection

- Derive recipients, channels, wording, and timing from the approved notification matrix.
- Keep an auditable in-system notification for important events and treat SMS and push as delivery channels.
- Avoid duplicate or contradictory messages when one event is retried or updated.

### Notification Delivery, Retry, and Auditability

- Record channel, provider identifier, attempt, result, and safe failure reason without storing secrets.
- Retry transient failures with bounded backoff, stop permanent failures, and expose unresolved failures to operators.
- Make delivery callbacks and repeated worker execution idempotent.

### Africa’s Talking SMS Integration

- Normalise Ugandan numbers, separate sandbox and production credentials, and use approved sender configuration.
- Verify delivery callbacks and control message length, content, rate, and cost.
- Keep the provider behind an adapter so business workflows do not depend on vendor-specific responses.

### Firebase Cloud Messaging Integration

- Associate tokens with the correct user, device, environment, and lifecycle; remove invalid or signed-out tokens.
- Authenticate server sending securely and never expose service credentials to clients.
- Handle FCM as best effort and test duplicates, stale tokens, disabled permissions, and delayed delivery.

## 11. Maps, Routes, and Location Services

### Google Maps Client Integration

- Use the approved Flutter and JavaScript integrations and preserve Google attribution and terms.
- Keep marker, route, status, error, and loading behaviour consistent across mobile and web.
- Handle unavailable maps without blocking unrelated Weyonje operations.

### Place and Address Search

- Use Places sessions and request only fields required by the approved workflow.
- Preserve user confirmation of the selected service point and store Weyonje-owned coordinates and address context deliberately.
- Debounce search, cancel obsolete requests, and handle no-result, ambiguous, offline, and quota states.

### Routing Integration

- Request only approved route data and treat calculated distance, duration, and geometry as guidance.
- Preserve actual GPS journey evidence separately and never claim the planned route proves where a provider travelled.
- Handle no-route, invalid point, timeout, quota, and provider-error responses explicitly.

### Google Maps Credential Security

- Use separate Android, web, and server credentials with the narrowest application and API restrictions.
- Keep server credentials only in approved secret stores and rotate exposed keys immediately.
- Do not call server-only services directly from untrusted clients.

### Mapping Quotas and Cost Controls

- Debounce, cache only where terms allow, prevent duplicate calls, and request the smallest required response.
- Configure and monitor quotas, budgets, and spending alerts per environment.
- Test quota-exhausted behaviour and never remove limits merely to make a test pass.

### Mapping Data Ownership and Terms Compliance

- Store Weyonje-owned service locations, disposal sites, GPS positions, and route history in PostgreSQL/PostGIS.
- Do not treat Google Maps as the business database or retain Google-provided content beyond permitted uses.
- Preserve required attribution and document any approved caching or storage.

### Location Privacy and Data Protection

- Collect and transmit only location data required for an active approved purpose.
- Restrict historical access, define retention and deletion, and prevent location data from logs, analytics, or unrelated screens.
- Document what is sent to Google and require privacy and contractual approval for material changes.

## 12. Security and Privacy

### Threat Modelling and Security Requirements

- Identify actors, assets, trust boundaries, abuse cases, and mitigations for every material feature.
- Use OWASP ASVS, MASVS, and API Security guidance as review baselines appropriate to the affected surface.
- Treat authorisation, OTP, location, audit, and administrative flows as high risk.

### Secrets and Credential Management

- Store secrets only in approved local ignored files, Koyeb settings, or SOPS/age-encrypted files where required.
- Grant least privilege, separate environments, rotate deliberately, and remove unused credentials.
- Never include secrets in source, fixtures, logs, screenshots, documentation, prompts, build arguments, or client bundles.

### Cryptography and Sensitive-Data Protection

- Use established platform and standard-library cryptography with approved algorithms and secure random generation.
- Never invent encryption, hashing, signing, token, or key-management schemes.
- Protect data in transit with TLS and sensitive local data with platform secure storage or approved encryption.

### Rate Limiting and Abuse Prevention

- Rate-limit OTP, login, recovery, registration, public APIs, maps, SMS, and other costly or enumerable operations by appropriate actor and network signals.
- Return non-enumerating responses and define safe limits, reset behaviour, monitoring, and operator overrides.
- Test distributed limits through Valkey and behaviour when Valkey is unavailable.

### Audit Logging and Accountability

- Append immutable audit events for approvals, rejections, assignments, prices, roles, transitions, confirmations, and administrative access.
- Record actor, action, target, time, correlation, and safe before/after context without secrets.
- Do not allow application users or ordinary update paths to modify audit history.

### Log Redaction and Sensitive-Data Classification

- Classify fields before logging and redact tokens, OTPs, credentials, phone numbers, feedback text, and precise locations by default.
- Apply the same rules to Pino, browser telemetry, mobile diagnostics, traces, automation logs, and provider errors.
- Test redaction and treat a logging leak as a security incident.

### Secure Coding and Automated Security Analysis

- Run Gitleaks, Semgrep, Trivy, dependency audits, ZAP, MobSF, and applicable checks at documented gates.
- Review findings in context, fix material issues, and document narrow accepted risks with owner and expiry.
- Do not disable scanners or broadly suppress findings to achieve a green pipeline.

### Browser, API, and Mobile Security Headers and Controls

- Configure Helmet, CSP, CORS, TLS, cookies, request limits, and proxy trust for actual deployment origins.
- Use secure mobile storage and minimum permissions, and validate deep links and exported Android components.
- Tune ModSecurity/CRS deliberately and never assume the WAF replaces secure application code.

### Data Protection and Records Governance

- Document purpose, lawful authority, access, retention, correction, deletion, export, and incident handling for personal and location data.
- Apply Ugandan law and approved KCCA policy before changing collection or disclosure.
- Use anonymised or synthetic data outside authorised environments and prevent production data from entering developer tools.

## 13. Testing and Verification

### Risk-Based Testing Strategy

- Choose unit, component, contract, integration, end-to-end, security, performance, and device tests according to change risk.
- Test business rules and failure paths at the lowest reliable level and retain a small set of critical end-to-end flows.
- Do not claim completion until relevant automated and manual checks pass.

### Flutter Unit and Widget Testing

- Test validation, Riverpod state, navigation decisions, permissions, and every visible loading, empty, success, and error state.
- Use deterministic fakes and clocks; avoid real networks, arbitrary delays, and assertions tied to internal widget structure.
- Verify semantics and user interaction, not merely widget existence.

### Flutter Integration and Device Testing

- Test complete role-appropriate flows on supported devices, including authentication, requests, journeys, confirmations, and notifications.
- Exercise permission denial, background tracking, weak connectivity, offline queues, process interruption, GPS accuracy, and recovery.
- Include maintained physical Android devices; do not treat emulator success as sufficient for tracking behaviour.

### React Unit and Component Testing

- Use Vitest and React Testing Library to test observable behaviour, accessibility, permissions, forms, and asynchronous states.
- Query elements by accessible role or label and avoid implementation-specific selectors.
- Mock only external boundaries and keep TanStack Query and router behaviour realistic where material.

### Web End-to-End Testing

- Use Playwright for critical KCCA and Call Centre workflows with isolated accounts and data.
- Use stable user-facing selectors, wait for observable conditions, and never use arbitrary sleeps to hide races.
- Capture useful artifacts on failure without exposing credentials or personal data.

### Backend Unit and API Testing

- Use Jest for services, guards, state transitions, idempotency, and error mapping, and Supertest for actual HTTP contracts.
- Assert database effects and lack of effects on failure, not only response status.
- Cover unauthenticated, forbidden, invalid, conflicting, concurrent, throttled, and dependency-failure cases.

### Real-Service Integration Testing

- Run real PostgreSQL integration only when approved isolated `TEST_DATABASE_URL` and `TEST_DIRECT_URL` values are explicitly supplied.
- Apply real Prisma migrations and verify constraints, session/token relationships, and transaction boundaries without requiring Docker, WSL, local Linux, or hosted automation.
- Skip transparently when test URLs are absent; never use a shared Neon development database for routine tests or claim skipped checks passed.

### API Contract and Generated-Client Testing

- Fail the documented local contract gate when OpenAPI output or generated Dart and TypeScript clients differ from committed reviewed output.
- Test compatibility of required fields, nullability, enums, errors, authentication, and pagination.
- Do not maintain handwritten duplicate client models for generated contracts.

### Mapping and Location Testing

- Stub paid Google calls for routine tests and reserve live calls for controlled integration checks with strict quotas.
- Test unavailable maps, no routes, quota exhaustion, inaccurate GPS, geofence boundaries, duplicates, gaps, and out-of-order samples.
- Verify that actual route history remains independent of Google route estimates.

### Notification Testing

- Test notification policy, in-system records, channel selection, retries, deduplication, callbacks, and permanent failures.
- Use fakes or provider sandboxes by default and prevent uncontrolled paid SMS or real-user push messages.
- Assert that sensitive values never enter logs or test reports.

### Performance and Load Testing

- Use k6 against an approved isolated environment to test expected API, WebSocket, journey-position, queue, and database load.
- Define realistic workloads, success thresholds, resource limits, and a safe stop condition before running tests.
- Do not load-test paid external providers without explicit approval.

### Test Data and Environment Isolation

- Use synthetic, minimal, reproducible data and unique test identifiers.
- Never copy production personal data, phone numbers, credentials, or precise journeys into tests.
- Clean up external side effects and make parallel tests unable to interfere with each other.

### Regression and Acceptance Criteria

- Convert every bug into a failing regression test before or with the fix when practical.
- Define observable acceptance criteria covering success, permissions, validation, failure, and recovery.
- Report tests not run and remaining risks honestly.

## 14. Accessibility and User Experience Quality

### Cross-Platform Accessibility

- Support keyboard navigation, visible focus, screen readers, semantic labels, text scaling, contrast, touch targets, and reduced motion.
- Preserve native control semantics and manage focus correctly in dialogs, errors, navigation, and dynamic updates.
- Include automated checks and manual keyboard and assistive-technology review for material interface changes.

### Responsive and Device-Adaptive Design

- Design mobile and web layouts for approved screen sizes, orientations, input methods, and text scaling without clipping or hidden actions.
- Use responsive tokens and layouts rather than device-specific pixel fixes.
- Test constrained phones and common portal viewport sizes.

### Loading, Empty, Error, Offline, and Permission States

- Implement every meaningful non-success state with clear status, next action, and recovery path.
- Preserve user input where safe and never show endless spinners or silent failures.
- Distinguish no data from unauthorised, offline, failed, filtered-empty, and not-yet-loaded states.

### Usability for Operational Workflows

- Minimise steps and ambiguity for Call Centre entry, provider review, assignment, monitoring, confirmation, and feedback.
- Make status, ownership, required action, and consequences visible before irreversible operations.
- Prevent duplicate actions and require confirmation only when it meaningfully reduces risk.

### Content and Status Terminology

- Use approved plain-language terms consistently across mobile, web, API, notifications, tests, and documentation.
- Do not create synonyms for workflow states or expose internal enum names directly to users.
- Review wording for clarity, actionability, grammar, and accessibility.

## 15. GitHub and Collaboration Workflow

### Git and Branching Standards

- Use approved branch names, small coherent commits, and Conventional Commit messages that describe intent.
- Do not rewrite shared history, force-push protected branches, or mix unrelated refactors with feature work.
- Keep generated changes and migrations in the same reviewable change that requires them.

### Pull-Request Quality and Reviewability

- Keep pull requests focused and explain scope, requirement, architecture impact, data changes, security risks, tests, and rollout.
- Provide screenshots or recordings for material interface changes and migration or rollback notes for operational changes.
- Resolve review feedback deliberately and do not mark threads resolved without addressing or explaining them.

### GitHub Issues and Work Traceability

- Link implementation and pull requests to approved issues or requirements.
- Record newly discovered scope, defects, and follow-up work rather than silently expanding the current change.
- Keep issue status and acceptance criteria aligned with actual completion.

### GitHub Permissions and Repository Security

- Use organisation-owned repositories, require MFA, protect branches, and grant the minimum team and package permissions.
- Keep environment secrets behind appropriate approvals and restrict workflow token permissions per job.
- Review access periodically and remove former users, stale deploy keys, and unused tokens.

### AI-Agent Change Discipline

- Inspect relevant code, tests, documentation, and current changes before editing.
- Make the smallest coherent change, preserve unrelated user work, and never perform destructive Git operations without explicit approval.
- Review the final diff for fabricated APIs, placeholders, dead code, security regressions, unrelated formatting, and documentation drift.

## 16. Manual Quality Gates and Software Supply Chain

### Current Automation Boundary

- This development slice defines no hosted workflow and no automated deployment; run and record all documented checks manually.
- Do not add a replacement workflow merely for authentication unless a later approved task changes this boundary.
- Keep future automation proposals separate from implemented repository reality.

### Required Quality Gates

- Require formatting, linting, typing, tests, generated-code checks, migrations, security scans, and builds appropriate to the change.
- Do not bypass, weaken, or condition away a failing gate merely to merge.
- Keep failures actionable and preserve useful safe artifacts for diagnosis.

### Container Build Standards

- Use reproducible multi-stage Dockerfiles with pinned bases, minimal runtime contents, non-root users, health checks, and graceful signals.
- Keep secrets out of layers, build arguments, and images and use `.dockerignore` deliberately.
- Do not add a container solely for the Koyeb development API while its supported native Node/pnpm build remains reliable.

### GitHub Container Registry Management

- Publish images to GHCR with immutable version, commit, or digest references instead of deploying `latest`.
- Restrict read, write, and delete permissions and define retention without removing deployed artifacts.
- Promote the same verified image between environments rather than rebuilding different bytes.

### Software Supply-Chain Security

- Scan dependencies, operating-system packages, configuration, and images with approved tools.
- Generate CycloneDX SBOMs, sign approved images with Cosign, and verify signatures before deployment.
- If automation is later approved, pin its actions and base images and review provenance and licence changes.

### Deployment Automation and Approval Controls

- Do not deploy from coding tasks. Future reviewed production automation requires separate approval; the development Koyeb service is configured manually by an authorised operator.
- Protect staging and production with required reviewers, environment-scoped secrets, health checks, and rollback or forward-recovery procedures.
- Record deployment version, time, actor, migration result, and verification outcome.

### Environment Separation

- Use distinct data, credentials, keys, domains, integrations, and configuration for test, development, staging, and production.
- Prevent lower environments from reaching production databases or sending messages to real users.
- Make the active environment unambiguous in logs, telemetry, interface diagnostics, and deployment records.

## 17. Windows, Neon, and Koyeb Development

### Windows Development Compatibility

- Write repository commands and scripts that run natively on supported Windows workstations.
- Handle paths, quoting, file permissions, and line endings without assuming Bash, WSL, Docker Desktop, or local Linux.
- Test cross-platform commands where both platforms are actually claimed; do not imply an unconfigured hosted gate exists.

### Local Versus Remote Responsibility Boundaries

- Run supported source development, unit tests, and local mobile and web processes on Windows.
- Keep routine authentication checks native to Windows; run database integration only against an explicitly approved isolated PostgreSQL target.
- Do not expose workstation services publicly to bridge remote dependencies.

### Neon and Koyeb Development Architecture

- Use Neon pooled runtime and direct migration addresses for the Prisma API and keep both private; never use a shared database for routine tests.
- Run one stateless Koyeb Free Web Service for the compiled NestJS API, bind supplied `PORT` on `0.0.0.0`, and keep durable state in Neon with no worker or persistent disk.
- Enter separate secrets in Koyeb settings, prefer Frankfurt when available and suitable, document free sleep/cold starts, and never weaken Argon2id for host limits.

### Development Connectivity and Outage Handling

- Design the workflow for temporary loss of internet, GitHub, Neon, Koyeb, Google Maps, Firebase, or Africa’s Talking.
- Preserve local unpushed work safely and expose clear degraded states rather than bypassing required checks.
- Resume idempotently after connectivity returns.

## 18. Production Infrastructure and Operations

### Ubuntu Server Baseline and Hardening

- Use approved Ubuntu Server 24.04 LTS images, minimal packages, named operators, SSH keys, least privilege, and timely security patches.
- Disable unnecessary services and password-based remote access where policy permits.
- Record and automate host configuration rather than relying on undocumented manual state.

### Docker Compose Production Deployment

- Define networks, volumes, secrets, health checks, resource limits, restart policies, dependencies, and graceful shutdown explicitly.
- Isolate public and data services and use durable volumes only for approved state.
- Validate upgrade, rollback, backup, and restore behaviour before production changes.

### Nginx and TLS Configuration

- Terminate HTTPS with approved certificates, redirect HTTP safely, proxy API and WebSockets correctly, and serve only intended static content.
- Configure trusted proxies, security headers, request limits, timeouts, and certificate-expiry monitoring.
- Test renewal and reload without service interruption.

### Firewall and Network Security

- Allow only required inbound ports and management networks and test Docker traffic through the `DOCKER-USER` chain.
- Keep PostgreSQL, Valkey, internal monitoring, and administrative interfaces off the public internet.
- Document every exception with owner, purpose, and review date.

### Host-Service Supervision

- Use systemd for startup, shutdown, timers, dependencies, bounded restarts, and status visibility.
- Prevent restart loops and ensure services stop gracefully before deployment or reboot.
- Monitor failed units and preserve diagnostic logs safely.

### Infrastructure Automation

- Make Ansible playbooks idempotent, reviewed, environment-aware, and safe to rerun.
- Separate inventories and secrets and validate changes in lower environments first.
- Provide recovery for partially applied infrastructure changes.

### Web-Application Firewall Management

- Introduce ModSecurity/OWASP CRS in detection mode, review real traffic and false positives, then enable blocking deliberately.
- Version and test exclusions narrowly and never disable broad rule groups without evidence.
- Monitor blocks and provide an operational rollback path.

## 19. Observability and Operational Diagnostics

### Observability Architecture

- Instrument APIs, workers, external adapters, and frontends consistently through OpenTelemetry where supported.
- Define telemetry ownership, names, environments, retention, and privacy before emitting data.
- Keep observability useful during partial failures and avoid vendor-specific logic in business code.

### Structured Logging and Correlation

- Use structured Pino logs with severity, timestamp, request or correlation ID, safe actor context, and relevant business identifiers.
- Propagate correlation across HTTP, Socket.IO, database work, outbox records, BullMQ jobs, and external requests.
- Redact sensitive data centrally and avoid free-form production logging that bypasses policy.

### Metrics and Service-Level Indicators

- Expose bounded Prometheus metrics for latency, errors, saturation, queues, WebSockets, notifications, journeys, databases, and hosts.
- Use low-cardinality labels and never label metrics with phone numbers, coordinates, tokens, or unbounded identifiers.
- Define expected ranges and an owner for every alerting metric.

### Distributed Tracing

- Propagate trace context through API and worker boundaries and record safe spans for important dependencies.
- Sample deliberately and prevent payloads, credentials, and precise location from span attributes.
- Use traces to complement, not replace, logs and business audit records.

### Dashboards and Operational Views

- Build Grafana dashboards around operator decisions, service health, queue backlogs, dependency failures, and safe aggregate process indicators.
- Display environment, time range, units, thresholds, and data freshness clearly.
- Remove obsolete panels and keep dashboard configuration version-controlled where supported.

### Alert Design and Escalation

- Alert only on actionable symptoms with severity, owner, safe context, runbook, and recovery signal.
- Use sustained thresholds, grouping, deduplication, and inhibition to limit alert fatigue.
- Test routing and escalation without exposing personal information.

### Availability and External Monitoring

- Use Uptime Kuma and Blackbox checks for public endpoints, certificates, DNS, WebSocket reachability where appropriate, and expected health responses.
- Run checks from outside the monitored failure domain and distinguish dependency degradation from total outage.
- Avoid health checks that mutate business data.

### Error Tracking and Release Diagnostics

- Configure GlitchTip with release, commit, environment, ownership, and regression information.
- Group errors meaningfully, triage by user and operational impact, and link fixes to regression tests.
- Enforce the same privacy redaction as application logs.

### Monitoring Infrastructure Operations

- Define access, capacity, retention, backup, compaction, upgrade, and recovery for Prometheus, Loki, Tempo, Grafana, exporters, and GlitchTip.
- Monitor the monitoring stack itself and set safe resource limits.
- Do not expose dashboards, metrics, logs, or tracing endpoints publicly without approved authentication.

## 20. Backup, Recovery, and Maintenance

### Database Backup and Point-in-Time Recovery

- Configure pgBackRest full and incremental backups, WAL archiving, encryption, retention, and failure alerts from approved recovery objectives.
- Store credentials separately and ensure backups cover every authoritative PostgreSQL database.
- Treat a backup as successful only after restoration and application verification.

### Non-Database Backup Management

- Use Restic for approved configuration and operational files not held in PostgreSQL.
- Exclude secrets or external Google content unless their approved handling explicitly permits backup.
- Define retention, encryption, integrity checks, and restore ownership.

### Off-Site and Failure-Domain Separation

- Store backups outside the production host and, where possible, outside the same physical or administrative failure domain.
- Restrict deletion and restore access independently from ordinary application administration.
- Monitor capacity, retention, and failed transfers.

### Restore Testing and Disaster Recovery

- Perform automated verification and scheduled manual restoration into an isolated environment.
- Run integrity, migration, authentication, and application smoke checks after restore and record actual recovery time and data loss.
- Update procedures immediately when a drill reveals a gap.

### Patch and Upgrade Management

- Track supported versions of operating systems, runtimes, databases, Prisma, Argon2, containers, dependencies, and tools.
- Test updates in lower environments, review release and security notes, back up state, and define rollback or forward recovery.
- Schedule disruptive work and controlled reboots with ownership and verification.

### Operational Runbooks and Incident Response

- Maintain executable runbooks for deployment, rollback, queues, notifications, Google quotas, databases, certificates, authentication keys/sessions, backups, and dependency outages.
- Include detection, immediate containment, diagnosis, recovery, validation, escalation, and evidence-preservation steps.
- Review runbooks after incidents and material architecture changes.

## 21. Documentation and Knowledge Management

### Technical Documentation Standards

- Keep Markdown accurate, task-oriented, version-controlled, and reviewed with the code it describes.
- Document prerequisites, ownership, configuration names, commands, expected results, failure recovery, and security constraints.
- Remove stale instructions rather than accumulating conflicting alternatives.

### Current-System-State Maintenance

- Update `CURRENT_SYSTEM_STATE.md` only with verified implemented reality and explicitly label incomplete or unknown areas.
- Record architecture, behaviour, roles, integrations, environments, operations, risks, limitations, and known issues affected by each change.
- Resolve discrepancies between documentation and code or state them clearly.

### Architecture Decision Records

- Create an ADR for material technology, data, security, hosting, or cross-module decisions.
- Record context, decision, status, consequences, alternatives, and superseding ADRs without rewriting history.
- Do not use an ADR to approve scope that still requires product or organisational authority.

### Diagram Accuracy and Maintainability

- Keep Mermaid architecture, workflow, state, data-flow, and deployment diagrams consistent with code and configuration.
- Show trust boundaries, external dependencies, ownership, and direction clearly without speculative components.
- Update or remove diagrams when the represented reality changes.

### Runbook and Documentation Publishing

- Organise MkDocs navigation for developers and operators with controlled access to sensitive operational material.
- Make documentation builds reproducible and validate links, navigation, and rendering in the documented manual gate or any later approved automation.
- Do not publish secrets, internal addresses, or sensitive incident detail to public documentation.

### Code Comments and Developer Guidance

- Comment intent, invariants, constraints, workarounds, and non-obvious security decisions rather than restating syntax.
- Keep TODOs attributable and linked to approved work; do not leave vague placeholders.
- Update comments with code and delete misleading commentary.

## 22. Cost, Licensing, and Governance

### Paid-Service Cost Management

- Identify every change that can increase Google Maps, Neon/Koyeb beyond free allowances, Africa’s Talking, GitHub, Firebase Test Lab, infrastructure, or distribution costs.
- Estimate the cost driver, obtain approval where required, and assign an owner before enabling chargeable use.
- Monitor actual use and remove accidental or obsolete consumption.

### Quota and Spending Safeguards

- Configure conservative quotas, budgets, alerts, and responsible recipients per environment.
- Treat budget alerts as notifications rather than guaranteed spending caps and use enforceable quotas where safe.
- Investigate anomalies promptly and never raise limits without documenting need and cost authority.

### Open-Source Licence Compliance

- Check dependency, image, font, icon, and tool licences before adoption and preserve required notices and attribution.
- Include dependencies in the SBOM and reject incompatible or unclear licensing until reviewed.
- Do not copy code from unknown or incompatible sources.

### Google Maps Contractual Compliance

- Preserve required attribution and comply with current restrictions on storage, caching, display, and derived content.
- Send only approved location information and document privacy and contractual impact when usage changes.
- Do not bypass API controls, scrape Google content, or substitute Weyonje’s operational database with Google data.

### Access Ownership and Account Continuity

- Use approved organisational ownership for repositories, Neon, Koyeb, Google Cloud, Firebase, Africa’s Talking, domains, billing, and recovery methods.
- Avoid sole-person dependencies; assign backup administrators and store recovery material through approved processes.
- Review access regularly and revoke it promptly when roles change.

### Operational Ownership and Support Responsibilities

- Assign a named role for every service, alert, backup, credential, cost, security finding, incident path, and vendor relationship.
- Document support hours, escalation, maintenance expectations, and handover requirements before production use.
- Do not declare a component production-ready while ownership, monitoring, backup, security, or recovery remains unassigned.

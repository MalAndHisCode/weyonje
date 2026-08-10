# Weyonje Technology Stack

## 1. Recommendation Summary

Weyonje should be built as a **modular monolith with separate mobile, web, API, worker, identity, data, and monitoring components**. This is the best fit for the documented workflows because it gives the mobile app and KCCA web portal one authoritative backend, supports real-time location tracking and notifications, and keeps deployment understandable for a small development and operations team.

The core stack is:

- **Flutter and Dart** for the single mobile app used by clients and service providers.
- **React, TypeScript, and Vite** for the KCCA and Call Centre web portal.
- **NestJS, TypeScript, and Node.js 24 LTS** for the backend API and background workers.
- **PostgreSQL 18 with PostGIS 3.6** for transactional and geographical data.
- **Valkey 9** and **BullMQ** for short-lived data, rate limiting, scheduled reminders, and reliable background jobs.
- **Keycloak** for identity, login, session, and role management.
- **Socket.IO** for live journey updates.
- **Google Maps Platform** for map display, place and address search, route calculation, and other approved mapping capabilities.
- **Africa's Talking SMS** for required phone verification and SMS notifications in Uganda.
- **Firebase Cloud Messaging** for mobile push notifications.
- **Docker Compose on Ubuntu Server LTS**, fronted by **Nginx**, for production deployment.
- **GitHub, GitHub Actions, and GitHub Container Registry** for source control, collaboration, automated delivery, Linux-based testing, and container-image storage.
- **Windows 11 workstations with Render-hosted Linux development services** so developers can work directly on Windows while Valkey 9 and other genuinely Linux-dependent components run remotely.
- **OpenTelemetry, Prometheus, Grafana, Loki, Tempo, and Alertmanager** for monitoring and diagnostics.

Use the latest supported patch releases of these approved major versions when implementation begins, pin them in the repository, and upgrade them through tested maintenance releases rather than allowing uncontrolled version drift.

## 2. Supported Requirements from the Business Process Specification

This stack is designed around the requirements explicitly established by the supplied Weyonje specification:

- client self-registration and SMS phone verification;
- service-provider registration, phone verification, KCCA review, approval, rejection, and activation;
- service requests initiated through the mobile app;
- service requests recorded by KCCA Call Centre staff for clients without smartphones;
- provider selection, acceptance, rejection, and reassignment;
- controlled request-status transitions;
- agreed prices recorded against requests;
- scheduled reminders;
- SMS, push, and in-system notifications;
- provider location capture when a job is initiated;
- live monitoring of journeys to the collection location and disposal site;
- arrival detection and journey-history review, including routes and stopovers;
- client or KCCA confirmation of collection;
- feedback and service-provider ratings; and
- KCCA oversight through completion of disposal.

## 3. Assumptions Used to Complete the Stack

The specification describes business processes rather than a technical architecture. The following assumptions are therefore necessary:

- **KCCA staff and Call Centre staff will use a web portal.** The specification says they access “the system” but does not define the interface. A browser-based portal is the most practical interface for request entry, provider review, assignment, monitoring, and administration.
- **Clients and service providers will use one role-aware mobile application.** This follows the specification, which describes the Weyonje Mobile App prompting a first-time user to choose a client or service-provider account type.
- **Android is the first production mobile target.** Flutter retains an iOS path without requiring a second codebase, but the specification does not explicitly require an iOS release.
- **Location collection will occur only during an active service journey.** Continuous tracking outside a job is not supported by the specification and would create unnecessary privacy and battery risks.
- **KCCA can provide or procure Linux virtual machines, network access, DNS, backup storage, and SMS credit.** Exact server capacity cannot be selected until expected user numbers, concurrent journeys, retention periods, and availability targets are known.
- **Developers will work directly on Windows and have reliable internet access to GitHub, Render, Google Maps Platform, and other external services.** WSL, Docker Desktop, and a local Linux installation are not workstation requirements.
- **Render will host Valkey 9 and integration instances of the NestJS API and BullMQ worker for development.** The API and worker must share Render's private network with Valkey for complete queue integration testing. Whether PostgreSQL/PostGIS, Keycloak, and monitoring services also run on Render remains an environment-design decision and must not be treated as confirmed until documented.
- **The initial workload is suitable for a modular monolith.** Nothing in the specification establishes a scale or team structure that would justify microservices or Kubernetes.
- **The request location needs map display, address search, routing, and arrival detection.** These are reasonable supporting capabilities for the documented live monitoring and arrival notifications. They should be confirmed during detailed requirements analysis.
- **Payments, document uploads, photographs, artificial intelligence, and public analytics are not included.** They are not required by the supplied specification and should not be added to the baseline stack without an approved requirement.

## 4. Architecture and Application Structure

### Modular Monolith

**Technology/approach: Modular monolith**

Build one backend application divided into strongly separated modules for identity linkage, clients, service providers, approvals, service requests, assignments, journeys, notifications, feedback, ratings, audit, and administration. This gives Weyonje one consistent business transaction boundary while preventing the code from becoming an unstructured monolith.

### Separate API and User Applications

**Technology/approach: API-first client-server architecture**

The Flutter mobile app and React web portal will communicate with the same secure backend API. Neither user application should connect directly to the database or contain authoritative business rules.

### REST and WebSockets

**Technology/approach: REST API plus WebSockets**

Use REST for registration, approvals, requests, assignments, feedback, administration, and history. Use WebSockets only for time-sensitive updates such as live provider positions and immediate request-status changes. This keeps normal operations simple while supporting real-time journeys.

### Explicit Workflow State Machines

**Technology: XState**

Represent provider approval and service-request states as explicit state machines. This prevents invalid transitions such as starting an unaccepted request, travelling to disposal before collection confirmation, or completing a request before disposal is recorded.

## 5. Programming Languages and Runtime Platforms

### Dart

**Technology: Dart**

Dart will be the language for the Flutter mobile application. It provides strongly typed application code and compiles efficiently for supported mobile platforms.

### TypeScript

**Technology: TypeScript**

TypeScript will be used for the web portal, backend API, workers, shared API types, and build tooling. Using one strongly typed language across the web and server reduces data-contract mistakes and makes the code easier to maintain.

### SQL

**Technology: PostgreSQL SQL and PostGIS SQL**

SQL will define migrations, constraints, reports, and geographical queries. Important business integrity rules should be enforced in the database as well as in application code where practical.

### Node.js 24 LTS

**Technology: Node.js 24 LTS**

Node.js will run the API and background workers. Version 24 is the appropriate production baseline because it is an LTS release; the Node.js project recommends production applications use Active or Maintenance LTS versions.

### OpenJDK 21 LTS

**Technology: Eclipse Temurin OpenJDK 21 LTS**

Java is required to run Keycloak and Android build tooling. Use one supported LTS distribution and pin it in development and CI environments.

## 6. Mobile Application Stack

### Flutter

**Technology: Flutter stable channel**

Flutter will provide the single mobile app for clients and service providers. It supports Android and preserves a future iOS route from the same codebase. Flutter's official platform documentation confirms support across mobile and web targets, although Weyonje should use React rather than Flutter for the data-heavy KCCA portal.

### Forui

**Technology: Forui**

Forui will provide the mobile interface components and design foundation. Use a Weyonje theme derived from the approved branding, then wrap reused components in application-owned widgets so that future library changes do not spread across every screen.

### Riverpod

**Technology: Riverpod**

Riverpod will manage mobile application state, authenticated-user context, request lists, selected journeys, and asynchronous API data. Keep business rules on the server; Riverpod should coordinate interface state rather than become a second business-rule engine.

### GoRouter

**Technology: GoRouter**

GoRouter will manage role-aware navigation, guarded routes, deep links from notifications, and restoration of the correct request or approval screen.

### Dio

**Technology: Dio**

Dio will call the Weyonje REST API. It will provide timeouts, request cancellation, controlled retries for safe operations, authentication headers, and consistent error handling.

### Freezed and json_serializable

**Technologies: Freezed and json_serializable**

These tools will generate immutable Dart models and reliable JSON conversion from the backend's OpenAPI-defined data structures, reducing repetitive and error-prone mapping code.

### flutter_appauth

**Technology: flutter_appauth**

This library will connect the mobile app to Keycloak using OpenID Connect Authorization Code Flow with PKCE. Tokens must be stored through secure platform storage rather than ordinary application preferences.

### flutter_secure_storage

**Technology: flutter_secure_storage**

This library will store the minimum sensitive authentication material using Android Keystore and the equivalent secure storage on other supported platforms.

### geolocator

**Technology: geolocator**

Geolocator will obtain the service provider's position, request permission correctly, expose accuracy information, and provide location updates during active journeys.

### flutter_foreground_task

**Technology: flutter_foreground_task**

This library will keep approved Android journey tracking running through a visible foreground service while the provider switches apps or locks the screen. Tracking must stop automatically when the applicable journey ends or is cancelled.

### permission_handler

**Technology: permission_handler**

This library will manage location and notification permissions with clear explanations and appropriate fallbacks when a user denies access.

### Google Maps for Flutter

**Technology: Google Maps for Flutter (`google_maps_flutter`)**

Google Maps for Flutter will display request locations, provider movement, routes, collection points, and disposal journeys in the mobile application. Use separately restricted development and production API keys, permit only the required Google Maps APIs, and keep authoritative service locations and journey positions in Weyonje rather than treating displayed Google content as the business record.

### firebase_messaging

**Technology: firebase_messaging**

This Flutter plugin will receive Firebase Cloud Messaging notifications for accepted requests, provider arrival, collection confirmation, disposal updates, and other app-visible events.

### flutter_local_notifications

**Technology: flutter_local_notifications**

This library will display notifications consistently while the app is open or when a locally handled reminder needs to be shown.

### connectivity_plus

**Technology: connectivity_plus**

This library will help the app explain when network connectivity is unavailable. It must not be treated as proof that the internet works; API calls still need timeouts and real error handling.

### Drift, SQLite, and SQLCipher

**Technologies: Drift, SQLite, and sqlcipher_flutter_libs**

Use a small SQLCipher-encrypted local database for non-authoritative cached reference data, the signed-in user's recent requests, and a bounded queue of journey positions awaiting upload after a brief network interruption. The server remains the source of truth, and cached sensitive data must have a short retention period.

### Sentry Flutter SDK with Self-Hosted GlitchTip

**Technology: Sentry Flutter SDK reporting to GlitchTip**

Capture mobile crashes and handled errors without placing personal or precise location data in diagnostic events. GlitchTip provides a self-hosted, Sentry-compatible destination so KCCA can retain operational control of error data.

## 7. KCCA Web Portal Stack

### React

**Technology: React**

React will build the KCCA and Call Centre portal for service-provider approvals, request entry, assignment, live monitoring, feedback recording, administration, and operational review.

### Vite

**Technology: Vite**

Vite will provide fast local development and produce the static web application bundle served by Nginx.

### TypeScript

**Technology: TypeScript with strict mode**

Strict TypeScript will catch invalid API data assumptions and unsafe null handling before deployment.

### Tailwind CSS

**Technology: Tailwind CSS**

Tailwind will provide a controlled design system for responsive layouts, spacing, typography, status colours, and accessible interaction states.

### shadcn/ui and Radix UI

**Technologies: shadcn/ui and Radix UI primitives**

These will provide accessible dialogs, menus, forms, alerts, tabs, and other administrative interface components while keeping the component source within the project for local control.

### TanStack Router

**Technology: TanStack Router**

TanStack Router will manage typed portal routes, route guards, query parameters, and deep links into provider or request records.

### TanStack Query

**Technology: TanStack Query**

TanStack Query will fetch and cache server data, refresh changed records, invalidate stale views after mutations, and present loading and error states consistently.

### TanStack Table

**Technology: TanStack Table**

TanStack Table will support the approval, provider, request, journey, feedback, and audit lists with server-side filtering, sorting, and pagination.

### React Hook Form

**Technology: React Hook Form**

React Hook Form will manage efficient forms for Call Centre request entry, provider review, rejection reasons, confirmation, feedback, and administrative settings.

### Zod

**Technology: Zod**

Zod will validate web form input and API responses at the browser boundary. Server validation remains authoritative.

### react-oidc-context

**Technology: react-oidc-context**

This library will integrate the portal with Keycloak through OpenID Connect and PKCE, including login, logout, token renewal, and authenticated route handling.

### Google Maps JavaScript API

**Technology: Google Maps JavaScript API**

The Google Maps JavaScript API will render live journeys, request points, actual GPS route history, stopovers, and disposal-site arrival information in the KCCA portal. Restrict the browser API key by approved web origins and required APIs, and keep the Weyonje API responsible for deciding which operational records an authenticated user may view.

### Socket.IO Client

**Technology: Socket.IO Client**

The portal will subscribe only to journeys the authenticated KCCA user is authorised to view and receive live location and status updates without repeatedly polling the API.

### Grafana Faro

**Technology: Grafana Faro Web SDK**

Faro will report web performance and frontend errors into the self-hosted observability platform. It must be configured to remove phone numbers, tokens, precise locations, and form contents.

## 8. Backend API and Business Logic

### NestJS

**Technology: NestJS**

NestJS will structure the backend into modules with controllers, services, guards, interceptors, validation, and dependency injection. Its official documentation provides built-in patterns for OpenAPI, security, WebSockets, and queues, matching Weyonje's needs.

### Fastify Adapter

**Technology: NestJS Fastify adapter**

Fastify will provide the HTTP server beneath NestJS, giving efficient request handling while retaining NestJS structure.

### TypeORM

**Technology: TypeORM**

TypeORM will map application entities to PostgreSQL, manage reviewed migrations, support transactions, and handle PostGIS geometry columns. Complex geographical and reporting queries should use explicit parameterised SQL rather than forcing them through an abstraction.

### pg

**Technology: node-postgres (`pg`)**

This PostgreSQL driver will provide the underlying database connection and allow carefully reviewed SQL for PostGIS, locking, and performance-sensitive operations.

### class-validator and class-transformer

**Technologies: class-validator and class-transformer**

These will validate and transform incoming API request data through NestJS validation pipes. Validation errors should use one consistent, documented response format.

### NestJS Swagger/OpenAPI

**Technology: `@nestjs/swagger` and OpenAPI 3**

Generate an authoritative API contract and interactive internal documentation from backend request and response models. Generate client types from this contract so the mobile and web applications do not maintain handwritten copies.

### openapi-generator

**Technology: OpenAPI Generator**

Generate TypeScript and Dart API models or clients from the reviewed OpenAPI contract. Generated files should not contain business logic and should be regenerated through one repository command.

### Passport and JOSE

**Technologies: Passport JWT strategy and JOSE**

Validate Keycloak-issued access tokens, signatures, audiences, issuers, and expiry. Backend guards must enforce roles and record ownership even when the interface hides an action.

### Node.js Crypto HMAC

**Technology: Node.js Crypto with HMAC-SHA-256**

Store only a keyed HMAC of each short-lived SMS verification code, using a server-held secret, an expiry time, and a strict attempt limit. A plain hash is insufficient for low-entropy numeric codes. User passwords should remain under Keycloak rather than being duplicated in the Weyonje database.

### Pino

**Technology: Pino**

Produce fast structured JSON logs with request IDs, actor IDs, request IDs, journey IDs, severity, and safe error details. Logging rules must redact tokens, phone numbers, feedback text where unnecessary, and precise location payloads.

### Socket.IO

**Technology: Socket.IO**

Provide authenticated, room-based live updates for active journeys and request-status events. The server must authorise every subscription and must not allow a client to choose arbitrary provider or request identifiers.

### BullMQ

**Technology: BullMQ**

Run reminders, SMS delivery, push delivery, retryable integration work, cleanup, and other background tasks. Its delayed-job and retry features match the specification's scheduled reminders and unreliable external-network conditions.

### Transactional Outbox

**Technology/approach: PostgreSQL transactional outbox processed by BullMQ workers**

Write important notification intentions in the same PostgreSQL transaction as the business change, then dispatch them asynchronously. This prevents a request from becoming accepted while its notification silently disappears because the queue or SMS service was temporarily unavailable.

### date-fns

**Technology: date-fns**

Handle scheduled dates and time calculations consistently. Store timestamps in UTC and display them in Africa/Kampala time where required.

### libphonenumber-js

**Technology: libphonenumber-js**

Normalise and validate Ugandan telephone numbers before registration, OTP delivery, lookup, and SMS sending.

### Helmet and NestJS Throttler

**Technologies: Helmet and `@nestjs/throttler`**

Apply secure HTTP headers and rate limits, with stricter rules for login, OTP issuance, OTP verification, password recovery, registration, and public request endpoints.

## 9. Identity, Authentication, and Authorization

### Keycloak

**Technology: Keycloak**

Keycloak will be the central identity and access-management service for clients, service providers, KCCA staff, and administrators. It will issue standard OpenID Connect tokens, manage sessions, support role assignment, and keep authentication separate from Weyonje business records. Keycloak provides official production container guidance, health checks, metrics, PostgreSQL support, and standard OAuth/OIDC capabilities.

### OpenID Connect and OAuth 2.0 with PKCE

**Technology/standard: OpenID Connect and OAuth 2.0 Authorization Code Flow with PKCE**

Use standard browser-based authentication flows for the mobile and web clients. Do not place a privileged client secret inside the mobile or browser application.

### Application Roles and Server-Side Policy Guards

**Technology/approach: Keycloak roles plus NestJS guards and database ownership checks**

Keycloak will carry coarse roles such as client, service provider, KCCA staff, Call Centre staff, and system administrator. NestJS will enforce record-level rules such as whether a provider can see a particular request or a client can view a particular journey.

### Registration and Approval Orchestration

**Technology/approach: NestJS registration workflow integrated with Keycloak Admin API**

Weyonje will send and validate the required SMS code, then provision or enable the matching identity. Service-provider access to requests must remain disabled until KCCA approval. Rejection reasons and approval history belong in the Weyonje database, not only in identity metadata.

## 10. Database and Data Storage

### PostgreSQL 18

**Technology: PostgreSQL 18**

PostgreSQL will be the authoritative store for users' Weyonje profiles, providers, approvals, service requests, assignment history, agreed prices, workflow states, feedback, ratings, notifications, audit events, and journey metadata. Its transactions are essential when a business action changes several related records together.

### PostGIS 3.6

**Technology: PostGIS 3.6**

PostGIS extends PostgreSQL with geographical points, spatial indexes, distance checks, and other spatial functions. It will store request locations, sampled actual journey tracks, disposal-site locations, and Weyonje-owned route-history data and support arrival/geofence queries. Google Maps Platform provides map and calculated-route content but does not replace this authoritative operational store; storage and retention of Google-provided content must comply with the applicable Google Maps Platform terms.

### Valkey 9

**Technology: Valkey 9**

Valkey is a Linux Foundation-backed BSD-licensed, Redis-compatible in-memory data store. It will hold short-lived OTP state, rate-limit counters, cached reference data, WebSocket coordination, the latest provider position, and BullMQ job data. PostgreSQL remains the source of truth for durable business and journey history.

Because Valkey 9 is not a supported native Windows server and Render's managed Key Value offering does not currently provide the selected major version, run a pinned official Valkey 9 container as a Render Private Service for development. Attach appropriately sized persistent storage for BullMQ job recovery, require authentication, limit access to the private network, and document backup or recovery expectations. Render-hosted integration instances of the API and worker will connect to this service; Linux GitHub Actions tests will also exercise the selected Valkey 9 version in isolated test containers.

### Database Constraints

**Technology/approach: PostgreSQL constraints, foreign keys, unique indexes, check constraints, and transactions**

Use database-level safeguards for identifiers, active assignments, valid ratings, unique verified phone numbers where the business rules permit, and other invariants. Do not rely only on interface validation.

### Database Migrations

**Technology: TypeORM migrations reviewed as SQL changes**

Every schema change must be committed, reviewed, tested against a restored database copy, applied through CI/CD, and accompanied by a rollback or forward-recovery plan.

### pgBackRest

**Technology: pgBackRest**

Create encrypted, compressed full and incremental PostgreSQL backups with retention rules and point-in-time recovery support. Restore tests are required; successful backup jobs alone do not prove recoverability.

### Restic

**Technology: Restic**

Back up encrypted configuration, Keycloak realm exports, and other necessary non-database operational files to storage outside the production host. Google Maps content is not a Weyonje backup asset and must not be copied or retained contrary to Google Maps Platform terms.

## 11. Mapping, Routing, and Location Tracking

### Google Maps Platform

**Technology/service: Google Maps Platform — Paid External Dependency**

Use Google Maps Platform for the approved map, place-search, address-search, and routing capabilities. Google operates the underlying map infrastructure; Weyonje will not process, store, serve, update, or maintain its own base-map, geocoding, or routing datasets. This simplifies infrastructure but creates dependencies on reliable internet access, Google service availability, billing, contractual terms, and continued account access.

Google Maps Platform is not Weyonje's business database. Store Weyonje-owned service locations, sampled GPS positions, disposal-site records, and actual journey history in PostgreSQL/PostGIS. Store or cache Google-provided content only where and for as long as the applicable service terms permit, and preserve required Google attribution.

### Places API (New)

**Technology/service: Google Places API (New)**

Use Places API (New) for the place and address search needed by mobile users and Call Centre staff when identifying a collection or disposal location. Request only the fields required by the workflow, use session-based autocomplete correctly where applicable, and do not add place photos, reviews, or unrelated place features without an approved requirement.

### Geocoding API

**Technology/service: Google Geocoding API**

Use the Geocoding API only when Weyonje must convert an entered address to coordinates or coordinates to a human-readable address and the same result cannot be obtained through the selected place-search flow. A user-confirmed map point and Weyonje's stored coordinates remain the operational location record.

### Routes API

**Technology/service: Google Routes API**

Use the Routes API to calculate estimated road routes, distance, and travel time for documented collection and disposal journeys. Calculated routes are guidance; the provider's timestamped GPS samples stored by Weyonje remain the evidence of the actual journey. Avoid repeated route calculations for every location update, request only required fields, and apply quotas and caching rules consistent with Google's terms.

### API-Key, Quota, and Cost Controls

**Technology/approach: Restricted Google Maps credentials, quotas, budgets, and usage monitoring**

Use separate credentials for mobile, web, backend, development, staging, and production as appropriate. Restrict keys by application, approved origin, package/signing identity, source address where feasible, and the minimum required APIs. Keep server credentials out of Flutter and browser bundles, never commit keys or service credentials to GitHub, configure quotas and spending alerts, monitor usage by environment and API, and rotate compromised credentials promptly. Spending alerts do not by themselves prevent charges, so enforce quotas and operational review as well.

### Privacy, Data Protection, and Contractual Controls

**Technology/approach: Data minimisation and approved Google Maps Platform usage**

Send Google only the location information required for the requested map operation. Do not send client names, phone numbers, request notes, provider identities, or other unnecessary business data in mapping requests. Complete legal, privacy, procurement, data-residency, retention, and contractual review before production use, update user-facing privacy information where required, and document which Google services receive which location data.

### PostGIS Arrival Detection

**Technology/approach: PostGIS `ST_DWithin` geofence checks**

Determine whether the provider is within an approved radius of the Weyonje-stored request or disposal point before generating an arrival event. Require multiple accurate samples or a short dwell period to reduce false arrivals caused by GPS drift. This authoritative arrival decision remains in Weyonje rather than depending on a client-side map display.

### Location Sampling Policy

**Technology/approach: Adaptive GPS sampling and bounded offline queue**

Sample frequently enough to show useful movement during active journeys, reduce frequency when stationary, and stop on completion. Upload batches after brief connectivity loss, reject impossible jumps, and record accuracy and timestamps with every point.

## 12. Notifications and Communications

### Africa's Talking SMS API — Paid and Necessary

**Technology/service: Africa's Talking Bulk SMS for Uganda**

Use Africa's Talking for phone-verification codes and SMS notifications to clients who use the Call Centre or cannot receive app push notifications. It is a required paid communications service because delivery to Ugandan mobile networks incurs a per-message telecommunications charge. Google Maps Platform and Render development infrastructure may also create recurring charges. Africa's Talking officially lists bulk SMS availability in Uganda.

Abstract the SMS provider behind a Weyonje interface so that KCCA can change provider later without changing registration or request workflows. Store provider message IDs and delivery results, but never log OTP values.

### Firebase Cloud Messaging — No-Cost Service

**Technology/service: Firebase Cloud Messaging**

Use FCM for app push notifications. Google's current Firebase pricing documentation lists Cloud Messaging as a no-cost product. Firebase should not become Weyonje's database or authentication system; it is used only for push delivery and app registration tokens.

### In-System Notifications

**Technology/approach: PostgreSQL notification records delivered through REST and Socket.IO**

Store an auditable notification record in Weyonje, expose it in mobile and web notification centres, and use SMS or FCM as delivery channels rather than the sole record of an important event.

### Delivery Tracking and Retry

**Technology/approach: BullMQ retries, exponential backoff, deduplication, and dead-letter review**

Retry temporary provider failures without sending duplicates. Stop retrying permanent failures and make failed notifications visible to authorised operational staff.

## 13. API and Integration Standards

### OpenAPI 3

**Technology/standard: OpenAPI 3**

Document request and response formats, authentication requirements, error codes, pagination, and WebSocket-related references. Treat the generated specification as a reviewed contract, not as a substitute for business documentation.

### JSON over HTTPS

**Technology/standard: JSON over HTTPS**

Use UTF-8 JSON for mobile and web API communication. All external traffic must use TLS; unencrypted HTTP should exist only within tightly controlled private development or container networks where justified.

### Idempotency Keys

**Technology/approach: Idempotency keys for retryable write operations**

Prevent duplicate service requests, job starts, collection confirmations, and completion actions when a mobile device retries after an uncertain network response.

### Webhooks

**Technology/approach: Signed webhook endpoints**

Receive SMS delivery reports through allow-listed, authenticated or cryptographically verified endpoints. Persist raw external identifiers safely and process events idempotently.

## 14. Source Control and Repository Management

### Git

**Technology: Git**

Track all source code, migrations, configuration templates, infrastructure automation, approved Google Maps configuration references, documentation, and tests. Secrets, unrestricted API keys, and generated production data must never be committed.

### GitHub

**Technology/platform: GitHub**

Host the Weyonje monorepo and provide pull requests, code review, issues, release tags, branch protection, repository rules, and team permissions. The repository must belong to an approved organisation rather than an individual developer, use least-privilege access, require multi-factor authentication where supported, and protect release and deployment branches from unreviewed changes.

### GitHub Container Registry

**Technology/platform: GitHub Container Registry**

Store versioned, scanned container images produced by GitHub Actions where container packaging is required. Limit package permissions, authenticate with short-lived or narrowly scoped credentials, and deploy immutable version tags or digests rather than `latest`.

### pnpm Workspaces

**Technology: pnpm workspaces**

Manage the backend, worker, web portal, shared TypeScript packages, and tooling in one repository with one lockfile and efficient dependency storage.

### FVM

**Technology: Flutter Version Management**

Pin the Flutter SDK version used by developers and CI so builds do not change unexpectedly when a developer updates their global Flutter installation.

### Task

**Technology: Taskfile/Task**

Provide memorable cross-platform commands for setup, code generation, linting, testing, database migrations, supported Windows processes, approved remote development services, and builds.

### Conventional Commits and Commitlint

**Technologies: Conventional Commits and Commitlint**

Standardise commit intent and support reliable release notes. This should aid review rather than become a substitute for meaningful pull-request descriptions.

## 15. Windows and Render Development Environment

### Windows 11

**Platform: Windows 11 development workstation**

Develop the Flutter mobile application, React portal, NestJS API, BullMQ worker code, supported automated tests, and documentation directly on Windows. Install and pin the approved Flutter, Dart, Node.js, pnpm, OpenJDK, Android, Git, and development-tool versions natively. WSL, Docker Desktop, and a local Linux installation are not workstation requirements.

### Visual Studio Code

**Technology: Visual Studio Code**

Use one editor configuration for Dart, Flutter, TypeScript, ESLint, formatting, tests, Dockerfile and workflow-file validation, and Git/GitHub workflows. Container execution remains in GitHub Actions, Render, staging, or production rather than on the Windows workstation.

### Android Studio

**Technology: Android Studio**

Provide the Android SDK, emulator, device inspection, signing support, and native debugging required for Flutter development. Use a maintained physical Android device whenever the emulator cannot run or when testing GPS accuracy, foreground tracking, notifications, battery restrictions, and real device behaviour.

### Render Development Environment

**Platform/service: Render**

Provide the shared Linux development environment for Valkey 9 and any other component that cannot run reliably or natively on Windows. Valkey 9 will run as a private containerized service. Render will also host integration instances of the NestJS API and BullMQ worker so they can connect to Valkey over the private network. Whether PostgreSQL/PostGIS, Keycloak, and monitoring services also run on Render must be decided and documented as the development architecture is finalised; this document does not assume that those services will run there.

The Render-hosted API and worker will require secure, network-reachable development PostgreSQL/PostGIS and Keycloak endpoints. Their final hosting location is unresolved; do not expose services running on an individual Windows workstation merely to satisfy this dependency.

Render is a runtime and integration environment, not the place where developers edit source code. Developers work in the Windows checkout, push changes to GitHub, and connect the Flutter and web applications to approved Render-hosted endpoints for complete integration testing.

### Render API and Blueprint Configuration

**Technologies: Render API and Render Blueprints**

Manage Render services, deployments, environment groups, and other supported resources programmatically through the Render API and version-controlled Blueprint configuration. Keep API tokens and service secrets in protected GitHub or Render settings, grant the minimum required access, rotate them deliberately, and never commit them to the repository. Treat the Render Dashboard as an operational interface rather than an undocumented second source of configuration.

### Development Workflow

**Technology/approach: Windows development with GitHub automation and Render integration testing**

Use the following workflow:

1. Developers write and run supported code and tests on Windows.
2. Changes are committed and pushed to GitHub.
3. GitHub Actions runs platform-independent checks and Linux-specific automated tests, including container-based PostgreSQL/PostGIS, Valkey 9, and Keycloak integration tests where required.
4. Approved changes are deployed to the Render development environment.
5. The Flutter and web applications connect to Render-hosted services for complete integration testing.

This workflow depends on reliable internet connectivity and the availability of GitHub and Render. Define safe behaviour for temporary outages, avoid making unpushed local work the only copy of important changes, and do not allow development shortcuts to bypass required Linux integration tests.

### DBeaver Community

**Technology: DBeaver Community**

Inspect PostgreSQL data and execute authorised development queries against an approved native Windows or Render-hosted development database. Use TLS and restricted credentials for remote access; production write access should remain restricted and audited.

### Bruno

**Technology: Bruno**

Store human-readable API request collections in Git for development, debugging, demonstrations, and repeatable manual verification without a paid collaboration service.

## 16. Code Quality and Static Analysis

### ESLint

**Technology: ESLint**

Enforce TypeScript and React correctness rules and block unsafe patterns in CI.

### Prettier

**Technology: Prettier**

Apply one automatic format to TypeScript, JavaScript, JSON, YAML, and Markdown so reviews focus on behaviour rather than style.

### Dart Analyzer and flutter_lints

**Technologies: Dart Analyzer and flutter_lints**

Enforce sound Dart typing, Flutter conventions, and agreed project-specific rules.

### Lefthook

**Technology: Lefthook**

Run fast formatting, linting, and secret checks before commits while keeping the full authoritative checks in CI.

### Renovate

**Technology: Renovate for GitHub**

Open controlled dependency-update pull requests with changelogs and compatibility information. Security updates should be prioritised, but all updates still require tests and review. Configure Renovate through repository-controlled settings and grant only the repository permissions it requires.

## 17. Testing Stack

### flutter_test

**Technology: flutter_test**

Test mobile widgets, validation, navigation, state handling, and presentation behaviour.

### integration_test

**Technology: Flutter integration_test**

Test complete mobile flows on emulators and physical devices, including registration, OTP entry, request creation, provider acceptance, job initiation, collection confirmation, and disposal completion.

### Mocktail

**Technology: Mocktail**

Provide strongly typed Dart test doubles without code generation for focused mobile unit tests.

### Vitest

**Technology: Vitest**

Run fast unit and component tests for the React portal and shared TypeScript utilities.

### React Testing Library

**Technology: React Testing Library**

Test portal behaviour from the user's perspective, including permissions, form errors, status display, and loading or empty states.

### Playwright

**Technology: Playwright**

Run browser-level tests for KCCA approval, Call Centre request entry, provider assignment, journey monitoring, feedback, and administrative access.

### Jest

**Technology: Jest**

Run backend unit and integration tests for services, guards, state transitions, notification policies, and error handling.

### Supertest

**Technology: Supertest**

Exercise the running NestJS HTTP API, including authentication, validation, status codes, and database effects.

### Testcontainers

**Technology: Testcontainers**

Run integration tests against real PostgreSQL/PostGIS, Valkey 9, and Keycloak containers rather than unrealistic in-memory substitutes. Because developers do not run a local container engine, execute these tests on standard Ubuntu GitHub Actions runners or another approved Linux runner with container support.

### Google Maps Integration Testing

**Technology/approach: Mocked unit tests plus controlled Google Maps development integration tests**

Keep application-owned mapping adapters testable without calling Google for every unit or component test. Use a restricted development Google Cloud project for the smaller set of tests that must verify real Maps, Places, Geocoding, or Routes behaviour. Apply test quotas and spending alerts, avoid load-testing Google services, and verify denied-key, quota, timeout, unavailable-service, and invalid-location handling without recording sensitive production locations.

### k6

**Technology: Grafana k6**

Test Weyonje API capacity, concurrent mobile requests, WebSocket connections, and location-update load before production releases. Stub or isolate paid external services such as Google Maps Platform, Africa's Talking, and FCM during load tests unless a separately approved test explicitly requires them.

### Physical Android Devices

**Technology/approach: A maintained physical-device test set**

Verify GPS accuracy, foreground-service behaviour, battery use, permission flows, notifications, weak-network recovery, and vendor-specific Android restrictions. Emulator tests alone are insufficient for Weyonje's tracking requirements.

### Firebase Test Lab — Optional No-Cost Quota, Paid Beyond Quota

**Technology/service: Firebase Test Lab**

Use its no-cost quota for wider Android-device coverage when useful. Additional device minutes are paid and should be approved only when the physical KCCA device set cannot cover a release risk.

## 18. Security Tools and Controls

### OWASP ASVS, MASVS, and API Security Top 10

**Technology/standards: OWASP ASVS, MASVS, and API Security Top 10**

Use these as checklists for the web, mobile, and API security requirements, particularly authentication, authorisation, sensitive-data storage, transport security, and object-level access control.

### Gitleaks

**Technology: Gitleaks**

Scan commits and GitHub Actions workspaces for passwords, Google Maps and Render API keys, private keys, and other secrets before they reach protected branches.

### Semgrep Community Edition

**Technology: Semgrep Community Edition**

Scan TypeScript and Dart code for insecure patterns and organisation-specific rules.

### Trivy

**Technology: Trivy**

Scan dependencies, container images, operating-system packages, configuration, and generated software bills of materials for known vulnerabilities and risky settings.

### OWASP ZAP

**Technology: OWASP ZAP**

Run automated security checks against staging APIs and the web portal, then manually review material findings before release.

### MobSF

**Technology: Mobile Security Framework (MobSF)**

Analyse release APKs for exposed secrets, unsafe permissions, weak transport configuration, insecure storage, and packaging mistakes.

### ModSecurity with OWASP Core Rule Set

**Technology: ModSecurity and OWASP CRS**

Provide a carefully tuned web-application firewall layer at Nginx for common malicious traffic. Start in detection mode, review false positives, and then enable blocking rules deliberately.

### SOPS and age

**Technologies: SOPS and age**

Encrypt environment-specific secret files for controlled storage and deployment. Decryption keys must remain outside Git and be limited to authorised GitHub Actions environments and operators. Prefer platform secret stores for Render and Google credentials that do not need to exist as encrypted repository files.

### CycloneDX SBOM

**Technology: CycloneDX software bill of materials**

Generate a machine-readable inventory of application and container dependencies for each release, allowing KCCA to identify exposure when a library vulnerability is announced.

### Audit Log

**Technology/approach: Append-only PostgreSQL audit events**

Record high-value actions such as provider approval or rejection, role changes, request assignment, price updates, status transitions, collection confirmation, and administrative access. Application users must not be able to edit audit records.

## 19. Continuous Integration and Delivery

### GitHub Actions Runners

**Technology: GitHub-hosted Ubuntu and Windows runners**

Run repeatable workflows for linting, tests, code generation, security scans, image builds, and deployment. Use Windows runners only where Windows-specific verification is material, and use standard Ubuntu runners for Linux and container-based checks including Testcontainers and Valkey 9 integration. Pin action versions to reviewed immutable references where practical and grant each workflow the minimum required permissions.

GitHub-hosted runner capacity, included minutes, network access, and static-IP requirements depend on the selected GitHub plan and repository settings. If standard hosted runners cannot securely reach a required private resource or lack sufficient capacity, document and approve a self-hosted or larger-runner design rather than silently weakening the test.

### GitHub Actions

**Technology: GitHub Actions**

Define continuous integration and delivery as version-controlled workflows. A pull request must not merge into a protected release branch or deploy to a higher environment unless required tests, scans, reviews, and approvals succeed. Use GitHub environments, protected secrets, concurrency controls, and explicit deployment approvals to separate development, staging, and production authority.

### Docker BuildKit and Buildx

**Technologies: Docker BuildKit and Buildx**

Create reproducible multi-stage container images with dependency caching, minimal production layers, non-root users, and architecture-aware builds on GitHub Actions, Render, or approved Linux build infrastructure. Developers do not need Docker Desktop locally, but Dockerfiles and resulting images remain part of remote CI, development hosting where used, staging, and production.

### Cosign

**Technology: Cosign**

Sign approved container images and verify signatures before production deployment so an untrusted or accidentally replaced image cannot be promoted silently.

### Ansible

**Technology: Ansible**

Provision and update Ubuntu hosts, users, firewalls, Docker, directories, certificates, backup jobs, monitoring agents, and deployment configuration consistently.

### Staged Environments

**Technology/approach: Development, test, staging, and production environments**

Keep production data and credentials out of lower environments. Staging should reproduce production architecture closely enough to validate migrations, integrations, tracking, and deployment procedures.

## 20. Production Infrastructure and Deployment

### KCCA-Managed Virtual Machines

**Platform: KCCA-managed virtual machines**

Host Weyonje on infrastructure controlled by KCCA unless an approved hosting decision says otherwise. Separate public application services from data services through network rules and do not expose PostgreSQL, Valkey, or Keycloak administration directly to the internet.

### Ubuntu Server 24.04 LTS

**Technology: Ubuntu Server 24.04 LTS**

Use the mature 24.04 LTS line as the production operating system baseline. Ubuntu documents five years of standard security maintenance for LTS releases, with extended maintenance available beyond that period.

### Docker Engine

**Technology: Docker Engine**

Package the web portal, API, worker, Keycloak, and observability components consistently. Pin image versions and run application containers as non-root users. Google Maps Platform is an external service and is not packaged or hosted by Weyonje.

### Docker Compose

**Technology: Docker Compose**

Define each environment's services, internal networks, health checks, resource limits, volumes, and restart behaviour. It is sufficient for the documented scope and substantially easier to operate than Kubernetes.

### Nginx

**Technology: Nginx**

Terminate TLS, serve the React bundle, proxy API and WebSocket traffic, apply request-size and rate limits, and add security headers. Google map content is loaded through the approved Google Maps Platform integration rather than served from KCCA map files.

### Let's Encrypt and Certbot

**Technologies: Let's Encrypt and Certbot**

Issue and renew free public TLS certificates when the Weyonje domains are publicly resolvable. If KCCA policy requires its own certificate authority, use the approved KCCA certificate process instead while retaining automated expiry monitoring.

### UFW and Host Firewall Rules

**Technology: UFW with Docker-aware firewall configuration**

Allow only required inbound ports, management networks, and monitoring paths. Docker changes host packet filtering, so the rules must be tested through the `DOCKER-USER` chain rather than assuming ordinary UFW rules cover containers.

### systemd

**Technology: systemd**

Start and supervise Docker Compose deployments, backup timers, certificate checks, and other host-level maintenance tasks.

## 21. Monitoring, Logging, and Operational Diagnostics

### OpenTelemetry

**Technology: OpenTelemetry SDKs and Collector**

Create consistent traces, metrics, and diagnostic context across the API, workers, Keycloak integration, notification delivery, and web portal without locking Weyonje into one monitoring vendor.

### Prometheus

**Technology: Prometheus**

Collect time-series metrics for API latency, errors, active journeys, WebSocket connections, queue delays, SMS failures, Google Maps integration failures and latency, database health, server capacity, and business-process completion rates. Track Google Maps quota consumption, billing, and spending alerts through the approved Google Cloud controls rather than assuming Prometheus alone provides authoritative billing data.

### Grafana

**Technology: Grafana OSS**

Provide role-appropriate dashboards for developers and operators, including system health and safe aggregated process indicators.

### Loki

**Technology: Grafana Loki**

Store and search structured application and infrastructure logs without mixing them into the transactional database.

### Tempo

**Technology: Grafana Tempo**

Store distributed traces so an operator can follow a request from the web or mobile API through the database, job queue, and notification provider.

### Alertmanager

**Technology: Prometheus Alertmanager**

Route actionable alerts for service outages, sustained errors, queue backlogs, database capacity, backup failure, certificate expiry, and notification-delivery problems.

### Uptime Kuma

**Technology: Uptime Kuma**

Perform simple external checks of public endpoints, certificate validity, and expected health responses so complete loss of service is noticed even when internal metrics fail.

### Exporters

**Technologies: Node Exporter, PostgreSQL Exporter, cAdvisor, and Blackbox Exporter**

Expose host, database, container, and network-check metrics to Prometheus using established open-source exporters.

### GlitchTip

**Technology: Self-hosted GlitchTip**

Collect grouped application exceptions and release regressions from the mobile app and backend while keeping diagnostic data under KCCA control. A Render-hosted development GlitchTip instance is optional until the development monitoring topology is confirmed; production hosting remains part of the approved KCCA infrastructure design.

## 22. Backup, Recovery, and Maintenance

### Off-Host Backup Storage

**Technology/approach: Encrypted off-host backup repository**

Store pgBackRest and Restic backups outside the production server and, where possible, outside the same physical failure domain. The exact storage platform depends on KCCA infrastructure and must be documented before production.

### Point-in-Time Recovery

**Technology/approach: PostgreSQL WAL archiving through pgBackRest**

Allow recovery to a selected moment before corruption or operator error rather than restoring only the previous nightly snapshot.

### Restore Drills

**Technology/approach: Automated restore verification plus scheduled manual recovery exercises**

Restore databases and files into an isolated environment, run integrity checks and smoke tests, record results, and correct procedures that fail.

### Unattended Upgrades with Controlled Reboots

**Technology: Ubuntu unattended-upgrades**

Apply appropriate security patches automatically while scheduling disruptive updates and reboots through an approved maintenance window.

### Runbooks in Markdown

**Technology: Version-controlled Markdown runbooks**

Document deployment, rollback, failed SMS handling, stuck jobs, Google Maps outage or quota exhaustion, database recovery, certificate renewal, Keycloak recovery, and incident escalation next to the code that changes them.

## 23. Documentation Tools

### Markdown

**Technology: Markdown**

Maintain architecture, setup, decisions, runbooks, requirements traceability, and current-state documentation in reviewable text files.

### MkDocs Material

**Technology: MkDocs Material**

Publish the approved Markdown documents as a searchable internal technical and operations site.

### Mermaid

**Technology: Mermaid**

Keep architecture, workflow, state, and deployment diagrams text-based and version-controlled so they can be reviewed with the implementation.

### Architecture Decision Records

**Technology/approach: Markdown Architecture Decision Records**

Record important decisions, their context, chosen approach, consequences, and superseding decisions without rewriting history.

### CURRENT_SYSTEM_STATE.md

**Technology/approach: Living current-state document based on `CURRENT_SYSTEM_STATE_TEMPLATE.md`**

Update the document whenever implemented functionality, architecture, roles, integrations, configuration, environments, operations, risks, or known issues change. Planned work must remain clearly separated from implemented behaviour.

## 24. Technologies Deliberately Excluded from the Baseline

### Kubernetes

Kubernetes is not recommended initially because the specification does not establish the traffic, deployment count, availability objective, or operations team needed to justify its complexity. Docker Compose is the better baseline and does not prevent a later migration if evidence demands it.

### Microservices

Microservices are not recommended because the documented processes share transactions, state transitions, actors, and data. Premature separation would increase failure modes, deployment work, and data consistency problems.

### Firebase Authentication, Firestore, and Realtime Database

These are not recommended because Keycloak and PostgreSQL provide a more coherent, self-hosted identity and transactional data model. Firebase is limited to no-cost push delivery.

### Self-Hosted OpenStreetMap Stack

OpenStreetMap-derived self-hosting with MapLibre, Planetiler, PMTiles, Maputnik, Nominatim, and OSRM was superseded by the decision to use Google Maps Platform. It is not part of the selected baseline because the project has chosen lower development and operational complexity over operating its own map, geocoding, and routing infrastructure. PostGIS remains selected for Weyonje-owned coordinates, actual journey history, spatial queries, and arrival detection.

### Payment Gateway

No payment gateway is included because the specification records an agreed price but does not describe electronic payment, invoicing, settlement, or commission collection.

### General Object Storage

MinIO or another business-document store is not included because the specification does not require licences, photographs, receipts, or other file uploads. It should be added only after the required files, retention, access, and security rules are approved.

### Message Broker Beyond BullMQ and Valkey

RabbitMQ or Kafka is not recommended initially. BullMQ and Valkey are enough for reminders, notification delivery, and background processing at the documented scope. A separate broker should be introduced only after measured workload or integration requirements justify it.

## 25. Required Paid Items

### Google Maps Platform Usage

Google Maps Platform requires a billing-enabled Google Cloud project. Map loads, place and address searches, geocoding, route calculations, and other enabled services may incur usage charges. Configure least-privilege API access, environment-specific credentials, quotas, budgets, and spending alerts, and assign responsibility for regular cost and usage review before enabling production traffic.

### Render Development Infrastructure

Render will host the private Valkey 9 development service together with integration instances of the NestJS API and BullMQ worker. It may host PostgreSQL/PostGIS, Keycloak, monitoring, or other development components after the remaining topology is confirmed. Required compute, storage, bandwidth, persistent disks, and workspace features may incur recurring charges. Record service ownership, spending limits, suspension and cleanup procedures, and the migration path to KCCA-controlled staging and production infrastructure.

### GitHub Usage, If Beyond Included Allowances

The approved GitHub organisation, private-repository plan, Actions minutes, runner capacity, artifact retention, and GitHub Container Registry usage must be confirmed. Usage beyond included allowances or advanced organisation controls may be paid; configure budgets, retention limits, permissions, and ownership accordingly.

### Africa's Talking SMS Credit

This is required because the specification mandates SMS verification and SMS notifications for Call Centre clients. SMS delivery is billed per message and may also require sender-name registration or regulatory/network setup.

### Production Infrastructure

Most application and operational components remain open source and can be self-hosted for production, but Google Maps Platform is a commercial external dependency and Render is a paid development dependency where free allowances are insufficient. Production virtual machines, storage, backups, networking, domains, and support also have real infrastructure costs unless supplied internally by KCCA.

### Mobile Distribution Fees, If Applicable

Public application-store publication may require platform developer-account fees. This is not included as a firm requirement because the specification does not state whether Weyonje will use public stores, managed organisational distribution, or direct deployment.

## 26. Important Validation Before Implementation Is Locked

The stack is coherent and ready to guide development, but the following facts must be confirmed because they affect capacity or configuration rather than the technology choice:

- expected numbers of clients, providers, KCCA staff, daily requests, and simultaneous active journeys;
- Android versions and device types used by service providers;
- whether iOS must be supported at launch;
- service area and approved disposal-site list;
- exact Google Maps Platform APIs to enable after detailed workflow validation, expected request volumes, approved billing account, quotas, budgets, key restrictions, and cost owner;
- privacy, procurement, contractual, data-residency, and records-retention approval for sending the minimum necessary location information to Google Maps Platform;
- required GPS sampling interval, arrival radius, route-history retention, and who may view historical locations;
- whether clients may select a provider or whether all assignments are controlled by KCCA;
- authoritative pricing rules and who may change an agreed price;
- exact notification matrix, message wording, reminder timing, retry policy, and escalation process;
- KCCA identity integration requirements for staff, if any;
- hosting, availability, recovery-time, recovery-point, and data-residency requirements;
- whether PostgreSQL/PostGIS, Keycloak, monitoring, or other development services will join the confirmed Valkey 9, API, and worker integration services on Render, together with the selected region, capacity, persistence, networking, access controls, costs, and responsibility for operation;
- the approved GitHub organisation and plan, repository ownership, Actions and runner model, GitHub Container Registry retention, and required access controls;
- Ugandan data-protection, records-retention, and audit requirements applicable to client and location data; and
- the relationship between client confirmation in the app-based flow and KCCA-recorded confirmation in the Call Centre flow.

These confirmations should populate `CURRENT_SYSTEM_STATE.md` only after they are implemented or operationally established; before that, they belong in requirements and decision records. Workstation setup instructions, architecture records, operational documentation, and the future `CURRENT_SYSTEM_STATE.md` must all be aligned with the Windows, GitHub, Render, and Google Maps Platform decisions in this document.

## 27. Official References Used to Verify Key Choices

- [Flutter supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms)
- [Node.js release and LTS policy](https://nodejs.org/en/about/previous-releases)
- [NestJS documentation](https://docs.nestjs.com/)
- [PostgreSQL current documentation](https://www.postgresql.org/docs/current/)
- [PostGIS documentation](https://postgis.net/documentation/manual/)
- [Valkey project and releases](https://valkey.io/)
- [Keycloak production container guidance](https://www.keycloak.org/server/containers)
- [Google Maps for Flutter](https://developers.google.com/maps/flutter-package/overview)
- [Google Maps JavaScript API](https://developers.google.com/maps/documentation/javascript/)
- [Google Places API (New)](https://developers.google.com/maps/documentation/places/web-service/overview)
- [Google Geocoding API](https://developers.google.com/maps/documentation/geocoding/overview)
- [Google Routes API](https://developers.google.com/maps/documentation/routes)
- [Google Maps Platform API security guidance](https://developers.google.com/maps/api-security-best-practices)
- [Google Maps Platform pricing and billing](https://developers.google.com/maps/billing-and-pricing/overview)
- [Google Maps Platform terms and policies](https://developers.google.com/maps/terms)
- [GitHub Actions documentation](https://docs.github.com/actions)
- [GitHub-hosted runners reference](https://docs.github.com/actions/reference/runners/github-hosted-runners)
- [GitHub Container Registry documentation](https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Render API documentation](https://render.com/docs/api)
- [Render Blueprints](https://render.com/docs/infrastructure-as-code)
- [Firebase pricing and no-cost products](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
- [Africa's Talking product availability by country](https://help.africastalking.com/en/articles/2727792-which-countries-are-africa-s-talking-products-in)
- [BullMQ delayed jobs](https://docs.bullmq.io/guide/jobs/delayed)
- [BullMQ retry handling](https://docs.bullmq.io/guide/retrying-failing-jobs)
- [Ubuntu release support](https://documentation.ubuntu.com/project/release-team/ubuntu-releases/)
- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

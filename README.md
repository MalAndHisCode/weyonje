# Weyonje

Weyonje is an Android Flutter application with a NestJS/Fastify API. It implements native authentication/registration, role eligibility, Client service requests, Provider marketplace acceptance and jobs, KCCA monitoring, collection feedback/follow-up, KCCA-controlled disposal, persisted location tracking, durable notifications/outbox, and authenticated Socket.IO hints with REST reconciliation.

The repository is a development implementation. Railway is the user-confirmed GitHub-connected deployment target with the service rooted at the repository root; its live deployment health and configuration have not been inspected in this task. Neon and all live external integrations remain unverified. Google Maps, push delivery, production background tracking, outbox processing, retention purge, scheduled reminders, and release operations require separate authorisation and production decisions.

## Repository

- `apps/mobile`: Flutter/Forui role workflows, device-location boundary, Socket.IO client, native authentication, and encrypted platform session storage.
- `apps/api`: NestJS/Fastify authentication plus service-request, assignment, journey, feedback, disposal, notification/outbox, and Socket.IO workflows on Prisma.
- `packages/contracts`: shared authentication, workflow, actor/access, and safe-error contracts.
- `docs/project-context`: adopted requirements, UX/brand guidance, architecture, and verified current state.

## Local checks

```text
pnpm install --frozen-lockfile
pnpm format
pnpm typecheck
pnpm test
pnpm build
pnpm openapi:check
pnpm audit --prod --audit-level high

cd apps/mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/auth.local.json
```

Database integration is opt-in and requires an isolated PostgreSQL database explicitly supplied through `TEST_DATABASE_URL` and `TEST_DIRECT_URL`. Routine checks do not connect to Neon or any shared database.

## Development configuration

Copy `.env.example` to an ignored `.env`, replace every placeholder, and keep every cryptographic key separate. The API uses Neon's pooled address as `DATABASE_URL` and direct address as `DIRECT_URL`. Apply the checked-in migration from an approved workstation:

```text
pnpm --filter @weyonje/api migration:deploy
```

Create development accounts interactively; email and masked password are prompted and no password is accepted on the command line:

```text
pnpm --filter @weyonje/api provision:user -- --actor-type CLIENT --email-verified
pnpm --filter @weyonje/api provision:user -- --actor-type SERVICE_PROVIDER --provider-status APPROVED --email-verified
pnpm --filter @weyonje/api provision:user -- --actor-type KCCA_STAFF --kcca-mobile-monitoring --email-verified
pnpm --filter @weyonje/api provision:user -- --actor-type KCCA_STAFF --kcca-mobile-monitoring --call-centre-operations --email-verified
```

The mobile build requires only the HTTPS API base URL. `WEYONJE_GOOGLE_MAPS_ENABLED` remains false until an authorised integration exists:

```text
cd apps/mobile
copy config\auth.example.json config\auth.local.json
flutter run --dart-define-from-file=config/auth.local.json
```

See [apps/api/README.md](apps/api/README.md), [apps/mobile/README.md](apps/mobile/README.md), and [docs/project-context/CURRENT_SYSTEM_STATE.md](docs/project-context/CURRENT_SYSTEM_STATE.md) for security, Neon, Railway, and known-limitation details.

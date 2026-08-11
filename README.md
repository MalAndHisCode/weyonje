# Weyonje

Weyonje is an Android Flutter application with a NestJS/Fastify API. The implemented slice preserves `AUTH-001` welcome/account access and bounded `AUTH-002` account-type selection, and implements native email/password sign-in with Prisma-backed server sessions for `AUTH-003`.

Registration, password recovery, verification delivery, Provider approval, dashboards, and downstream waste-collection workflows are not implemented. Their existing route boundaries remain truthful and collect no data.

## Repository

- `apps/mobile`: Flutter, Forui, Riverpod, GoRouter, Dio, native sign-in fields, and encrypted platform session storage.
- `apps/api`: NestJS/Fastify native authentication, Prisma, Argon2id, encrypted email storage, rotating sessions, and eligibility.
- `packages/contracts`: shared authentication, actor, provider-status, access, and safe-error contracts.
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
```

The mobile build needs only the HTTPS API base URL:

```text
cd apps/mobile
copy config\auth.example.json config\auth.local.json
flutter run --dart-define-from-file=config/auth.local.json
```

See [apps/api/README.md](apps/api/README.md), [apps/mobile/README.md](apps/mobile/README.md), and [docs/project-context/CURRENT_SYSTEM_STATE.md](docs/project-context/CURRENT_SYSTEM_STATE.md) for security, Neon, Koyeb Free, and known-limitation details.

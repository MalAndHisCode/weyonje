# Weyonje

Weyonje is an Android Flutter application with a NestJS/Fastify API. The current implemented slice covers `AUTH-001` welcome and account access, bounded `AUTH-002` account-type selection, and `AUTH-003` browser-based Keycloak Authorization Code Flow with PKCE.

Registration data collection and role dashboards are intentionally outside this slice. Their route boundaries state that the destination is unavailable and do not simulate completed functionality.

## Repository

- `apps/mobile`: Flutter, Forui, Riverpod, GoRouter, Dio, AppAuth, and secure token storage.
- `apps/api`: NestJS/Fastify identity and eligibility API with TypeORM/PostgreSQL.
- `packages/contracts`: shared TypeScript actor, provider-status, access, and error contracts.
- `docs/project-context`: adopted product, UX, brand, architecture, and current-state sources.

## Local checks

```text
pnpm install
pnpm format
pnpm typecheck
pnpm test
pnpm build
pnpm openapi:check

cd apps/mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

The API requires configured Keycloak and PostgreSQL services to start. Copy `.env.example` to an ignored `.env` and replace every placeholder. Run migrations with `pnpm --filter @weyonje/api migration:run` before starting the API.

The mobile app receives non-secret environment coordinates at compile time:

```text
cd apps/mobile
copy config\auth.example.json config\auth.local.json
flutter run --dart-define-from-file=config/auth.local.json
```

Never put a Keycloak client secret in the mobile configuration. The Android redirect scheme defaults to `ug.go.kcca.weyonje.auth`, matching `ug.go.kcca.weyonje.auth:/oauthredirect` in the example.

See [apps/api/README.md](apps/api/README.md) and [apps/mobile/README.md](apps/mobile/README.md) for exact identity and runtime setup.

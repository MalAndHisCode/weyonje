# Weyonje API native authentication foundation

The NestJS/Fastify API owns authentication, sessions, actor roles, Provider eligibility, and KCCA mobile-monitoring permission. Prisma is its only persistence layer. PostgreSQL stores Argon2id password hashes, AES-256-GCM encrypted normalized email payloads, separate HMAC-SHA-256 email lookup values, sessions, hashed refresh tokens, and durable login throttles. Raw passwords and tokens are never persisted.

Endpoints:

- `POST /v1/auth/sign-in`: generic non-enumerating email/password authentication and session creation.
- `POST /v1/auth/refresh`: atomic refresh-token rotation; reuse revokes the session family.
- `POST /v1/auth/sign-out`: bearer-authenticated, idempotent current-session revocation.
- `GET /v1/actors/me`: current database-backed `actorType`, `access`, and Provider `providerStatus` when applicable.

Access tokens are short-lived HS256 JWTs containing only internal user and session identifiers. Every protected request verifies algorithm, signature, issuer, audience, issue/expiry times, current server session, password version, login permission, and verification state. Roles and business eligibility are loaded from Prisma rather than trusted as token claims.

## Configure and run

1. Copy the root `.env.example` to an ignored `.env` and replace every placeholder.
2. Put Neon's pooled connection in `DATABASE_URL` and its direct connection in `DIRECT_URL`.
3. Generate each base64 secret independently. On a trusted workstation, run `openssl rand -base64 32` or the PowerShell command `[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))` separately for every key. Store output only in the ignored local file or Koyeb secret settings. `EMAIL_ENCRYPTION_KEY` must decode to exactly 32 bytes; the other keys must decode to at least 32 bytes.
4. Install with `pnpm install --frozen-lockfile` from the repository root.
5. Apply migrations with `pnpm --filter @weyonje/api migration:deploy` (Prisma uses `DIRECT_URL`).
6. Start locally with `pnpm --filter @weyonje/api start:dev`.

Startup rejects missing/malformed/placeholder connection values, insecure issuer configuration, undersized keys, secret reuse, unsafe TTL/limit values, and inconsistent production environment selection. Secrets are never generated at startup.

## Prisma and migration checks

```text
pnpm --filter @weyonje/api prisma:format
pnpm --filter @weyonje/api prisma:validate
pnpm --filter @weyonje/api prisma:generate
pnpm --filter @weyonje/api migration:status
```

`prisma/migrations/20260811130000_native_authentication/migration.sql` is the clean development-only replacement for the former un-deployed TypeORM foundation. It creates `users`, `authentication_sessions`, `refresh_tokens`, and `login_throttles`, including database constraints Prisma cannot express. Do not run it against a database containing a prior live `actor_profiles` schema or data; design a forward data-preserving migration first.

The real PostgreSQL suite is opt-in. Set both `TEST_DATABASE_URL` (isolated pooled test address) and `TEST_DIRECT_URL` (the same isolated database's direct address), then run `pnpm --filter @weyonje/api test -- postgres.integration.spec.ts`. It applies the checked-in migration and creates/deletes synthetic rows, so never point it at Neon development, production, or any shared database.

## Development-only provisioning

The command refuses `WEYONJE_ENVIRONMENT=production`, connects through `DIRECT_URL`, prompts for email, masks password input, uses the same API encryption and Argon2id services, and prints no protected values:

```text
pnpm --filter @weyonje/api provision:user -- --actor-type CLIENT --email-verified
pnpm --filter @weyonje/api provision:user -- --actor-type SERVICE_PROVIDER --provider-status APPROVED --email-verified
pnpm --filter @weyonje/api provision:user -- --actor-type KCCA_STAFF --kcca-mobile-monitoring --email-verified
```

Provider status is mandatory only for Service Providers. `--inactive` and `--login-disabled` create negative test cases. Omitting `--email-verified` creates an account that must fail sign-in generically. No default administrator or fixed credential exists.

## Koyeb Free development service

Native Koyeb Node builds support this pnpm/Node 24 monorepo; no Dockerfile is required. Create one Free Web Service from the private GitHub repository with repository working directory `/`, region Frankfurt (`fra`) when available and suitable, and:

- Build command: `pnpm install --frozen-lockfile && pnpm --filter @weyonje/contracts build && pnpm --filter @weyonje/api prisma:generate && pnpm --filter @weyonje/api build`
- Run command: `pnpm --filter @weyonje/api start`
- Port: Koyeb-supplied `PORT`; the API binds `0.0.0.0`.
- Environment: all root `.env.example` names entered privately in Koyeb settings; `NODE_ENV=production` and `WEYONJE_ENVIRONMENT=development` for this non-production service.

Use no persistent disk or worker. Durable state belongs in Neon. A Free instance sleeps after inactivity and can cold-start; Neon compute can also suspend. This environment has no production uptime guarantee. No deployment or cloud resource is created by repository commands.

Swagger UI is exposed at `/internal/docs` only when `NODE_ENV` is not production. Generate and check the committed safe contract with `pnpm openapi:generate` and `pnpm openapi:check`.

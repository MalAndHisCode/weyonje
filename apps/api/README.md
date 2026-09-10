# Weyonje API

The NestJS/Fastify API owns authentication, sessions, actor roles, Provider eligibility, Client/Provider/KCCA workflows, Call Centre permissions, journey state, feedback/follow-up, disposal control, notifications/outbox, and authenticated Socket.IO hints. Prisma/PostgreSQL is the authoritative persistence layer.

Endpoints:

- `POST /v1/auth/sign-in`: generic non-enumerating email/password authentication and session creation.
- `POST /v1/auth/refresh`: atomic refresh-token rotation; reuse revokes the session family.
- `POST /v1/auth/sign-out`: bearer-authenticated, idempotent current-session revocation.
- `GET /v1/actors/me`: current database-backed `actorType`, `access`, and Provider `providerStatus` when applicable.
- `/v1/client/*`: Client dashboard, request creation/history/detail, and feedback.
- `/v1/provider/*`: marketplace, atomic acceptance/rejection, jobs, journeys, positions, collection, and disposal.
- `/v1/call-centre/*`: separately permissioned Call Centre request/assignment/feedback ingress.
- `/v1/kcca/*`: permitted monitoring and KCCA-controlled disposal-site catalogue/assignment.
- `/v1/journeys/*`, `/v1/notifications/*`, and Socket.IO namespace `/journeys`: authorised reconciliation and durable notification access.
- `/v1/account-security/*`: non-enumerating password recovery and email verification.
- `/v1/provider-registrations/*`: Provider review, administration status and immutable history.
- `/v1/notification-devices/*`: authenticated FCM installation lifecycle.
- `/v1/maps/*`: authenticated Places, reverse-geocoding and Routes proxy using a server-only key.
- `/v1/kcca/delivery/health`: permission-protected delivery backlog health.

Access tokens are short-lived HS256 JWTs containing only internal user and session identifiers. Every protected request verifies algorithm, signature, issuer, audience, issue/expiry times, current server session, password version, login permission, and verification state. Roles and business eligibility are loaded from Prisma rather than trusted as token claims.

## Configure and run

1. Copy the root `.env.example` to an ignored `.env` and replace every placeholder.
2. Put Neon's pooled connection in `DATABASE_URL` and its direct connection in `DIRECT_URL`.
3. Generate each base64 secret independently. On a trusted workstation, run `openssl rand -base64 32` or the PowerShell command `[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))` separately for every key. Store output only in the ignored local file or Railway Variables. `EMAIL_ENCRYPTION_KEY` must decode to exactly 32 bytes; the other keys must decode to at least 32 bytes.
4. Install with `pnpm install --frozen-lockfile` from the repository root.
5. Apply migrations with `pnpm --filter @weyonje/api migration:deploy` (Prisma uses `DIRECT_URL`).
6. Start locally with `pnpm --filter @weyonje/api start:dev`.

Startup rejects missing/malformed/placeholder connection values, insecure issuer configuration, undersized keys, secret reuse, unsafe TTL/limit values, and inconsistent production environment selection. Secrets are never generated at startup.

`SMS_PROVIDER=FAKE` is the default outside `WEYONJE_ENVIRONMENT=production`. It returns the generated one-time code in the development-only challenge field so the mobile verification screen can display and prefill it without an external SMS account. The fake is prohibited in the Weyonje production environment. Use `SMS_PROVIDER=AFRICAS_TALKING` only after the corresponding credentials and non-production resources have been authorised and configured; that adapter never returns the code in an API response.

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
pnpm --filter @weyonje/api provision:user -- --actor-type KCCA_STAFF --kcca-mobile-monitoring --call-centre-operations --email-verified
```

Provider status is mandatory only for Service Providers. `--inactive` and `--login-disabled` create negative test cases. Omitting `--email-verified` creates an account that must fail sign-in generically. No default administrator or fixed credential exists.

## Railway GitHub deployment

The Railway service is user-confirmed as connected directly to GitHub and rooted at the repository root. The repository supports a native pnpm/Node 24 build; no Dockerfile is required. Configure the root service with:

- Build command: `pnpm install --frozen-lockfile && pnpm --filter @weyonje/contracts build && pnpm --filter @weyonje/api prisma:generate && pnpm --filter @weyonje/api build`
- Run command: `pnpm --filter @weyonje/api start`
- Port: Railway-supplied `PORT`; the API binds `0.0.0.0`.
- Environment: all root `.env.example` names entered privately in Railway Variables; use `NODE_ENV=production` and set `WEYONJE_ENVIRONMENT` to the actual environment classification.

Use no persistent disk. Durable state belongs in PostgreSQL. Production delivery uses a separate Railway service built from the same repository and variables with run command `pnpm --filter @weyonje/api start:worker`. The worker claims PostgreSQL outbox events with leases/skip-locked rows, retries with bounded backoff, records attempts, dead-letters permanent failures, recovers expired claims, and cleans terminal history according to retention configuration. Run it locally with `pnpm --filter @weyonje/api start:worker:dev`. Do not run an additional in-process production worker or add Valkey/BullMQ.

Creating the Railway worker, applying migrations, and setting private Maps/Firebase variables are external operations and were not performed. Deploy migrations before starting code that writes the new models, then start one worker and inspect `/v1/kcca/delivery/health`; scale only after the isolated competing-worker test and capacity checks pass.

## Maps, push, reminders, and account security

- `GOOGLE_MAPS_SERVER_API_KEY` is server-only. Restrict it to the authorised APIs and Railway egress policy; do not place it in Flutter.
- `FCM_PROVIDER=FAKE` is development-only. `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY` are required only for `FCM_PROVIDER=FIREBASE` and must be private Railway variables.
- `EMAIL_PROVIDER=FAKE` supports local recovery/verification capture without sending email. No live email provider has been selected.
- `REMINDER_OFFSETS_MINUTES` is a validated comma-separated provisional schedule. ASAP requests create no reminders.
- Account challenge and delivery lease/backoff/retention settings are listed in the root `.env.example`.

Swagger UI is exposed at `/internal/docs` only when `NODE_ENV` is not production. Generate and check the committed safe contract with `pnpm openapi:generate` and `pnpm openapi:check`.

## Phone OTP delivery and recovery

See [phone verification setup](../../docs/PHONE_VERIFICATION_SETUP.md) for the existing native endpoint flows, provider-neutral message composition, Africa's Talking acceptance validation, SMS_ANDROID_APP_HASH, transaction/recovery limits and isolated/live test requirements. OTP delivery remains on SmsGateway; operational messaging is unchanged.

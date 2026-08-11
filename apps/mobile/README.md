# Weyonje mobile authentication entry

The Android application implements guarded launch/session resolution, unchanged `AUTH-001`, bounded `AUTH-002`, and native `AUTH-003` email/password sign-in. It stores one validated JSON credential record in encrypted platform storage, calls `GET /v1/actors/me`, rotates credentials once through `POST /v1/auth/refresh` after expiry or an authentication `401`, coalesces concurrent refreshes, and routes only after current API eligibility is known.

The sign-in page has persistent Email address and Password labels, obscures the password, uses explicit keyboard/focus order, prevents duplicate submissions, and contains no browser, identity-provider, OIDC, or PKCE handoff. The API remains authoritative; GoRouter guards prevent protected-content flash but are not authorization controls.

## Compile-time configuration

Copy `config/auth.example.json` to ignored `config/auth.local.json` and replace `WEYONJE_API_BASE_URL` with the HTTPS Koyeb development API URL:

```text
flutter run --dart-define-from-file=config/auth.local.json
```

Do not place API secrets, database addresses, signing keys, encryption keys, email lookup keys, refresh-token hash keys, or user credentials in mobile configuration.

## Session behaviour

- Successful sign-in stores only access token, rotating refresh token, and their expiries.
- Temporary connectivity failures preserve potentially recoverable credentials and expose retry.
- Invalid/revoked sessions and unrecoverable refresh failures clear local credentials.
- Sign-out asks the API to revoke the current session, then clears local credentials even if the network call fails. A failed network revocation can leave the server session active until later revocation or absolute expiry.
- Lifecycle resume revalidates server authority; obsolete launch/sign-in requests are cancelled.

## Scope boundary

Registration forms, forgot-password/password-reset UI, verification delivery, Provider approval, KCCA self-registration, and role dashboards are not implemented. Successful eligibility reaches role-specific unavailable boundaries that load no protected workflow data.

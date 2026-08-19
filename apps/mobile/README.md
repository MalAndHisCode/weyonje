# Weyonje mobile application

The Android application implements guarded native authentication/registration plus API-backed Client, approved Provider, and permitted KCCA workflows. It stores one validated credential record in encrypted platform storage, resolves current server eligibility, and exposes only role-authorised routes.

The sign-in page has persistent Email address and Password labels, obscures the password, uses explicit keyboard/focus order, prevents duplicate submissions, and contains no browser, identity-provider, OIDC, or PKCE handoff. The API remains authoritative; GoRouter guards prevent protected-content flash but are not authorization controls.

## Compile-time configuration

Copy `config/auth.example.json` to ignored `config/auth.local.json` and replace `WEYONJE_API_BASE_URL` with the HTTPS Railway API URL:

```text
flutter run --dart-define-from-file=config/auth.local.json
```

`WEYONJE_GOOGLE_MAPS_ENABLED` defaults to false. Enabling the flag does not bundle credentials or make Maps production-ready; an authorised Google project/SDK configuration is still required. Do not place API secrets, database addresses, signing/encryption keys, provider credentials, or user credentials in mobile configuration.

## Session behaviour

- Successful sign-in stores only access token, rotating refresh token, and their expiries.
- Temporary connectivity failures preserve potentially recoverable credentials and expose retry.
- Invalid/revoked sessions and unrecoverable refresh failures clear local credentials.
- Sign-out asks the API to revoke the current session, then clears local credentials even if the network call fails. A failed network revocation can leave the server session active until later revocation or absolute expiry.
- Lifecycle resume revalidates server authority; obsolete launch/sign-in requests are cancelled.

## Operational flows

- Clients can create ASAP or scheduled requests, view history/details, track journeys, and submit 1–5 collection feedback.
- Approved active Providers can see eligible marketplace requests with minimal pre-acceptance information, atomically accept work, manage jobs, report collection, and complete KCCA-assigned disposal.
- Permitted KCCA users have read-only monitoring and notifications; Call Centre/disposal administration remains API-only.
- Location values come from a provisional API policy. Google Maps is an explicit unconfigured adapter state; device/coordinate fallback is available for development.
- Socket.IO supplies authenticated update hints only. Screens always reconcile authoritative journey state through REST.

Password recovery, KCCA Provider-review UI, production push/SMS dispatch, durable background tracking, and release operations are not implemented.

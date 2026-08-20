# Weyonje mobile application

The Android application implements guarded native authentication/registration plus API-backed Client, approved Provider, and permitted KCCA workflows. It stores one validated credential record in encrypted platform storage, resolves current server eligibility, and exposes only role-authorised routes.

The sign-in page has persistent Email address and Password labels, obscures the password, uses explicit keyboard/focus order, prevents duplicate submissions, and contains no browser, identity-provider, OIDC, or PKCE handoff. The API remains authoritative; GoRouter guards prevent protected-content flash but are not authorization controls.

## Compile-time configuration

Copy `config/auth.example.json` to ignored `config/auth.local.json` and replace `WEYONJE_API_BASE_URL` with the HTTPS Railway API URL:

```text
flutter run --dart-define-from-file=config/auth.local.json
```

`WEYONJE_GOOGLE_MAPS_ENABLED` and `WEYONJE_FCM_ENABLED` default to false. Set them only in an authorised non-production build. Supply the Android Maps SDK key as Gradle property `WEYONJE_GOOGLE_MAPS_ANDROID_KEY`; it is injected into the manifest and must be restricted to package `ug.go.kcca.weyonje.weyonje` plus the exact signing certificate. Places, geocoding, and Routes use the API's separate server credential. Never place that server key, Firebase service credentials, database addresses, encryption keys, or user credentials in mobile configuration.

## Session behaviour

- Successful sign-in stores only access token, rotating refresh token, and their expiries.
- Temporary connectivity failures preserve potentially recoverable credentials and expose retry.
- Invalid/revoked sessions and unrecoverable refresh failures clear local credentials.
- Sign-out asks the API to revoke the current session, then clears local credentials even if the network call fails. A failed network revocation can leave the server session active until later revocation or absolute expiry.
- Lifecycle resume revalidates server authority; obsolete launch/sign-in requests are cancelled.

## Operational flows

- When the API uses its guarded development fake SMS provider, the phone-verification screen displays and prefills the generated one-time code. No Africa's Talking account is required. The API prohibits this response field in the Weyonje production environment.
- Clients can create ASAP or scheduled requests, view history/details, track journeys, and submit 1–5 collection feedback.
- Approved active Providers can see eligible marketplace requests with minimal pre-acceptance information, atomically accept work, manage jobs, report collection, and complete KCCA-assigned disposal.
- KCCA routes expose monitoring, Provider review/status administration, manual Call Centre request entry, and disposal-site administration only when the matching server permission is present.
- Google Maps renders location selection and live journey markers when configured; address/coordinate and device-location fallbacks remain available. Search/reverse geocoding use authenticated API adapters.
- Active Provider journeys use an Android foreground service and persistent disclosure. The coordinator restores an authorised active session, keeps a 200-sample/24-hour encrypted offline queue, uploads chronologically with stable sample IDs, and clears on completion/logout/lost eligibility. Android force-stop survival is not claimed.
- FCM requests permission after authentication when enabled, registers/rotates/removes an installation token, and treats notification opens only as hints to reconcile `/v1/notifications`.
- Socket.IO supplies authenticated update hints only. Screens always reconcile authoritative journey state through REST.

Password recovery and email-verification mobile flows use guarded fake delivery until live providers are authorised. Google Maps, FCM and background execution are repository-integrated but remain unverified on a credentialed physical device. Release signing and store operations are not implemented.

## Live validation

For Maps, enable Maps SDK for Android, Places API (New), Geocoding API and Routes API; set quota budgets/alerts; use separate restricted Android/server keys; then test map load, tap/search/reverse/route plus invalid-key, quota, offline and timeout fallbacks. For FCM, provide the authorised Android Firebase configuration outside source control, enable the flag, and verify token rotation, logout removal, invalid-token cleanup, foreground/background/terminated opens and expired-session routing on a physical device. Test foreground tracking across backgrounding, recent-app removal, process restart, disabled GPS, permission denial and battery restrictions; do not describe force-stop as supported.

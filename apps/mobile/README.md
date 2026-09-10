# Weyonje mobile application

The Android application implements guarded native authentication/registration plus API-backed Client, approved Provider, and permitted KCCA workflows. It stores one validated credential record in encrypted platform storage, resolves current server eligibility, and exposes only role-authorised routes.

The sign-in page has persistent Email address and Password labels, obscures the password, uses explicit keyboard/focus order, prevents duplicate submissions, and contains no browser, identity-provider, OIDC, or PKCE handoff. The API remains authoritative; GoRouter guards prevent protected-content flash but are not authorization controls.

## Mobile Identity and UI Conventions

The Android display name is **Weyonje**. Application ID and namespace remain `ug.go.kcca.weyonje.weyonje`. The welcome screen contains Create Account, Client Sign In, Provider Sign In, and KCCA Sign In, in that order. The three sign-in actions use the same secondary emphasis. Provider and KCCA use `/sign-in?entry=provider` and `/sign-in?entry=kcca`; `/sign-in` and unknown context retain the generic form. Entry context changes presentation only. Authentication, eligibility and permissions come from the existing native API; cross-role credentials follow server authority. Back from recovery returns to the selected entry; direct-link back falls back safely to welcome.

Use Forui 0.25.0 (the lockfile version), the central `lib/theme/` configuration and `lib/ui/` wrappers for standard mobile UI. Text/select/button constraints and radio/switch padding explicitly enforce at least 48 dp touch sizing, with responsive labels and scrollable forms/dialogs. Keep native date/time pickers, maps and platform interfaces. Existing Forui-bundled Inter/Lucide and light-only application behavior are retained; no dependencies were added or upgraded. Authored headings and button labels use conventional Title Case. Field labels, body text and user/API content keep their existing capitalization.

## Regenerate Android Launcher Resources

From `apps/mobile`, run `python tool/generate_launcher_icons.py` using Python 3 and Pillow (local build tooling only). The generator reads `assets/branding/weyonje-logo.png` without modifying it. The source is RGBA, 554 × 554; nonzero alpha bounds are `(41, 203, 513, 351)`, containing the complete 472 × 148 artwork. Derivatives trim only empty transparent padding and preserve aspect ratio and all visible logo elements.

The script generates 48 dp legacy square/round icons and 108 dp adaptive foreground layers at mdpi through xxxhdpi, plus API 26 adaptive XML. Legacy artwork uses 80% of the icon width on white. Adaptive artwork is 60 dp wide; its approximately 62.9 dp bounding diagonal fits inside the 66 dp safe circle. Both adaptive backgrounds are white. The optional monochrome themed-icon layer is deliberately absent because no recoloured mark is authorized. The tagline is retained but may be illegible at small launcher sizes. Splash resources are unchanged.

Validation commands: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, `flutter test --no-pub`, and `flutter build apk --debug --no-pub`. Visual tests load the fonts already bundled with the application, use fake authentication/workflow data and mock secure storage, and cover compact/large phones, landscape, enlarged text, keyboard, loading/error states and representative role dashboards. Use `flutter test --no-pub test/visual/auth_visual_test.dart --update-goldens` only for intentional changes, then inspect the resulting PNGs before accepting them.

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

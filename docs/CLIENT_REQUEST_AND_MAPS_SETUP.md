# Client Request Form and Google Maps Setup

Last verified: 2026-09-11. Repository implementation and deterministic tests are separate from deployment and device evidence.

## Implemented behavior

The compatible `/client/requests/new` route displays **Request for a Service**. Its sections are Client Details, Location Details, Service Details, and Additional Contact Details, followed by Submit Request. `GET /v1/client/profile` returns only `clientName`, `phoneNumber`, and optional `emailAddress` for the authenticated active Client. Individual names join first/last names; Organization names use the organization name. No displayed profile data is submitted as authoritative identity. The creation service reads encrypted contacts and the Client profile again.

The foreground-only location gateway checks services and permission on entry, resume, and immediately before submission. Disabled services, denied permission, permanent denial, and acquisition timeout have separate recovery messages. Settings return keeps the mounted form. Yes takes one position and disables manual selection; explicit refresh replaces it. No allows map selection and requires confirmation, with the compatible full-screen picker available for its existing search/coordinate accessibility controls. Mode changes clear the selection/address; generation checks ignore obsolete GPS and reverse-geocoding responses. Camera movement does not geocode. Missing addresses are honestly reported and valid coordinates remain usable. Address text stays in memory and is not sent as Google-derived persistent request content.

Client ingress requires a supported toilet type in both the endpoint DTO and service; Call Centre DTOs and historical nullable records remain unchanged. The form sends `ASAP` without `requestedServiceAt`; scheduled API/record/reminder support is preserved. Additional name/phone remain a pair. The existing server PhoneSecurityService normalizes and validates Ugandan numbers, with its invalid-phone message reflected at the form field.

Repeated taps are guarded. An unchanged submission keeps its UUID across retries. A definite rejection permits editing and a changed payload receives a new UUID. An ambiguous response locks payload edits and permits retry of the same UUID or opening My Requests to reconcile; it does not silently create a new request. Drafts remain in the mounted page only; process-death restoration is not implemented.

## Resume diagnosis and correction

Previously `revalidateOnResume()` called `_check()`, which emitted `LaunchChecking`; GoRouter redirected to `/launch`, disposed the request page, and then selected the dashboard after validation. The router itself was already stable. Background checks now retain `LaunchAuthenticated` while resolving the stored session; transient/rate-limit failures retain it. Invalid, revoked, denied, and missing sessions still reach safe auth/access routes. Restricted Provider status redirects immediately to account status. Checks remain coalesced. Controller generations, cancellation, and repository session generations prevent stale checks/refresh writes from replacing a newer session or resurrecting logout.

## Configuration boundaries

| Setting | Location | Purpose / current local evidence |
| --- | --- | --- |
| `WEYONJE_API_BASE_URL` | Ignored `apps/mobile/config/auth.local.json` | Existing Railway API target; unchanged |
| `WEYONJE_GOOGLE_MAPS_ENABLED` | Mobile Dart define JSON | Enabled in ignored local configuration; example defaults false |
| `WEYONJE_GOOGLE_MAPS_ANDROID_KEY` | Gradle project property, e.g. private user Gradle properties | Existing manifest placeholder; restricted debug key privately installed in user Gradle properties |
| `GOOGLE_MAPS_SERVER_API_KEY` | API environment | Blank locally; keep only on server, independently configure Railway |
| `GOOGLE_MAPS_TIMEOUT_MILLISECONDS` | API environment | Existing default/example 8000 |

No dependency, database schema, migration, package identity, or signing setting changed. `MapsModule` continues importing `AuthModule`; adapters remain authenticated. No background permission or Provider foreground service is started for Client request entry.

## External setup audit

The user confirmed **weyonje-dev (Weyonje-Development)** as the development project. The initially open My First Project was rejected and left unchanged. The intended project initially had no API keys. Maps onboarding created a key, now named **Weyonje Android Debug**. Its saved restriction inventory confirms **Android apps, 1 API**: the exact package/debug SHA-1 below and Maps SDK for Android only. The four required APIs were individually enabled and verified: Maps SDK for Android, Geocoding API, Places API (New), and Routes API. The restricted Android key was subsequently installed privately into user Gradle properties at the user's request. Its value is absent from source, documentation and conversation output. The standard SDK necessarily packages this Android credential in the manifest; package/certificate/API restrictions remain essential.

The console shows an active free trial expiring December 11, 2026 and a linked Cloud Billing reports page. Trial/billing settings were untouched. Geocoding quota inspection showed requests/day Unlimited and requests/minute 3000, with zero current usage. Both were marked Adjustable No; Edit quota and Create usage alert were disabled in the inspected UI. No custom spending cap or alert was configured, and no quota was raised. Billing visibility and API enablement do not prove successful live API access.

Railway inspection was read-only: weyonje-api is Sleeping on the Trial plan, in an environment named production. Its settings warn that the configured ams region is invalid and blocks deployments. No region, variable, plan, or deployment was changed. Railway's [static outbound IP documentation](https://docs.railway.com/networking/static-outbound-ips) requires Pro and a redeploy. Consequently, no unrestricted server key was created as a workaround.

Remaining actions:

1. **Completed:** Installed the restricted Android key privately via the existing Gradle property, enabled the ignored local mobile Maps flag, rebuilt the APK and verified its manifest key matches without printing it. The user will install and test this APK on their own phone.
2. Approve an appropriate fixed-egress hosting arrangement before creating a separate server credential restricted to Geocoding API, Places API (New), Routes API and the actual outbound IPs. A Railway Pro purchase is not authorized. A Railway hostname is not an egress IP restriction.
3. Approve the production-named service's region correction and API deployment explicitly. Configure GOOGLE_MAPS_SERVER_API_KEY privately in the authorized API environment; local configuration does not update Railway. Deploy the new profile endpoint and Client DTO before using the rebuilt form against that backend.
4. An account administrator should review available quotas/usage alerts and establish an approved cost-control policy. Do not link billing, raise paid quotas, purchase services, or deactivate the trial as part of this task.
5. Connect an authorized Android device and verify native tiles/attribution, both permission modes and settings recovery, actual GPS and confirmed map selection, address failures, and warm display-off/on. Test process death separately; durable draft restoration is not implemented.

Verified local **debug** identity (public certificate, not a production identity):

- Package: `ug.go.kcca.weyonje.weyonje`.
- SHA-1: `82:63:D6:53:D3:C7:C3:AF:8D:C4:A1:D9:00:06:B2:C1:B0:62:F2:C8`.
- Existing release configuration still uses debug signing. Production signing remains outside this task and requires the actual future app-signing certificate.

Google's [security guidance](https://developers.google.com/maps/api-security-best-practices) specifies package/SHA-1 restrictions for Android and IP restrictions for server keys. [Geocoding usage and billing](https://developers.google.com/maps/documentation/geocoding/usage-and-billing) describes API/billing prerequisites and quota controls. Preserve attribution and follow [Geocoding policies](https://developers.google.com/maps/documentation/geocoding/policies), including storage restrictions. Budget alerts are not a spending cap. Never deactivate the Maps trial.

## Verification stages and limitations

- **Configured:** Development Google APIs and restricted Android debug credential are ready. Private local Android key installation and Maps-enabled APK build are complete. Server credential/fixed egress remain deferred.
- **Locally tested:** Deterministic API, form, lifecycle and rendering tests; see CURRENT_SYSTEM_STATE.md for final command results.
- **Deployed:** Not deployed by this task. The new profile endpoint requires the updated API before the redesigned app can submit successfully.
- **Verified on-device:** Not verified. `adb devices` found no connected device. The debug APK is a build artifact, not installation or Maps evidence.

Map rendering has an initialization indicator/timeout and a reload control. The Flutter SDK's map-created callback confirms platform-view creation, not successful Google tile authorization; blank tiles/key/quota errors still need physical-device validation. Golden tests use a visibly labeled deterministic map surface and do not claim to render Google tiles. No live paid Maps requests, new billing linkage, deployment, secret rotation, persistent Google-address cache, or database operation was performed.

## No-extra-expense follow-up — 2026-09-11

The user declined Railway Pro and requested the remaining Android map setup. No paid plan, billing setting, backend variable or deployment was changed. Ordinary native Maps SDK usage is listed with unlimited free usage in [Google pricing](https://developers.google.com/maps/billing-and-pricing/pricing); the current widget supplies no cloud map ID and uses no Street View. Server geocoding/Places/Routes remain unconfigured and no unrestricted server credential was introduced. Coordinate selection remains usable despite address failure under the implemented API rules.

The Maps-enabled APK build passed with the existing plugin KGP warning. SHA-256: 244E9252B62A93AB02C0AC00E3101E6E31FE1ABEAE7FE7C55244DE800BCEDED7. Packaged manifest credential was compared to private Gradle configuration without logging its value. Source code was unchanged in this follow-up; preceding analysis/tests remain the code-validation evidence. No phone was connected; the user elected to test the APK themselves. An existing emulator was briefly started, but no app was installed or map-rendering result claimed. The new profile endpoint still requires separately approved backend deployment for complete request submission.

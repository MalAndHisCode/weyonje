# Weyonje mobile authentication entry

The Android application implements:

- a guarded launch state with no protected-content flash;
- `AUTH-001` welcome and account access;
- `AUTH-002` Client or Service Provider selection, followed by an explicit no-data-collected boundary because registration is out of scope;
- `AUTH-003` system-browser sign-in through Keycloak Authorization Code Flow with PKCE;
- encrypted platform storage for the minimum session material;
- one refresh attempt after an API `401`, safe local invalidation for unrecoverable sessions, and session preservation for transient failures; and
- authoritative role/eligibility routing from `GET /v1/actors/me`.

## Compile-time configuration

Copy `config/auth.example.json` to ignored `config/auth.local.json` and replace:

- `WEYONJE_API_BASE_URL`
- `WEYONJE_KEYCLOAK_ISSUER`
- `WEYONJE_KEYCLOAK_CLIENT_ID`
- `WEYONJE_AUTH_REDIRECT_URI`

Run with:

```text
flutter run --dart-define-from-file=config/auth.local.json
```

The API and issuer must use HTTPS. The redirect URI must use a dedicated custom scheme and exactly match a Keycloak allow-list entry. The public mobile client must have no embedded secret and must require PKCE `S256`.

The default Android scheme is `ug.go.kcca.weyonje.auth`, corresponding to `ug.go.kcca.weyonje.auth:/oauthredirect`. If an approved environment uses another scheme, update the Android Gradle property `WEYONJE_AUTH_REDIRECT_SCHEME` and the Dart redirect URI together.

## Scope boundary

No native password fields, registration forms, KCCA self-registration, provider approval workflow, or role dashboard is implemented. Successful identity and access checks reach role-specific screens that explicitly identify unavailable downstream functionality and load no protected feature data.

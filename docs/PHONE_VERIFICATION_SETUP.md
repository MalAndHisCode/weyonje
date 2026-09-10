# Phone verification and SMS testing

Client registration and Client code sign-in use the existing native endpoints and shared verification screen. Forui 0.25.0 renders one editable six-digit value as six boxes. Manual entry, paste and Android candidates use the same guarded server request. A complete unchanged value submits once; errors reset when edited, and a network retry requires an explicit action. Server-confirmed success is green for 650 ms before existing actor routing. The transition and pending requests are cancelled when leaving.

## OTP input correction — 2026-09-10

**Implemented:** The shared verification screen previously copied the fake-provider response's development code into its Forui controller on entry and resend, then automatically verified it. Both fill paths and the hint are removed. The mobile phone model ignores legacy extra data, including malformed development-code fields. PhoneChallengeService, its DTO, shared contract and generated OpenAPI no longer expose the OTP for any provider. Provider registration shares this protection; unrelated account-recovery/email-verification contracts remain unchanged. Tests capture codes only in injected gateways.

A new challenge remains empty unless a matching SMS was buffered during its request. Allowed input is deliberate typing/paste, supported platform OTP autofill or a generation/challenge-matched SMS Retriever event. Consumed SMS candidates are remembered only within the current retrieval generation so duplicate delivery cannot overwrite later manual edits; start/stop clears them. Automatic six-digit submission and the guarded 650 ms server-success transition remain. Fake delivery and provider SENT status cannot populate input or imply handset receipt.

## Server configuration

Store credentials only in the ignored root `.env` or an approved server secret store. The API now explicitly resolves this root file from source and compiled layouts; process variables retain precedence. Previously Nest used the process working directory, so the documented pnpm command from `apps/api` missed the root file. The general environment whitelist now retains the SMS keys for validation by the existing smsConfig factory; previously file-loaded keys were discarded and provider selection reverted to FAKE. Process/Railway variables were not subject to that file-loading loss. No new environment framework is introduced. Do not put provider keys in Flutter defines, an APK, examples, screenshots, logs or chat. The application uses an API key, never the dashboard password.

| Variable | Behavior |
| --- | --- |
| `SMS_PROVIDER` | `FAKE` by default outside production; `AFRICAS_TALKING` selects the implemented real adapter. Unknown values fail startup; production must select a real adapter. |
| `AFRICASTALKING_API_BASE_URL` | Required for the real adapter; exactly `https://api.sandbox.africastalking.com` or `https://api.africastalking.com`. |
| `AFRICASTALKING_USERNAME` | Required real-adapter application username. Sandbox uses `sandbox`; live uses the application's username, not an account email. |
| `AFRICASTALKING_API_KEY` | Required API key for that application and environment; keep private. |
| `AFRICASTALKING_SENDER_ID` | Optional. Leave blank to omit `from` and use the provider default sender on supported routes. Only set a custom name when approved and mapped to the app. |
| `SMS_ANDROID_APP_HASH` | New optional server-only 11-character base64 hash derived from the actual APK signing certificate and unchanged package ID. Without it, manual/keyboard autofill still works but SMS Retriever cannot match the SMS. One signing identity per API environment. |
| `OTP_TTL_SECONDS` | Default 600, validated 300–1800. Included in SMS instead of a hard-coded expiry. |
| `OTP_RESEND_SECONDS` | Default 60, validated 30–300. Applies to initial/repeated requests and resend. |
| `OTP_MAX_ATTEMPTS` | Default 5, validated 3–10. Incorrect attempts persist; exhausted challenges cannot be consumed. |
| `OTP_MAX_REQUESTS_PER_HOUR` | Default 5, validated 2–20 per protected phone/purpose. |

The adapter sends one form-encoded request to `/version1/messaging`, with the API key in a header. It accepts only a single matching recipient, nonempty message ID and status 100/101/102. HTTP 2xx alone is insufficient. `SENT` in the existing contract means provider acceptance, not confirmed handset delivery. `FAILED` means acceptance was not confirmed (including rejection, malformed response or ambiguous timeout); it is not proof that the handset will never receive a delayed SMS. There is no automatic retry after timeout. The retained challenge offers an explicit cooldown-controlled resend that supersedes the previous code.

OTP message composition is provider-neutral in `otp-message.ts`. It contains the digits, configured expiry, a challenge UUID reference and optional trusted app hash; UTF-8 size is checked against 140 bytes. Each additional provider requires its own `SmsGateway` adapter plus an explicit factory/config registration. Switching between the implemented fake and Africa's Talking adapters requires configuration only. Operational outbox messaging is unchanged.

### Effective environment audit — 2026-09-10

The ignored root configuration passes the existing smsConfig validator and selects AFRICAS_TALKING, the live origin, present username/key, blank optional sender and a configured debug app hash. No credential or environment-variable value was changed for the OTP correction. The old traceability claim about invalid local username settings is historical and superseded by this audit. No provider request was made.

The ignored mobile auth.local.json selects development and https://weyonje-api-production.up.railway.app; the repository always wires NativeAuthRepository. The new debug APK explicitly uses that file. A filename or environment label does not establish Railway's server classification or resolved SMS provider. Railway variables/process state and any previously installed APK are **Unknown** here; local .env edits cannot change them. No device is attached, and no authorized Railway management connection is available in this task. An operator must verify the target service's SMS_PROVIDER and matching endpoint/credentials privately before device testing, and deploy the reviewed server change separately.

The existing local live configuration is preserved, not switched to sandbox or newly enabled for paid testing. Sandbox testing requires its existing sandbox credentials, username sandbox and sandbox origin on the API actually targeted by the APK. A simulator message is not handset receipt: copy/paste its code deliberately, or the page stays waiting. No simulator polling, synthetic runtime event or chargeable send is needed to validate this correction.

## Android signing and retrieval

The only new dependency is Google's first-party `com.google.android.gms:play-services-auth-api-phone:18.3.1`, pinned in the app Gradle file. No Flutter package, second design system, SMS inbox permission or accessibility service was added. The dynamic receiver is protected with Google's `SEND_PERMISSION` (a receiver sender check, not an app SMS-reading permission). Native code extracts only the expected message structure and passes digits plus challenge reference through `weyonje/sms_retriever`. Dart buffers up to four transient candidates until the challenge response arrives, ignores obsolete references, and clears them when stopped. A new request starts retrieval before calling the API, including resend. Missing Play services, unsupported platforms and retrieval timeout retain manual entry.

Package/application ID remains `ug.go.kcca.weyonje.weyonje`. Export the PUBLIC certificate for the APK being tested, then run from `apps/mobile`:

```powershell
node tool/sms_app_hash.cjs public-signing-certificate.der
```

The helper validates DER as an X.509 certificate and follows Google's package-name/hex-certificate/SHA-256/base64 algorithm. Export a certificate with `keytool -exportcert -keystore <keystore-path> -alias <alias> -file <public-certificate.der>` and enter any required keystore password interactively. For Play-distributed builds, use the Play app-signing certificate, not the upload certificate. Never invent a release certificate or compute an arbitrary client hash for server use.

Local debug certificate verified 2026-09-10: hash `iRKzuOXzxKg`. This is public build identity, not a credential. Another developer's debug keystore generally produces a different hash. Set this only on the non-production API that serves this exact debug build. Existing release Gradle configuration still signs with the debug key; production release signing is **Not Implemented** and was not changed. A future properly signed release needs its own derived hash and separate server environment configuration. Do not mix debug and production trust identities.

## Recovery and transaction limits

- Repeating Client registration for the same unverified phone resumes the original pending Client without overwriting profile data or creating another user. If the previous request was interrupted, wait for the cooldown before submitting again. Existing verified identifiers still require sign-in. Provider registration fields and password access are preserved.
- Issuance serializes each protected phone/purpose with a PostgreSQL transaction advisory lock before checking hourly count, latest cooldown, supersession and creation. SMS I/O occurs after the transaction.
- Correct-code consumption uses an atomic conditional update checking one-time use, remaining attempts, expiry and delivery status. Registration activation, Client number assignment/Provider review notification, session/refresh-hash creation and access-token signing happen within the same completion transaction. Failure rolls them back. Incorrect-code decrements occur outside that completion transaction and are not rolled back by authentication rejection.
- If commit succeeds but the HTTP response is lost, the code stays consumed. Return to Client Sign In and request a fresh code; Provider users use their existing password sign-in. No raw session or replayable OTP response is persisted server-side to simulate exactly-once delivery.
- If credentials reach secure storage but actor resolution is interrupted, the existing session-error/retry flow resolves the stored session without replaying the OTP. A local secure-storage failure requires a fresh sign-in if retry cannot recover. Process death before receiving/saving credentials uses the same fresh sign-in recovery.
- Database atomicity and advisory-lock behavior require isolated PostgreSQL verification. No shared/test migrations were applied during this task when isolated URLs were absent.

## Africa's Talking account setup and bounded handset test

As of 2026-09-10, the live Weyonje app (username weyonje) has a user-generated API key stored in the ignored root .env. A single authorized connection-test SMS was accepted by the live messaging endpoint (HTTP 201, recipient status 100), cost UGX 27, and the user supplied a dashboard record showing Sent from AFRICASTKNG. The app has no registered alphanumeric sender. The successful request omitted from; custom sender registration is therefore not required for this observed route. This is live provider evidence, not a sandbox simulator test or proof of handset autofill.

Local configuration now selects AFRICAS_TALKING with the live endpoint, blank sender ID, and the existing debug APK hash. Both registration and Client phone sign-in use the shared PhoneChallengeService and SMS adapter. No deployed server settings were changed. Restart the local API to load configuration; a deployed API needs the equivalent server-only settings. Do not use the account-data endpoint's 401 response as a gate for SMS readiness: that check returned 401 while the same key successfully sent the test SMS.

Sandbox remains a separate setup: sandbox endpoint, username sandbox, and its own API key; messages appear in the simulator. No additional chargeable SMS was sent during the integration follow-up. Registration/sign-in behavior is covered by automated tests; live end-to-end account verification and physical SMS Retriever remain unverified.

Before any handset send, obtain the authorized recipient and a bounded allowance (for example, at most four messages covering registration, sign-in and optional resend/manual fallback), plus a funded application with a supported sender route, server-only credentials and connected authorized Android device. No device was connected in this task (`adb devices -l`). Then:

1. Configure a non-production API with the live provider credentials and matching debug hash, without changing production services.
2. Install the debug APK without clearing user data; point it at that non-production API.
3. Start Client registration and separately record provider acceptance, handset receipt, correct-reference autofill, server verification and Client routing.
4. Request Client sign-in and record the same evidence separately. Exercise manual entry/paste with retrieval unavailable and resend only within the agreed allowance.
5. Check a wrong code and old/superseded code through fake or controlled tests without extra chargeable sends. Record failures truthfully; stop at the allowance.

Only the single live connection-test acceptance and dashboard Sent record above were observed. No sandbox send, confirmed handset receipt, physical autofill or live registration/sign-in verification was performed. Synthetic widget/platform-boundary tests are not device evidence.

## Official references checked 2026-09-10

- [Google SMS Retriever overview](https://developers.google.com/identity/sms-retriever/overview) and [server verification/hash requirements](https://developers.google.com/identity/sms-retriever/verify).
- [Google Android SMS Retriever integration](https://developer.android.com/identity/sms-retriever) and [current Play services dependency](https://developers.google.com/android/guides/setup).
- [Africa's Talking official SMS SDK](https://github.com/AfricasTalkingLtd/africastalking-node.js/blob/master/lib/sms.js), [recipient acceptance versus delivery reports](https://help.africastalking.com/en/articles/16150386-messaging-error-codes), [sandbox versus live delivery](https://help.africastalking.com/en/articles/2189460-what-are-the-sandbox-and-the-live-environments), and [Uganda sender setup](https://help.africastalking.com/en/articles/407085-how-do-i-set-up-my-sender-id-in-kenya-or-uganda).

## Correction validation and changed files

The final correction passes 120 Flutter tests, Flutter analysis/formatting, 131 API tests (four isolated PostgreSQL tests skipped), API typecheck/build and OpenAPI generation/drift. Five unchanged verification goldens were visually inspected. Debug APK 0.1.0+20260910 uses the existing Railway development defines; SHA-256 `066E875740BFF9D0F67F977C81E075AA229ADD9CB37D621B73A7B2E0977A35D5`. Full commands and limitations are recorded in CURRENT_SYSTEM_STATE.md under Phone Input Correction Validation.

| Area | Changed files |
| --- | --- |
| Mobile runtime | lib/core/auth/registration_models.dart, sms_retriever.dart; lib/features/auth/presentation/phone_verification_screen.dart |
| API runtime | src/app.module.ts, src/config/environment.ts, src/registration/phone-challenge.service.ts, registration.dto.ts |
| Contracts | packages/contracts/src/index.ts; apps/api/openapi/openapi.json (regenerated) |
| Regression tests | Mobile auth_flow_test.dart, phone_auth_repository_test.dart, phone_verification_test.dart; API environment.spec.ts, phone-challenge.service.spec.ts, postgres.integration.spec.ts |
| Guidance | .env.example comments, API/mobile READMEs, this guide, current state and traceability notes; no master-template change |

Paths in the runtime/test rows are relative to their application. No schema, new dependency, native Android receiver, worker or operational outbox change was needed.


### Railway SMS variable audit — 2026-09-10

**Confirmed configuration gap:** Signed-in Railway inspection shows the phone-input fix deployed (deployment c98b3d21), with Client code request/resend HTTP 200 and verify HTTP 401 in network logs. The service has 21 variables and uses only three project shared variables; SMS_PROVIDER, AFRICASTALKING_API_BASE_URL, AFRICASTALKING_USERNAME, AFRICASTALKING_API_KEY, AFRICASTALKING_SENDER_ID and SMS_ANDROID_APP_HASH are available as shared variables but not attached to weyonje-api. Its WEYONJE_ENVIRONMENT is development, so the missing provider selects FAKE by the current code. HTTP 200 alone is not evidence of SMS delivery.

The shared non-secret settings are AFRICAS_TALKING, the live endpoint, username weyonje, blank sender and public debug hash iRKzuOXzxKg. The key remains masked and its validity was not tested. The signed-in Africa’s Talking application is Weyonje / weyonje. Required correction: link these six existing shared settings to the API service and redeploy, subject to the user's explicit deployment approval. No remote variables changed or SMS sent during this audit. A bounded authorized live test must distinguish API acceptance, outbox entry, handset receipt and completed authentication.


### Approved Railway SMS attachment — 2026-09-10

**Implemented externally:** Following explicit user approval, attached the six existing shared SMS variables to weyonje-api: SMS_PROVIDER, AFRICASTALKING_API_BASE_URL, AFRICASTALKING_USERNAME, AFRICASTALKING_API_KEY, AFRICASTALKING_SENDER_ID and SMS_ANDROID_APP_HASH. Railway now reports 27 service variables and nine shared references in use. Reviewed exactly six staged reference additions and deployed them. Deployment 1a28a4f2-6650-410f-9861-a46bd6d2f471 reports ACTIVE / Deployment successful. The existing key was neither revealed nor replaced. No SMS was sent; actual provider acceptance, outbox entry, handset receipt and authentication still require a bounded authorized live test. This supersedes the preceding pending-attachment/deployment status.

## Client sign-in registration branch and rate-limit recovery — 2026-09-10

The existing Client-code request returns the unchanged eligible challenge or a typed `REGISTRATION_REQUIRED` outcome only when no account owns the normalized phone. Mobile passes the entered number through in-memory GoRouter extra into an editable, one-time registration prefill. No SMS, challenge or account is created for that response. This intentionally reveals a limited registration distinction. Existing restricted accounts receive generic feedback; pending registration remains recoverable by explicit submission of the existing form without unauthenticated profile replacement.

Every valid initial Client-code request consumes a protected phone/IP allowance using the existing AUTH_ACCOUNT_MAX_ATTEMPTS, AUTH_IP_MAX_ATTEMPTS, AUTH_THROTTLE_WINDOW_SECONDS and AUTH_LOCK_SECONDS settings in separate database key namespaces. This includes unknown and restricted phones; it cannot become an unlimited lookup endpoint. Resends continue through the existing phone/purpose OTP limits. No environment values, providers, credentials, schema or dependencies changed.

The API error contract now preserves `retryAt` and `limitCategory`: hourly issuance, resend cooldown and initial Client-request throttling remain distinct from exhausted verification attempts. The UI displays the server-derived retry time and gates further issuance, including after code edits. Hourly release is computed from stored creation timestamps and the latest cooldown, including failed deliveries. Initial request throttle errors and resend cooldowns include any later hourly boundary; resend reports the hourly category when that limit also applies. No automatic network retry or counter reset is introduced. The sent-message copy applies only to successful submission; failed/unconfirmed delivery stays separate.

Read-only Railway evidence: the current service exposes 27 variables and nine shared references, including the previously attached SMS settings. OTP_TTL_SECONDS, OTP_RESEND_SECONDS, OTP_MAX_ATTEMPTS and OTP_MAX_REQUESTS_PER_HOUR are absent as service overrides; the deployed code defaults imply 600 seconds, 60 seconds, 5 attempts and 5/hour respectively. AUTH settings are 5/account, 20/IP, 900-second window/lock. The latest deployment was sleeping; no server request, SMS or remote change was made. Local .env agrees on OTP limits but is not the evidence for Railway. The exact live rate-limit incident remains unconfirmed without affected challenge/provider history.

Old mobile clients safely fail parsing the new absent-phone outcome; roll out both API and mobile to enable branching. See CURRENT_SYSTEM_STATE.md for local test/build evidence and physical-device limitations.

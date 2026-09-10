# Phone verification and SMS testing

Client registration and Client code sign-in use the existing native endpoints and shared verification screen. Forui 0.25.0 renders one editable six-digit value as six boxes. Manual entry, paste and Android candidates use the same guarded server request. A complete unchanged value submits once; errors reset when edited, and a network retry requires an explicit action. Server-confirmed success is green for 650 ms before existing actor routing. The transition and pending requests are cancelled when leaving.

## Server configuration

Store credentials only in the ignored root `.env` or an approved server secret store. Do not put provider keys in Flutter defines, an APK, examples, screenshots, logs or chat. The application uses an API key, never the dashboard password.

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

## Changed file groups

| Area | Files |
| --- | --- |
| API phone challenges and completion | `apps/api/src/registration/phone-challenge.service.ts`, `registration.service.ts`, `phone.module.ts`; `apps/api/src/auth/auth.service.ts`, `session.service.ts` |
| API provider boundary | `apps/api/src/registration/sms-gateway.ts`, new `otp-message.ts`; `apps/api/src/config/sms.config.ts`; root `.env.example` |
| API tests | `apps/api/test/phone-challenge.service.spec.ts`, `registration.service.spec.ts`, `sms.config.spec.ts`, new `sms-gateway.spec.ts`, `postgres.integration.spec.ts` |
| Mobile auth and input | `apps/mobile/lib/core/auth/auth_repository.dart`, new `sms_retriever.dart`; `apps/mobile/lib/features/auth/application/registration_controller.dart`, `launch_controller.dart`; `apps/mobile/lib/features/auth/presentation/phone_verification_screen.dart`, `choose_account_type_screen.dart`; new `apps/mobile/lib/ui/weyonje_otp_field.dart` |
| Android | `apps/mobile/android/app/build.gradle.kts`; `MainActivity.kt` and new `WeyonjeSmsRetriever.kt` under the existing package; new `apps/mobile/tool/sms_app_hash.cjs` |
| Mobile tests and visual evidence | `apps/mobile/test/auth_flow_test.dart`, new `phone_auth_repository_test.dart`, `phone_verification_test.dart`; five updated `account_type_*.png` and six new `verification_*.png` goldens |
| Documentation | This setup guide, API/mobile READMEs, `CURRENT_SYSTEM_STATE.md` and `MOBILE_APPLICATION_TRACEABILITY_AND_DECISIONS.md`. The state template is unchanged. |

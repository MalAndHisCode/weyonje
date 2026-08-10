# Weyonje Current System State

> **Purpose:** This document is a concise, evidence-based snapshot of what is present in the Weyonje repository today. It describes implemented reality, not the target business processes or proposed technology stack.

## Document control

| Field | Value |
| --- | --- |
| Document version | 1.0 |
| Last updated and verified | 2026-08-10 |
| Verified against | Local repository at `D:\Dev\weyonje`; no commit or release exists |
| Git state | Repository has no commits and `git ls-files` returns no tracked files; all visible project content is currently untracked |
| System version | No system release; mobile package declares `0.1.0+1` |

The repository files and working code were treated as primary evidence. `BUSINESS_PROCESS_SPECIFICATION.docx`, `TECHNOLOGY_STACK.md`, and `BRAND_IDENTITY_GUIDELINES.md` were used only as requirements, proposals, or design context.

## Status legend

| Status | Meaning in this document |
| --- | --- |
| **Implemented** | Present and confirmed in current repository files. |
| **Partially Implemented** | Some supporting code or configuration exists, but the capability is incomplete. |
| **Not Implemented** | No functioning implementation is present. |
| **Deprecated** | Present but no longer intended for continued use. |
| **Temporarily Disabled** | Intentionally inactive for a limited period. |
| **Known Broken / Unstable** | Current evidence confirms that the implementation fails or cannot be used reliably. |
| **Unknown / Not Yet Verified** | Repository evidence is insufficient to establish the state. |

## Current project summary and maturity

Weyonje is at project initiation. The repository has a monorepo-shaped `apps/` structure and project-context documents, but only an Android-targeted Flutter application skeleton contains substantive application files. The skeleton includes generated Forui theme code and Android build scaffolding; it does not currently pass Dart analysis and has no completed product screens or business workflows.

No backend, web portal, background worker, persistence layer, deployed environment, or operational system is implemented. The workflows in the business specification and the architecture and services in the technology stack remain context for future work unless separately evidenced by code.

## Implemented functionality

| Capability | Status | Current reality | Evidence |
| --- | --- | --- | --- |
| Flutter application entry point | **Partially Implemented** | `main()` attempts to start a `MaterialApp.router` wrapped with Forui theme, toaster, and tooltip providers. Router configuration is still a TODO. | `apps/mobile/lib/main.dart` |
| Light and dark design tokens | **Partially Implemented** | The generated default/light Forui colour configuration now contains Weyonje's documented working semantic palette, including its blue accessibility-focus token. The separate generated dark colours remain the unapproved preset values. Neither scheme is usable by a running application while the theme library declarations are broken. | `apps/mobile/lib/theme/colors.dart`, `apps/mobile/lib/theme/style.dart` |
| Weyonje logo asset | **Partially Implemented** | A 554 x 554 PNG exists under the mobile assets directory, but `pubspec.yaml` does not declare it as a Flutter asset and no code references it. | `apps/mobile/assets/branding/weyonje-logo.png`, `apps/mobile/pubspec.yaml` |
| Product screens and navigation | **Not Implemented** | No feature screens, route definitions, or usable navigation are present. | `apps/mobile/lib/` |
| Registration, verification, requests, assignments, journeys, disposal confirmation, feedback, ratings, roles, and permissions | **Not Implemented** | These are specified business processes only; no implementing client, API, data model, or test code exists. | Repository inspection; `BUSINESS_PROCESS_SPECIFICATION.docx` is requirements evidence only |

## Architecture and major component status

| Component | Location | Status | Current boundary |
| --- | --- | --- | --- |
| Mobile application | `apps/mobile/` | **Known Broken / Unstable** | Flutter/Forui Android skeleton; static analysis fails before a runnable product experience is established. |
| API | `apps/api/` | **Not Implemented** | Empty reserved directory. |
| Web portal | `apps/web/` | **Not Implemented** | Empty reserved directory. |
| Background worker | `apps/worker/` | **Not Implemented** | Empty reserved directory. |
| Data and persistence | None | **Not Implemented** | No schemas, migrations, database client, cache, or local application data layer is present. |
| Deployment and operations | None | **Not Implemented** | No CI workflow, container, infrastructure, deployment, monitoring, backup, or runbook implementation is present. |

The modular monolith, React portal, NestJS API, BullMQ workers, PostgreSQL/PostGIS, Valkey, Keycloak, Render services, Google Maps, notifications, monitoring, and production infrastructure described in context documents are not current architecture components.

## Repository structure and code organization

```text
apps/
  api/                 # empty placeholder
  mobile/              # Flutter project and Android platform scaffolding
    android/
    assets/branding/
    lib/
      main.dart
      theme/
  web/                 # empty placeholder
  worker/              # empty placeholder
docs/
  brand/               # source brand asset
  project-context/     # requirements, rules, stack, brand guidance, and state template
```

There is no root README, root `.gitignore`, workspace manifest, shared package area, repository command runner, or CI configuration. Future work should preserve clear ownership between the four application directories and avoid treating the empty placeholders or proposed cross-application architecture as already established.

## Current mobile application state

- **Implemented:** Flutter project metadata identifies an application project created on the stable channel with only the root and Android platforms recorded. No iOS, web, Windows, macOS, or Linux Flutter platform project is present.
- **Implemented:** Direct runtime dependencies are Flutter and Forui. The lockfile resolves Forui `0.25.0`; development dependencies include `flutter_test`, `flutter_lints 6.0.0`, and Forui CLI `0.25.0`.
- **Partially Implemented:** Forui CLI configuration points generated snippets to `lib`, styles to `lib/theme/styles`, themes to `lib/theme/theme.dart`, and fonts to `assets/fonts`.
- **Partially Implemented:** `lib/theme/colors.dart` centrally configures the default/light `FColors` values with Weyonje's documented working semantic palette. Forui `0.25.0` has no built-in focus colour field, so the blue `#0B65D8` focus token is carried by the generated `AppColors` extension and consumed by the existing global focus-outline style. These configured colours cannot currently be exercised by a running application because of the theme import and library-part errors below.
- **Not Implemented:** No approved branded dark palette has been implemented. The separate generated dark scheme remains unchanged in its visible colour behaviour and must not be treated as approved Weyonje dark-mode branding.
- **Known Broken / Unstable:** `lib/main.dart` imports `../theme.dart`, which does not exist. The available theme entry is `lib/theme/theme.dart`.
- **Known Broken / Unstable:** `colors.dart`, `icons.dart`, `style.dart`, and `typography.dart` declare `part of 'lib/theme/theme.dart'`, which does not match the library declared by `theme.dart`; analysis reports `PART_OF_DIFFERENT_LIBRARY` and cascading undefined-symbol errors.
- **Not Implemented:** There are no feature directories, screens, state management, API client, domain models, tests, localization content, permissions, or product workflows.

## Confirmed configuration and development requirements

| Area | Confirmed state |
| --- | --- |
| Dart / Flutter | `pubspec.yaml` requires Dart `^3.12.2`; the resolved lockfile requires Flutter `>=3.44.0-0`. No repository-level Flutter version pin is present. |
| Linting | `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. |
| Android identity | Namespace and application ID are both `ug.go.kcca.weyonje.weyonje`; the generated TODO to confirm a unique application ID remains. The application label is `weyonje`. |
| Android SDK levels | `compileSdk`, `minSdk`, `targetSdk`, and NDK version inherit from the installed Flutter SDK rather than being fixed numerically in the repository. |
| Java / Kotlin | Java source and target compatibility are 17; Kotlin JVM target is 17. |
| Android build tools | Android Gradle Plugin `9.0.1`, Kotlin Android plugin `2.3.20`, and Gradle wrapper `9.1.0` are configured. |
| Signing | Release builds temporarily use the debug signing configuration; production signing is not configured. |
| Local SDK paths | Android and Flutter SDK paths are supplied through ignored, machine-specific `android/local.properties`; their values are not portable configuration. |

No environment-variable contract, non-secret environment template, secrets configuration, or feature-flag configuration exists.

## External integrations and services

**Not Implemented.** No external service integration is present. In particular, there is no implemented identity provider, SMS, push notification, mapping, API, database, cache, queue, telemetry, monitoring, or deployment service. Forui is an application package dependency, not an operational external-service integration.

## Validation and build status

- On 2026-08-10, `dart analyze --format machine` was run from `apps/mobile` using the installed Flutter Dart SDK. It exited with code `3` and reported compile-time errors, beginning with `URI_DOES_NOT_EXIST` for `lib/main.dart` and `PART_OF_DIFFERENT_LIBRARY` for the generated theme parts.
- On 2026-08-10, the default/light Forui colour update was statically verified against the required ARGB values, and the documented foreground/background pairs were checked against WCAG contrast thresholds. Text pairs passed at `5.12:1` or better, and the focus token passed at `4.78:1` or better against the configured light surfaces. The required `#D4DAD6` border reaches only `1.35:1` against the canvas and `1.42:1` against the white card, so it does not meet `3:1` when used as the sole meaningful control boundary. Dart formatting and post-change analysis were also run; every diagnostic remained a consequence of the pre-existing theme import and library-part failures, with no independent diagnostic attributable to the configured ARGB values or focus extension API. UI rendering remained blocked by those failures, and no theme tests were available because the repository has no `test/` directory.
- Application builds and tests were not run: the analysis failure already establishes that the current source is not build-ready, and there is no `test/` directory.
- No repository-provided documentation check was found.
- Text and tables were extracted from `BUSINESS_PROCESS_SPECIFICATION.docx`. Visual rendering could not run because the required LibreOffice executable is unavailable; no current-state claim depends on its page layout.

## Known issues, limitations, and technical debt

| Item | Status | Impact |
| --- | --- | --- |
| Missing theme import target in `main.dart` | **Known Broken / Unstable** | Prevents the application entry point from resolving `lightTheme` and `darkTheme`. |
| Incorrect generated theme part declarations | **Known Broken / Unstable** | Prevents the theme files from forming one Dart library and causes cascading analyzer errors. |
| Light border token has insufficient standalone contrast | **Known Broken / Unstable** | The required `#D4DAD6` border is below `3:1` against both the configured canvas and white card, so controls cannot rely on this border alone as their meaningful visual boundary. |
| Router not configured | **Partially Implemented** | No screen can be reached through the `MaterialApp.router` skeleton. |
| Release uses debug signing | **Partially Implemented** | Release builds are temporarily signed with the debug configuration; a production signing configuration does not exist. |
| Application-identifier TODO remains | **Partially Implemented** | The current identifier is configured, but the template explicitly leaves uniqueness confirmation unresolved. |
| Logo is not registered as a Flutter asset | **Partially Implemented** | The image is present but unavailable through the normal Flutter asset bundle. |
| Repository has no tracked files or commits | **Known Broken / Unstable** | There is no versioned baseline against which repository state, history, or releases can be reliably compared. |

No deprecated functionality or intentionally disabled feature was found.

## Incomplete and not-yet-implemented areas

The repository does not yet implement the product capabilities described by the business specification: account registration and phone verification, provider review, service requests from mobile or the KCCA Call Centre, provider assignment and acceptance, scheduled reminders, location-aware journeys, collection and disposal confirmation, feedback, ratings, notifications, or KCCA oversight.

The proposed API, web portal, worker, data stores, identity, integrations, CI/CD, deployments, monitoring, security controls, backups, and production operations are also absent. Their exact implementation and operational status remain **Unknown / Not Yet Verified** until corresponding repository or deployed-system evidence exists.

## References and evidence boundaries

| Source | Use in this snapshot | Limitation |
| --- | --- | --- |
| Current repository files and analyzer output | Primary implementation evidence | No committed baseline exists. |
| `CURRENT_SYSTEM_STATE_TEMPLATE.md` | Structure and status-reporting intent | Template instructions and unused sections were not copied. |
| `AI_CODING_AGENT_RULES.md` | Adopted development and documentation rules | Rules do not prove implementation. |
| `BUSINESS_PROCESS_SPECIFICATION.docx` | Business requirements baseline | Required workflows are not implemented merely because they are specified. |
| `TECHNOLOGY_STACK.md` | Proposed architecture and technology baseline | Proposed technologies are not implemented unless present in code or configuration. |
| `BRAND_IDENTITY_GUIDELINES.md` | Brand source and recommendations | Recommendations are not proof of implemented UI behaviour. |

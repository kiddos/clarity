# AGENTS.md

Welcome to the **Clarity** codebase. This guide is tailored for AI agents and human developers to understand the project architecture, tech stack, data models, development workflows, and conventions.

## 1. Project Overview & Architecture

**Clarity** is an open-source Personal Health Record (PHR) mobile application built with Flutter. It implements the HL7® FHIR® R4 standard and SMART on FHIR OAuth 2.0 authorization framework to allow patients and practitioners to securely connect directly to healthcare FHIR servers and access aggregated clinical records in real time.

- **App ID / Namespace:** `app.kiddos.fhir.clarity`
- **Current Version:** `1.0.1+5`
- **Target Platforms:** Android (primary, published on Google Play), iOS, Web, macOS, Linux, Windows.
- **`lib/` Directory Organization:** The project follows a flat, feature-first structure centered around pages (`patient_profile_page.dart`, `patient_lab_page.dart`), with core logic in shared utilities (`constants.dart`, `auth.dart`, `log.dart`).
- **State Management & Dependency Injection:** Currently uses standard Flutter `StatefulWidget` and `setState()`. No external state management (e.g., Riverpod, Bloc) or DI packages are active. Dependencies (like token data and URL) are passed explicitly down the widget tree via constructors.
- **Data Flow Rules:**
  - **Auth:** OAuth 2.0 (via `flutter_web_auth_2`) retrieves token data and the base FHIR URL.
  - **UI / Domain:** Sub-pages handle their own HTTP data fetching tightly coupled with UI logic. Sub-pages query paginated FHIR models directly.
  - **Pagination:** Follows a standard pattern inspecting the FHIR Bundle's `link` array for `relation == 'next'`, implementing infinite scrolling via `ScrollController` listener (fetching when `pixels >= maxScrollExtent * 0.9`).

## 2. Environment, Code Generation & Build Commands

- **Required SDK Versions:** Dart SDK `^3.5.4` (Flutter 3.x+). Tools like `fvm` or `mise` are not configured; use standard `flutter` and `dart` commands.
- **Fetching Dependencies:**
  ```bash
  flutter pub get
  ```
- **Code Generation & Localizations:** The project currently does not use `build_runner`, `freezed`, `json_serializable`, or localizations (`l10n.yaml`). If code generation is introduced, the command would be:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
  Similarly, for generating localizations if set up:
  ```bash
  flutter gen-l10n
  ```
- **Building Platform Targets:**
  ```bash
  # Android (APK and App Bundle)
  flutter build apk --release
  flutter build appbundle --release

  # iOS
  flutter build ios --release

  # Web
  flutter build web --release
  ```

## 3. Testing, Static Analysis & Verification Workflow

- **Static Analysis:** Uses standard Flutter lint rules configured in `analysis_options.yaml` (using `flutter_lints`).
  ```bash
  flutter analyze
  ```
- **Formatting Checks:**
  ```bash
  dart format --output=none --set-exit-if-changed .
  ```
- **Testing Commands:** The repository contains headless widget tests (in `test/`) but currently no device-dependent integration tests (`integration_test/`). Headless tests can be executed directly by agents.
  - Run all unit and widget tests:
    ```bash
    flutter test
    ```
  - Target a single test file:
    ```bash
    flutter test test/widget_test.dart
    ```
- **Testing Specifics:** Widget tests require mocking `SharedPreferences` (e.g., `SharedPreferences.setMockInitialValues({})`) and should not perform real network calls.

## 4. Dart & Flutter Coding Conventions

- **Widget & UI Layer:**
  - Prefer small `StatelessWidget` and `StatefulWidget` classes rather than helper methods returning large widget trees.
  - Liberally use `const` constructors to optimize rendering.
  - Follow Material 3 guidelines and use `Theme.of(context)` for styling. App theme seed color is `Colors.teal`.
  - UI localization strings are hardcoded. Do not introduce `.arb` localization files unless part of the active implementation.
- **State & Concurrency:**
  - State mutations must use `setState()`.
  - All asynchronous network calls must be wrapped in robust `try/catch` blocks with appropriate fallback UI handling.
  - **Crucial:** Always check `if (!mounted)` or `if (!context.mounted)` across `async` gaps before interacting with contexts (e.g., using `Navigator` or triggering `setState`).
- **Native Interop & Platform Channels:**
  - No custom `MethodChannel`, Pigeon schemas, or Dart FFI bindings exist.
  - Native integration is limited to Android's `AndroidManifest.xml` deep linking via `clarity.kiddos.app://callback` for OAuth authorization code redirects.

## 5. Agent Guardrails (Do's and Don'ts)

- **Do's:**
  - Always run `flutter analyze` and relevant `flutter test` targets before finalizing and submitting changes.
  - Use `flutter pub add` / `flutter pub remove` (or follow existing version constraints in `pubspec.yaml`) when managing dependencies.
  - Always check `context.mounted` after `await` in asynchronous operations involving UI updates.
  - Centralize logging through `lib/log.dart` (using `log.i`, `log.w`, `log.e`) rather than using standard `print()`.

- **Don'ts:**
  - Never manually edit generated files (e.g., `*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`, or generated `app_localizations*.dart`) if introduced.
  - Always re-run `build_runner` after modifying annotated classes or schemas (if introduced in the future).
  - Never commit real patient data (Protected Health Information - PHI) or live credentials to test mocks or fixtures.
  - Do not log sensitive credentials (e.g., Bearer `access_token`, `refresh_token`, or complete JWT `id_token`) to production logs.
# AGENTS.md

Welcome to the Clarity codebase. This file provides autonomous coding agents and human developers with the architecture, configurations, and workflows required to build, analyze, test, and modify the project accurately.

## 1. Project Overview & Architecture

- **Purpose:** Clarity is an open-source Personal Health Record (PHR) mobile application built with Flutter. It implements the HL7® FHIR® R4 standard and SMART on FHIR OAuth 2.0 authorization framework.
- **Target Platforms:** Android, iOS, Web, macOS, Linux, and Windows.
- **Directory Organization:** The `lib/` directory follows a flat, feature-first structure centered around specific pages (e.g., `patient_profile_page.dart`, `patient_lab_page.dart`), with shared utilities (e.g., `auth.dart`, `constants.dart`, `log.dart`).
- **State Management & Dependency Injection:** The project exclusively relies on standard Flutter `StatefulWidget` and `setState()`. There are no external state management libraries (e.g., Riverpod, Bloc, Provider) or Dependency Injection containers. Dependencies (such as token data and base URLs) are passed explicitly down the widget tree via constructors.
- **Data Flow Rules:**
  - **Auth Layer:** Handles OAuth 2.0 via `flutter_web_auth_2` to retrieve token data and base FHIR URLs.
  - **UI / Domain & Data Layer:** Business logic, networking, and UI rendering are tightly coupled. Sub-pages (like `patient_lab_page.dart`) handle their own direct HTTP data fetching and query paginated FHIR models directly.
  - **Pagination:** Uses the FHIR Bundle's `link` array (where `relation == 'next'`) and implements infinite scrolling via a `ScrollController` listener (triggering a fetch when `pixels >= maxScrollExtent * 0.9`).

## 2. Environment, Code Generation & Build Commands

- **SDK Versions:** The project requires Dart SDK `^3.5.4` and Flutter 3.x+. Standard `flutter` and `dart` commands are used (no `fvm` or `mise exec` prefix is required).
- **Fetching Dependencies:**
  ```bash
  flutter pub get
  ```
- **Code Generation:** The project currently does not use code generation (`build_runner`, `freezed`, `json_serializable`, `pigeon`, `ffigen`). However, if code generation is introduced, use the following exact command:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Localization:** The project does not currently use `.arb` files or custom localization strings (UI strings are hardcoded). If localization generation is set up in the future, run:
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

- **Static Analysis:** The project uses `flutter_lints` configured in `analysis_options.yaml`. To run static analysis:
  ```bash
  flutter analyze
  ```
- **Formatting Checks:**
  ```bash
  dart format --output=none --set-exit-if-changed .
  ```
- **Testing Overview:** The project uses `flutter_test` for headless unit and widget tests located in the `test/` directory (e.g., `test/widget_test.dart`). Headless tests can be executed directly by agents. There is currently no `integration_test/` directory for device-dependent integration tests. Widget tests require mocking `SharedPreferences` (e.g., `SharedPreferences.setMockInitialValues({})`) and should not perform real network calls.
- **Running All Tests:**
  ```bash
  flutter test
  ```
- **Targeting a Single Test File:**
  ```bash
  flutter test test/widget_test.dart
  ```

## 4. Dart & Flutter Coding Conventions

- **Widget & UI Layer:**
  - **Widget Decomposition:** Favor small `StatelessWidget` or `StatefulWidget` classes over helper methods that return large widget trees.
  - **Const Constructors:** Liberally use `const` constructors to optimize rendering performance.
  - **Theme Usage:** Follow Material 3 guidelines and use `Theme.of(context)` for styling. The app theme seed color is `Colors.teal`.
  - **Localization:** Strings are hardcoded. Do not introduce custom localization strings unless specifically instructed.
- **State & Concurrency:**
  - **Reactive State:** State mutations must use `setState()`.
  - **Error Handling:** All asynchronous operations and network calls must be wrapped in robust `try/catch` blocks with appropriate fallback UI handling.
  - **Context Across Async Gaps:** Always check `if (!mounted)` (in StatefulWidgets) or `if (!context.mounted)` before executing state updates or interacting with the context across `async` gaps (e.g., using `Navigator`).
- **Native Interop:**
  - The project does not use custom `MethodChannel`, `EventChannel`, Pigeon schemas, or Dart FFI bindings.
  - Native integration is currently limited to deep linking for OAuth redirects, configured in Android's `android/app/src/main/AndroidManifest.xml` via the `clarity.kiddos.app://callback` scheme.

## 5. Agent Guardrails (Do's and Don'ts)

- **Do's:**
  - Always run `flutter analyze` and relevant `flutter test` targets before finalizing changes.
  - Use `flutter pub add` / `flutter pub remove` (or follow existing version-pinning conventions in `pubspec.yaml`) when managing packages.
  - Centralize logging through the helper in `lib/log.dart` (using `log.i`, `log.w`, `log.e`) rather than using `print()`.
- **Don'ts:**
  - Never manually edit generated files (e.g., `*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`, or generated `app_localizations*.dart`).
  - Always re-run `build_runner` after modifying annotated classes or schemas (if such tools are introduced).
  - Never commit or log Protected Health Information (PHI), live credentials, sensitive tokens (e.g., Bearer `access_token`, `refresh_token`, or complete JWT `id_token`), or test mocks containing real data.

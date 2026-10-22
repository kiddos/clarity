# AGENTS.md

Welcome to the **Clarity** codebase. This guide is tailored for AI agents and human developers to understand the project architecture, tech stack, data models, development workflows, and conventions.

---

## 1. Project Overview

**Clarity** is an open-source Personal Health Record (PHR) mobile application built with Flutter. It implements the **HL7® FHIR® R4** standard and **SMART on FHIR** OAuth 2.0 authorization framework to allow patients and practitioners to securely connect directly to healthcare FHIR servers and access aggregated clinical records in real time.

- **Target Platforms:** Android (primary, published on Google Play as `app.kiddos.fhir.clarity`), iOS, Web, macOS, Linux, Windows.
- **Flutter / Dart SDK:** Dart SDK `^3.5.4` (Flutter 3.x+).
- **Domain:** HealthTech / Medical Informatics / SMART on FHIR / HL7 FHIR R4.

---

## 2. Architecture & Data Flow

```
                      +-----------------------------+
                      |       Authentication        |
                      |     (SMART on FHIR OAuth)   |
                      |   lib/auth.dart / auth_page |
                      +--------------+--------------+
                                     |
                       Token Data & FHIR Base URL
                                     v
                      +-----------------------------+
                      |     Patient Profile Page    |
                      | (lib/patient_profile_page)  |
                      |   - Patient Demographics    |
                      |   - Practitioner Info       |
                      |   - Vital Signs (LOINC)     |
                      |   - Encounter Timeline      |
                      +--------------+--------------+
                                     |
    +--------------+------------+----+----+-------------+---------------+
    |              |            |         |             |               |
    v              v            v         v             v               v
  Labs         Vitals      Medications Conditions   Allergies      Vaccines / Reports
(patient_lab) (patient_lab)  (patient_  (patient_    (patient_      (patient_vaccination /
                            medication) condition)   allergy)      patient_diagnostic_report)
```

### Authentication Flow (SMART on FHIR)
1. User selects a FHIR base URL (default: `https://thas.mohw.gov.tw/v/r4` or a custom user-added server saved in `SharedPreferences`) and a launch context (e.g. Practitioner or Patient).
2. The app invokes `FlutterWebAuth2.authenticate()` pointing to `$baseUrl/sim/$launch/auth/authorize` with scopes:
   `openid fhirUser offline_access user/*.* patient/*.* launch/encounter launch/patient profile`
   and redirect scheme: `clarity.kiddos.app://callback`.
3. The auth code is exchanged for an access token via `$baseUrl/auth/token`.
4. The token payload includes:
   - `access_token`: Bearer token for FHIR API calls.
   - `patient`: FHIR Patient resource ID.
   - `id_token`: JWT containing the `fhirUser` claim for the practitioner or patient identity.
5. On successful authentication, navigation pushes to `PatientProfilePage`.

---

## 3. Repository Map & Directory Layout

```
.
├── lib/
│   ├── main.dart                          # App entry point (runs MainApp)
│   ├── main_app.dart                      # MaterialApp setup, ThemeData (Teal / M3)
│   ├── home_page.dart                     # Wrapper returning AuthPage
│   ├── constants.dart                     # OAuth client ID, scheme, redirect URI, scopes
│   ├── log.dart                           # Centralized logger instance (Logger package)
│   ├── auth.dart                          # OAuth2 auth URL builder & token exchange
│   ├── auth_page.dart                     # Server picker, launch option picker, auth trigger
│   ├── patient_profile_page.dart          # Main dashboard (demographics, vitals, encounters)
│   ├── patient_lab_page.dart              # Lab results & vital signs paginated list
│   ├── patient_medication_page.dart       # MedicationRequest list with pagination
│   ├── patient_condition_page.dart        # Medical conditions & problem list with pagination
│   ├── patient_allergy_page.dart          # Allergies & intolerances with criticality tags
│   ├── patient_vaccination_page.dart      # Immunization history with pagination
│   └── patient_diagnostic_report_page.dart# Diagnostic reports with pagination
├── assets/
│   └── images/icons/                      # Custom medical icons (lungs, oxygen, bmi, etc.)
├── android/
│   ├── app/src/main/AndroidManifest.xml   # Contains CallbackActivity with scheme clarity.kiddos.app
│   └── app/build.gradle                   # Android configuration & dependencies
├── test/
│   └── widget_test.dart                   # Default widget test template (needs update)
├── application.md                         # SMART App / FHIR IG / App store registration metadata
├── analysis_options.yaml                  # Linter configuration (package:flutter_lints/flutter.yaml)
└── pubspec.yaml                           # Project dependencies and asset definitions
```

---

## 4. Key Dependencies & Libraries

| Package | Version | Purpose |
| :--- | :--- | :--- |
| `fhir` | `^0.12.1` | HL7 FHIR R4 domain models (`Patient`, `Practitioner`, `Observation`, `Encounter`, `Bundle`) |
| `flutter_web_auth_2` | `^5.0.0` | Secure web-based OAuth 2.0 PKCE / redirect handling |
| `http` | `^1.6.0` | Direct REST API calls to FHIR endpoints |
| `shared_preferences` | `^2.5.3` | Persisting user-entered custom FHIR server URLs |
| `timelines_plus` | `^1.0.8` | Rendering chronological timeline of patient encounters |
| `fl_chart` | `^1.1.1` | Charting & medical data visualization |
| `logger` | `^2.6.2` | Structured debugging and logging |
| `intl` | `^0.20.2` | Date/time parsing and formatting |
| `flutter_lints` | `^6.0.0` | Recommended static analysis rules |

---

## 5. FHIR Resources & Clinical Codes

### Supported FHIR R4 Resources
- **Patient**: Demographic profile (name, birthDate, age calculation).
- **Practitioner**: User identity parsed from the `id_token` `fhirUser` claim.
- **Observation**: Vital signs and laboratory results.
- **Encounter**: Clinical encounters, consultation types, and timeline status.
- **Condition**: Diagnoses, clinical status (`active`, `resolved`), severity.
- **MedicationRequest**: Prescriptions, status (`active`, etc.), dosage instructions.
- **AllergyIntolerance**: Allergies, criticality (`high`, `unable-to-assess`), verification status.
- **Immunization**: Vaccines administered, occurrence date, site, status.
- **DiagnosticReport**: Diagnostic and lab report summaries, categories, statuses.

### LOINC Vital Sign Codes Used (`lib/patient_profile_page.dart`)
- `8302-2`: Body Height
- `29463-7`: Body Weight
- `883-9`: ABO Blood Group
- `10331-6`: Rh Blood Group
- `8310-5`: Body Temperature
- `55284-4`: Blood Pressure Panel (`8480-6` Systolic, `8462-4` Diastolic components)
- `8867-4`: Heart Rate
- `9279-1`: Respiratory Rate
- `2708-6`: Oxygen Saturation
- `39156-5`: Body Mass Index (BMI)

---

## 6. Coding Patterns & Conventions

### 1. FHIR Querying & Pagination Pattern
Sub-pages (`patient_lab_page.dart`, `patient_condition_page.dart`, etc.) follow a standard pagination pattern:
- **Initial Request:** `${requestUrl}/<Resource>?patient=$patient&_sort=-date&_count=10`
- **Next Page Extraction:** Inspect the FHIR Bundle's `link` array for `relation == 'next'`.
- **Infinite Scrolling:** Implemented using `ScrollController.addListener()` checking for `pixels >= maxScrollExtent * 0.9`.

### 2. State Management & Navigation
- Currently uses standard Flutter `StatefulWidget` and `setState()`.
- Navigation is performed using imperative `Navigator.of(context).push(MaterialPageRoute(...))`.
- State is passed directly via widget constructors (`requestUrl`, `tokenData`).

### 3. Error Handling & Logging
- Avoid `print()`. Use the centralized `log` instance from `lib/log.dart` (`log.i`, `log.w`, `log.e`).
- All asynchronous network calls are wrapped in `try/catch` with fallback handling.

### 4. UI / Theming
- Follows Material 3 guidelines (`useMaterial3: true`).
- App theme seed color: `Colors.teal`.
- Detail cards and list items use light green/indigo/teal badges for status representation.

---

## 7. Developer Commands

### Environment Setup
Make sure Flutter and Dart are in your `PATH` or configured via your version manager (e.g. mise, fvm, asdf):
```bash
# Verify Flutter installation
flutter doctor

# Fetch dependencies
flutter pub get
```

### Static Analysis & Testing
```bash
# Analyze code for lint errors and warnings
flutter analyze

# Run unit and widget tests
flutter test
```

### Running & Building
```bash
# Run on connected device or emulator
flutter run

# Run with dev flag if needed
flutter run --dart-define=IS_DEV=true

# Build Android APK / App Bundle
flutter build apk --release
flutter build appbundle --release
```

---

## 8. Known Issues & Notes for Agents

1. **`test/widget_test.dart` Status**:
   - The default `test/widget_test.dart` is currently boilerplate from the default Flutter template referencing `MyApp()` (which does not exist; the actual class is `MainApp`). Running `flutter test` will fail unless this test is updated or replaced with valid widget tests.
2. **Deep Linking Scheme**:
   - Android OAuth callback is handled via `clarity.kiddos.app://callback`. If testing OAuth locally on Android, verify that `AndroidManifest.xml` retains the `CallbackActivity` definition.
3. **FHIR Model vs. Raw JSON**:
   - `patient_profile_page.dart` uses typed `fhir` package classes (`Patient`, `Practitioner`, `Observation`, `Encounter`, `Bundle`).
   - Several sub-pages (`patient_lab_page.dart`, `patient_medication_page.dart`, etc.) parse FHIR Bundles as raw `Map<String, dynamic>`. When refactoring, consider standardizing to either the `fhir` R4 model classes or robust typed DTOs.
4. **Token Refresh**:
   - `offline_access` is included in the requested OAuth scopes, but token refresh logic (`refresh_token`) is not yet implemented. Keep this in mind when session expiry issues arise.

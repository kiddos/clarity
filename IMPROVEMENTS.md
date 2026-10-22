# Clarity Project Improvement Roadmap & Recommendations

This document outlines strategic, architectural, security, performance, UI/UX, and testing improvements for **Clarity**—an open-source Personal Health Record (PHR) mobile application built with Flutter implementing HL7® FHIR® R4 and SMART on FHIR.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Priority Matrix (P0 / P1 / P2)](#2-priority-matrix)
3. [SMART on FHIR & Authentication Standard Compliance](#3-smart-on-fhir--authentication-standard-compliance)
4. [Architecture & Code Quality](#4-architecture--code-quality)
5. [Performance & Network Optimization](#5-performance--network-optimization)
6. [Data Visualization & Clinical UI/UX](#6-data-visualization--clinical-uiux)
7. [Security & Protected Health Information (PHI) Safeguards](#7-security--protected-health-information-phi-safeguards)
8. [Testing Strategy & Quality Assurance](#8-testing-strategy--quality-assurance)
9. [Accessibility (a11y) & Internationalization (i18n)](#9-accessibility-a11y--internationalization-i18n)

---

## 1. Executive Summary

Clarity has established a strong foundation by demonstrating real-time FHIR R4 clinical data aggregation, OAuth 2.0 SMART on FHIR authorization against national health endpoints (such as Taiwan MoHW THAS), and an intuitive patient timeline and vitals dashboard.

To scale the project from a prototype into an enterprise-grade, production-ready open-source health application, key improvements are required across:
- **Standards compliance:** Supporting standard dynamic SMART configuration discovery and RFC 7636 PKCE.
- **Architecture:** Eliminating repetitive pagination boilerplate across 6 resource pages and standardizing on typed `package:fhir` domain models.
- **Network efficiency:** Replacing 10+ sequential HTTP requests on startup with batched FHIR requests.
- **Data visualization:** Activating `fl_chart` to render historical trends for vital signs and lab results.
- **PHI security:** Eliminating sensitive token/data console logging and adding encrypted credential storage.

---

## 2. Priority Matrix

| Priority | Category | Initiative | Impact / Rationale |
| :--- | :--- | :--- | :--- |
| **P0 (Critical)** | Testing | Fix broken `test/widget_test.dart` | Restores CI/CD build passing status (`flutter test`). |
| **P0 (Critical)** | Security | Strip token & PHI logging in production | Prevent leaking Bearer tokens, patient IDs, and clinical data to system logs. |
| **P0 (Critical)** | Security | Secure token storage (`flutter_secure_storage`) | Prevent plain-text storage of access/refresh tokens in app memory or prefs. |
| **P1 (High)** | Standards | Dynamic SMART on FHIR discovery | Query `/.well-known/smart-configuration` & `CapabilityStatement` instead of hardcoded paths. |
| **P1 (High)** | Standards | PKCE (RFC 7636) support | Mandatory security requirement for public mobile OAuth2 clients. |
| **P1 (High)** | Performance | Batch / Multi-code Observation queries | Reduce initial dashboard HTTP calls from 13+ requests to 1–2 requests. |
| **P1 (High)** | Architecture | Generic FHIR pagination & repository layer | Eliminate 80% copy-paste boilerplate across the 6 clinical list pages. |
| **P1 (High)** | Architecture | Typed FHIR models across all pages | Prevent untyped `Map<String, dynamic>` null-pointer and casting runtime exceptions. |
| **P1 (High)** | UX | Error handling & empty states | Provide retry buttons, error banners, and empty illustrations instead of silent drops. |
| **P2 (Medium)** | Visualization| Vital sign & lab trend charts (`fl_chart`) | Tap on vital sign tiles to inspect historical trends over time. |
| **P2 (Medium)** | Architecture | State management & DI (Riverpod / BLoC) | Clean separation of business logic, caching, and UI presentation. |
| **P2 (Medium)** | Localization| Traditional Chinese (zh-TW) & English i18n | Support Taiwan MoHW user base and international deployments. |
| **P2 (Medium)** | UX | Pull-to-refresh & skeleton loaders | Improve perceived performance and allow instant data re-sync. |
| **P2 (Medium)** | Offline | Local caching layer (Hive / SQLite) | Enable emergency offline clinical record access in low-connectivity areas. |

---

## 3. SMART on FHIR & Authentication Standard Compliance

### 3.1 Dynamic SMART Configuration Discovery
- **Current Limitation:** In `lib/auth.dart`, authorization endpoints are hardcoded to `$baseUrl/sim/$launch/auth/authorize` and `$baseUrl/auth/token`, which only works for the specific THAS simulator structure.
- **Recommended Solution:** Implement standard SMART App Launch discovery:
  1. Request `GET $baseUrl/.well-known/smart-configuration`.
  2. Parse `authorization_endpoint`, `token_endpoint`, `revocation_endpoint`, `management_endpoint`, and supported scopes.
  3. Fallback to `GET $baseUrl/metadata` (`CapabilityStatement`) with `http://fhir-registry.smarthealthit.org/StructureDefinition/oauth-uris` extension if `.well-known` is unavailable.
  4. Allows Clarity to connect interchangeably with Taiwan MoHW, SMART Health IT Sandbox, Epic, Cerner, and HAPI FHIR servers.

### 3.2 Proof Key for Code Exchange (PKCE - RFC 7636)
- **Current Limitation:** Mobile apps are public clients unable to securely protect client secrets. Currently, authorization uses plain authorization code exchange without PKCE.
- **Recommended Solution:**
  1. Generate a high-entropy cryptographic random `code_verifier`.
  2. Calculate `code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))`.
  3. Include `code_challenge` and `code_challenge_method=S256` in the `/authorize` request.
  4. Pass `code_verifier` in the POST body to `/token`.

### 3.3 Silent Token Refresh & Session Management
- **Current Limitation:** Scopes request `offline_access`, but the returned `refresh_token` is discarded. When `access_token` expires (typically in 15–60 minutes), subsequent API requests fail with 401s without warning.
- **Recommended Solution:**
  - Persist `refresh_token` securely.
  - Implement an HTTP client interceptor that automatically attempts token renewal via `grant_type=refresh_token` upon encountering a 401 or when checking expiration timestamps before requests.
  - Provide a clean Logout option that revokes tokens at the `revocation_endpoint` and clears local state.

---

## 4. Architecture & Code Quality

### 4.1 Eliminate Duplicated Pagination Logic
- **Current Limitation:** Six separate files (`patient_lab_page.dart`, `patient_medication_page.dart`, `patient_condition_page.dart`, `patient_allergy_page.dart`, `patient_vaccination_page.dart`, `patient_diagnostic_report_page.dart`) duplicate the identical pagination pattern:
  - `ScrollController.addListener()` checking `pixels >= maxScrollExtent * 0.9`.
  - Manual inspection of `bundle['link']` where `relation == 'next'`.
  - Manual management of `_isLoading`, `_hasMore`, `_nextPageUrl`, and dynamic entry lists.
- **Recommended Solution:** Create a reusable generic widget and pagination controller:
  ```dart
  class FhirPagedListView<T> extends StatelessWidget {
    final Future<FhirPageResult<T>> Function(String? pageUrl) fetcher;
    final Widget Function(BuildContext context, T item) itemBuilder;
    final Widget? emptyState;
    // Handles infinite scroll, pull-to-refresh, loading indicators, and error banners
  }
  ```

### 4.2 Standardize on Strongly Typed FHIR R4 Models
- **Current Limitation:** `patient_profile_page.dart` uses `package:fhir` classes, whereas sub-pages inspect untyped JSON structures such as:
  ```dart
  String substance = resource['code']?['text'] ??
      resource['code']?['coding']?[0]['display'] ?? "Unknown";
  ```
  This is prone to `TypeError` exceptions if fields vary across FHIR server implementations.
- **Recommended Solution:** Standardize all sub-pages on typed `fhir/r4.dart` models (`AllergyIntolerance`, `Condition`, `MedicationRequest`, `Immunization`, `DiagnosticReport`), ensuring consistent null-safety and autocompletion.

### 4.3 Clean Architecture & Dependency Injection
- **Current Limitation:** Business logic, networking, and UI rendering are tightly coupled inside `StatefulWidget` classes, making automated testing and mocking difficult.
- **Recommended Solution:** Introduce a layered architecture:
  - **Data Layer:** `FhirAuthClient`, `FhirRepository` (handles HTTP requests, headers, and token refresh).
  - **Domain / State Layer:** Riverpod or BLoC state providers managing auth state, active patient state, and clinical feeds.
  - **Presentation Layer:** Stateless / declarative widgets observing state.

---

## 5. Performance & Network Optimization

### 5.1 Consolidate Vitals & Observation Queries (FHIR Multi-Coding & Batching)
- **Current Limitation:** `PatientProfilePage._fetchData()` performs separate HTTP queries for:
  - Patient
  - Practitioner
  - Encounters
  - 10 individual LOINC observation codes (height, weight, ABO, Rh, temperature, blood pressure, heart rate, respiratory rate, oxygen saturation, BMI)
  This generates 13+ roundtrips over cellular connections sequentially or concurrently on launch.
- **Recommended Solution:**
  1. **Combined LOINC Query:** Query multiple LOINC codes in a single request:
     ```
     /Observation?patient={id}&code=8302-2,29463-7,883-9,10331-6,8310-5,55284-4,8867-4,9279-1,2708-6,39156-5&_sort=-date
     ```
  2. **FHIR Batch Bundle:** Combine Patient, Practitioner, Encounters, and latest Observations into a single FHIR `batch` POST request, reducing latency to a single roundtrip.

### 5.2 Local Caching & Offline Support
- Implement client-side caching (using Hive, Isar, or Drift) with a "Cache-First, Revalidate" strategy.
- When clinical data is fetched, save parsed resources locally with a sync timestamp.
- Allows patients to view their allergies, medications, and emergency health info even in cellular dead-zones (e.g., hospital elevators, underground clinics).

### 5.3 Asset Vectorization (SVG)
- Current PNG assets in `assets/images/icons/` (`lungs.png`, `blood-pressure.png`, `oxygen.png`, etc.) are rasterized at fixed resolutions.
- Converting to SVG (`flutter_svg`) ensures sharp rendering on high-DPI displays (xhdpi, xxhdpi, Retina) while reducing bundle size.

---

## 6. Data Visualization & Clinical UI/UX

### 6.1 Interactive Vital Sign & Lab Trends (`fl_chart`)
- `pubspec.yaml` already includes `fl_chart: ^1.1.1`, but it is currently unutilized.
- **Feature Additions:**
  - Make `_HealthDataTile` interactive (tappable).
  - Tapping Heart Rate, Blood Pressure, BMI, or Glucose displays a historical chart showing trend lines, reference ranges (normal vs. high/low zones), and date filters (1W, 1M, 6M, 1Y).
  - Show systolic/diastolic dual line charts with shaded target thresholds (< 120/80 mmHg).

### 6.2 Patient Encounters & Timeline Enhancements
- Expand the `timelines_plus` encounter view on `PatientProfilePage`:
  - Show attending practitioner names and clinic/hospital locations.
  - Support collapsing/expanding encounters to reveal related conditions and diagnostic reports tied to that encounter (`Encounter?_revinclude=DiagnosticReport:encounter`).

### 6.3 User Feedback & Modern UI Polish
- **Pull-to-Refresh:** Wrap `ListView` widgets in `RefreshIndicator` so users can pull down to sync with the server.
- **Skeleton Shimmer Loading:** Replace circular progress bars with modern shimmer cards during initial fetch.
- **Comprehensive Error Boundaries:** Show user-friendly error banners with "Retry" buttons if network calls drop.

---

## 7. Security & Protected Health Information (PHI) Safeguards

### 7.1 Remove Sensitive PHI & Token Logging
- **Vulnerability:** `lib/log.dart` logs full access tokens and OAuth URLs in plain text:
  ```dart
  log.i('auth url: $authUrl');
  log.i('token: $tokenData');
  ```
- **Remediation:**
  - Ensure logging levels are stripped in release builds (`kReleaseMode`).
  - Sanitize URLs and payloads to never log Bearer tokens, ID tokens, or raw patient identifiers in production logs.

### 7.2 Secure Credential Storage
- **Vulnerability:** Storing tokens or configuration in plain `SharedPreferences` leaves tokens vulnerable on rooted devices or Android backups.
- **Remediation:**
  - Store tokens, refresh tokens, and server secrets using `flutter_secure_storage` (backed by Android Keystore and iOS Keychain).
  - Set `android:allowBackup="false"` in `AndroidManifest.xml` for medical records compliance.

### 7.3 Biometric App Lock & Privacy Screen
- **Biometric Unlock:** Integrate `local_auth` to require Face ID / Fingerprint / PIN upon opening the app or after 5 minutes of background inactivity.
- **App Switcher Privacy:** Mask the screen when the app transitions to the background (`FLAG_SECURE` on Android or an overlay view on iOS) to prevent snapshots in the system app switcher containing sensitive clinical records.

---

## 8. Testing Strategy & Quality Assurance

### 8.1 Repair Existing Broken Test Suite
- `test/widget_test.dart` is currently broken (default template looking for non-existent `MyApp`).
- Replace it with a valid smoke test verifying `MainApp` launches `AuthPage` properly.

### 8.2 Comprehensive Test Pyramid

```
                ▲
               / \
              /   \
             / E2E \       Integration Tests (SMART Auth Mock Flow)
            /-------\
           / Widget  \     Component Tests (Cards, Timeline, PagedListView)
          /-----------\
         /    Unit     \   Calculations, FHIR Parsers, LOINC Extractors
        /---------------\
```

1. **Unit Tests:**
   - Patient age calculation across leap years and edge cases (`_patientAge()`).
   - Blood pressure component extraction (Systolic `8480-6` / Diastolic `8462-4`).
   - Blood type and Rh factor formatting.
   - FHIR Bundle link extraction (`relation == 'next'`).
2. **Widget Tests:**
   - `AuthPage` dropdown selection and custom URL persistence.
   - `_HealthDataTile` rendering correct units, values, and status tags.
   - `AllergyIntolerance` criticality badge color verification (`high` -> Red, etc.).
3. **Mock HTTP Tests:**
   - Mock FHIR server responses using `http.Client` mocks to test pagination, 401 token expiry handling, and 500 error banners.

---

## 9. Accessibility (a11y) & Internationalization (i18n)

### 9.1 Internationalization (i18n / l10n)
- Currently, all strings ("Profile", "Vital Signs", "Allergies & Intolerances", "HIGH RISK") are hardcoded in English.
- Because Clarity connects to Taiwan MoHW (`thas.mohw.gov.tw`) and serves both Taiwanese and international healthcare contexts:
  - Configure `flutter_localizations` and `.arb` translation files for `en` and `zh-TW` (Traditional Chinese).
  - Translate clinical terminology and status chips (`active` -> 進行中, `resolved` -> 已緩解).

### 9.2 Accessibility (a11y) & WCAG Compliance
- **Semantics:** Add `Semantics(label: ...)` to custom icons and timeline dots.
- **Minimum Tap Targets:** Ensure touchable icons in `_buildTopIconRow` satisfy the minimum 48x48 dp touch target recommendation.
- **Dynamic Type & Font Scaling:** Ensure patient names and vital sign text adapt gracefully without clipping when system accessibility font sizes (1.5x - 2.0x) are enabled.
- **Dark Mode Support:** Replace hardcoded `Colors.black`, `Colors.black54`, and `Colors.white` with semantic theme tokens (`Theme.of(context).colorScheme.onSurface`, `surfaceContainer`, etc.) to support Dark Theme seamlessly.

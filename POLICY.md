# Privacy Policy for Clarity (Personal Health Record)

**Effective Date:** October 24, 2026  
**Application ID / Package:** `app.kiddos.fhir.clarity`  
**Application Name:** Clarity  
**Repository:** [https://github.com/kiddos/clarity](https://github.com/kiddos/clarity)  
**Developer Contact:** `kiddo831007@gmail.com`

---

## 1. Introduction

Welcome to **Clarity** ("we", "our", or "the Application"). Clarity is an open-source Personal Health Record (PHR) mobile and cross-platform application developed to empower individuals and healthcare practitioners to directly access, view, and organize clinical health data using the **HL7® FHIR® (Fast Healthcare Interoperability Resources) Release 4** standard and the **SMART on FHIR** authorization framework.

Your privacy and the confidentiality of your Protected Health Information (PHI) and Personally Identifiable Information (PII) are our highest priority. This Privacy Policy explains our commitment to transparency, our privacy-by-design architecture, and how information is handled when you use Clarity.

---

## 2. Core Privacy Philosophy: Zero Intermediary Architecture

Clarity is built with a strict **client-to-endpoint direct architecture**:

- **No Proprietary Backend or Intermediary Servers:** We do not operate, maintain, or route your data through any proprietary cloud servers, intermediate relays, or databases.
- **Direct Communication:** When you log in, your device establishes a direct, encrypted connection (HTTPS/TLS) exclusively between the Clarity client running locally on your device and the FHIR server or Electronic Health Record (EHR) system authorized and selected by you (e.g., the Taiwan Ministry of Health and Welfare THAS platform, SMART Health IT sandbox, or your healthcare provider's FHIR endpoint).
- **We Never See Your Data:** The developers and maintainers of Clarity do not collect, intercept, inspect, store, monetize, or transmit your medical records, demographic details, or authentication credentials to any third-party or developer-controlled infrastructure.

---

## 3. Information the Application Accesses and Processes

Clarity functions as a secure, client-side viewer. Depending on the permissions granted by you and your healthcare institution during the SMART on FHIR OAuth authorization flow, the application may retrieve and display the following categories of clinical and administrative data:

### A. Demographic and Profile Information
- **Patient Identifiers & Demographics:** Patient full name, gender, birth date, and calculated age.
- **Practitioner Information:** Attending provider name, role, and identifier parsed from the OpenID Connect / SMART `id_token` (`fhirUser` claim) or FHIR `Practitioner` resource.

### B. Health and Medical Records (Protected Health Information)
- **Vital Signs (`Observation`):** Blood pressure (systolic and diastolic), heart rate, respiratory rate, body temperature, oxygen saturation ($SpO_2$), body height, body weight, Body Mass Index (BMI), and ABO/Rh blood groups.
- **Laboratory Results (`Observation`):** Diagnostic lab panels, test names, quantitative values, measurement units, reference ranges, and abnormal/interpretation flags.
- **Conditions & Diagnoses (`Condition`):** Medical problems, active and resolved diagnoses, clinical status, and verification status.
- **Medications (`MedicationRequest`):** Active prescriptions, historical medications, dosages, administration routes, and prescribing dates.
- **Allergies & Intolerances (`AllergyIntolerance`):** Food, drug, and environmental allergies, criticality ratings (High, Low, Unable-to-assess), verification statuses, and reaction manifestations.
- **Vaccinations (`Immunization`):** Immunization history, vaccine codes, administration dates, lot numbers, and target pathogens.
- **Diagnostic Reports (`DiagnosticReport`):** Diagnostic study summaries, report categories, status, and clinical conclusions.
- **Clinical Encounters (`Encounter`):** Chronological timeline of clinical visits, consultations, admission dates, encounter classes, and statuses.

### C. Authentication Credentials & Session Data
- **OAuth 2.0 Tokens:** Temporary bearer access tokens (`access_token`), identity tokens (`id_token`), refresh tokens (if issued), and FHIR patient identifier scopes (`patient`).
- **Storage & Lifecycle:** Authentication tokens and clinical data are held exclusively in **volatile runtime memory (RAM)** during your active application session. They are never written to unencrypted persistent disk storage or uploaded to any remote server other than the authenticating FHIR endpoint.

### D. Local App Preferences
- **Custom FHIR Server URLs:** If you choose to add custom FHIR server endpoints, these URL strings are saved locally on your device via standard local storage (`SharedPreferences`) for convenience. No personal health information or credentials are stored within these preferences.

---

## 4. How Your Information Is Used

Data accessed through Clarity is used strictly for the following purposes:
1. **Clinical Visualization:** Rendering your personal medical records, vital trends, and healthcare timeline directly on your screen.
2. **Authentication & Authorization:** Exchanging authorization codes for access tokens with your chosen healthcare provider's OAuth 2.0 authorization server.
3. **FHIR Querying:** Sending authenticated HTTPS REST requests to your chosen FHIR server to retrieve requested FHIR R4 resources.

We **do not**:
- Sell, rent, lease, or commercialize your personal or health data.
- Use your data for advertising, marketing, profiling, or behavioral analytics.
- Use your health data to train artificial intelligence or machine learning models.
- Merge your health records with any third-party data broker information.

---

## 5. Third-Party Services, SDKs, and Analytics

- **No Third-Party Analytics:** Clarity does **not** include Google Analytics, Firebase Analytics, Mixpanel, Segment, or any other user tracking or behavioral telemetry tools.
- **No Advertising SDKs:** Clarity is completely ad-free and contains no advertising networks or trackers.
- **No Crash Tracking Telemetry:** Crash or debug logs are printed solely to local system logs (`logcat` / console) for development and are not uploaded to remote servers.
- **External Healthcare Providers:** When you authenticate with an external healthcare server or identity provider, your interaction with their login portal is subject to that respective institution’s terms of service and privacy policy.

---

## 6. Device Permissions and Network Usage

Clarity requests only the minimal device permissions strictly required to perform its functions:

| Permission | Technical Name | Reason for Use |
| :--- | :--- | :--- |
| **Internet Access** | `android.permission.INTERNET` | Required to communicate over secure HTTPS with your selected SMART on FHIR server and OAuth authorization endpoints. |
| **Deep Linking / URL Scheme** | `clarity.kiddos.app://callback` | Used by the system browser / custom tabs (`flutter_web_auth_2`) to return the OAuth authorization code securely to the app upon successful login. |

Clarity does **not** request access to your device camera, microphone, contacts, location, calendar, phone state, or external shared storage.

---

## 7. Data Storage, Retention, and Deletion

- **Session-Only Health Data:** All patient records, observation values, laboratory results, and authentication tokens exist only in temporary device memory. When you close the app or navigate away, this data is cleared from memory by the operating system.
- **User Control Over Configuration:** Custom server URLs saved in local device storage can be removed directly within the application settings or by clearing the application storage/cache in your device settings.
- **Source Health Records:** Because Clarity is a client-side viewer and does not hold a copy of your medical records on an external server, requests to view, update, correct, or delete original health records must be submitted directly to the healthcare provider or health system managing the FHIR server.

---

## 8. Data Security and Safeguards

We implement industry-standard best practices to protect your health information:
- **Encrypted Transport:** All communication between Clarity and FHIR servers is mandated to use secure Transport Layer Security (TLS 1.2+ / HTTPS), preventing eavesdropping and man-in-the-middle attacks.
- **Ephemeral Web Authentication:** Web authentication flows leverage secure system custom tabs with ephemeral sessions (`preferEphemeral: true`) to prevent persistent cookie storage where supported.
- **Zero Local Caching of PHI:** Clinical records are not cached to disk or database files on the device, minimizing risk in the event of device loss or unauthorized physical access.
- **No Token Logging in Production:** The application is architected to prevent exposing sensitive bearer tokens in logs during release builds.

---

## 9. Children's Privacy

Clarity is not directed to children under the age of 13 (or under the age of 16 in the European Union). We do not knowingly collect personal information directly from children. Parents or legal guardians authorized by healthcare institutions to view their dependents' pediatric health records may do so using their authenticated provider-issued credentials under the authority of their healthcare system.

---

## 10. Regulatory and Legal Compliance

### A. HIPAA (Health Insurance Portability and Accountability Act)
Clarity functions as an un-tethered, standalone Personal Health Record application configured directly by the individual user. Because Clarity does not create, receive, maintain, or transmit Protected Health Information on behalf of a Covered Entity as a vendor or Business Associate, Clarity operates as a client tool under the patient's individual right of access.

### B. GDPR and International Data Protection (e.g., Taiwan PDPA)
Under regulations such as the General Data Protection Regulation (GDPR) and the Taiwan Personal Data Protection Act (PDPA):
- **Data Minimization & Purpose Limitation:** Data accessed is strictly limited to what is requested to render the user interface.
- **Right to Portability & Access:** Clarity leverages open HL7 FHIR standards to empower user data portability.
- **No Automated Profiling:** The application performs no profiling or automated decision-making.

### C. Google Play Health Apps and Sensitive Data Policy
Clarity strictly complies with Google Play's Health Apps and Sensitive Data policies:
- Health data is processed solely for personal health record viewing.
- No health data is shared with third parties, brokers, or advertising networks.
- Prominent disclosure and in-app authorization consent are required before connecting to any clinical endpoint.

---

## 11. Open Source Transparency

Clarity is distributed under the open-source **MIT License**. The complete source code is publicly accessible and auditable on GitHub:
👉 [https://github.com/kiddos/clarity](https://github.com/kiddos/clarity)

Independent researchers, healthcare organizations, and users are welcome to review the codebase to verify that our privacy and security implementations strictly adhere to the commitments made in this policy.

---

## 12. Medical Disclaimer

> **IMPORTANT NOTICE:**  
> Clarity is provided for informational, educational, and personal record organization purposes only. It is **not** a certified medical device and is **not** intended for use in the diagnosis, cure, mitigation, treatment, or prevention of disease or other conditions. Always seek the advice of a physician or other qualified health provider with any questions you may have regarding a medical condition or treatment plan. Never disregard professional medical advice or delay seeking it because of information viewed in this application.

---

## 13. Changes to This Privacy Policy

We may update this Privacy Policy periodically to reflect enhancements to the application, new FHIR resource capabilities, or regulatory changes. Any modifications will be posted to this repository with an updated "Effective Date". We encourage users to review this document periodically.

---

## 14. Contact and Inquiries

If you have questions, feedback, or concerns regarding this Privacy Policy or the security practices of Clarity, please contact us:

- **Maintainer / Developer:** kiddos
- **Email:** [kiddo831007@gmail.com](mailto:kiddo831007@gmail.com)
- **GitHub Issues:** [https://github.com/kiddos/clarity/issues](https://github.com/kiddos/clarity/issues)

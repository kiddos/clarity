import 'package:fhir/r4.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timelines_plus/timelines_plus.dart';
import 'dart:convert';

import 'log.dart';
import 'patient_lab_page.dart';
import 'patient_medication_page.dart';
import 'patient_condition_page.dart';
import 'patient_allergy_page.dart';
import 'patient_vaccination_page.dart';
import 'patient_diagnostic_report_page.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

typedef ObsesrvationCallback = void Function(Observation obs);

class _PatientProfilePageState extends State<PatientProfilePage> {
  Patient? patient;
  Practitioner? practitioner;
  Observation? weight;
  Observation? height;
  Observation? aboGroup;
  Observation? rhGroup;
  Observation? temperature;
  Observation? bloodPressure;
  Observation? heartRate;
  Observation? respiratoryRate;
  Observation? oxygenSaturation;
  Observation? bmi;
  List<Encounter> _encounter = [];

  @override
  void initState() {
    super.initState();

    _fetchData();
  }

  Future<void> _fetchPatientData(String patientId, String accessToken) async {
    final String query = "${widget.requestUrl}/Patient/$patientId";
    try {
      final response = await http.get(
        Uri.parse(query),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/fhir+json',
        },
      );

      if (response.statusCode == 200) {
        final Patient p = Patient.fromJsonString(response.body);
        setState(() => patient = p);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      log.e('fail to fetch patient data', error: e);
    }
  }

  Future<void> _fetchFhirUser(String idToken, String accessToken) async {
    List<String> parts = idToken.split(".");
    if (parts.length < 2) {
      return;
    }

    // id token consists of three parts separated by dots: Header.Payload.Signature
    String normalized = parts[1];
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }

    String jsonPayload = utf8.decode(base64.decode(normalized));
    final payload = jsonDecode(jsonPayload);
    String? fhirUser = payload['fhirUser'];
    if (fhirUser == null) {
      return;
    }

    final String query = "${widget.requestUrl}/$fhirUser";
    try {
      final response = await http.get(
        Uri.parse(query),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/fhir+json',
        },
      );

      if (response.statusCode == 200) {
        Practitioner p = Practitioner.fromJsonString(response.body);
        setState(() => practitioner = p);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      log.e('fail to fetch patient data', error: e);
    }
  }

  void _fetchData() async {
    log.i('fetch data...');
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    final idToken = widget.tokenData['id_token'];
    if (patient != null && accessToken != null) {
      await _fetchPatientData(patient, accessToken);
      await _fetchFhirUser(idToken, accessToken);
      await _fetchEncounter(patient, accessToken);
      final codes = [
        '8302-2', // height
        '29463-7', // weight
        '883-9', // abo
        '10331-6', // rh
        '8310-5', // temperature
        '55284-4', // blood pressure
        '8867-4', //heart rate
        '9279-1', // respiratory rate
        '2708-6', // 59408-5
        '39156-5', // bmi
      ];
      final List<ObsesrvationCallback> callbacks = [
        (Observation o) {
          setState(() => height = o);
        },
        (Observation o) {
          setState(() => weight = o);
        },
        (Observation o) {
          setState(() => aboGroup = o);
        },
        (Observation o) {
          setState(() => rhGroup = o);
        },
        (Observation o) {
          setState(() => temperature = o);
        },
        (Observation o) {
          setState(() => bloodPressure = o);
        },
        (Observation o) {
          setState(() => heartRate = o);
        },
        (Observation o) {
          setState(() => respiratoryRate = o);
        },
        (Observation o) {
          setState(() => oxygenSaturation = o);
        },
        (Observation o) {
          setState(() => bmi = o);
        },
      ];
      for (int i = 0; i < codes.length; ++i) {
        _fetchPatientObservation(patient, accessToken, codes[i], callbacks[i]);
      }
    }
  }

  Future<void> _fetchEncounter(String patient, String accessToken) async {
    final url = "${widget.requestUrl}/Encounter?patient=$patient&_sort=-date";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/fhir+json',
      },
    );

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        final bundle = Bundle.fromJson(data);
        List<Encounter> encounters = [];
        bundle.entry?.forEach((entry) {
          if (entry.resource is Encounter) {
            encounters.add(entry.resource as Encounter);
          }
        });
        setState(() => _encounter = encounters);
      } catch (e) {
        log.e('fail to fetch enounter', error: e);
      }
    }
  }

  void _fetchPatientObservation(String patientId, String accessToken,
      String loinc, ObsesrvationCallback callback) async {
    final String query =
        "${widget.requestUrl}/Observation?patient=$patientId&code=$loinc&_sort=-date&_count=1&_total=none";
    try {
      final response = await http.get(
        Uri.parse(query),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/fhir+json',
        },
      );

      if (response.statusCode == 200) {
        final Bundle b = Bundle.fromJsonString(response.body);
        b.entry?.forEach((BundleEntry entry) {
          if (entry.resource != null && entry.resource is Observation) {
            Observation o = entry.resource as Observation;
            callback(o);
          }
        });
        setState(() => {});
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      log.e('fail to fetch patient observation', error: e);
    }
  }

  // String _patientGivenName() {
  //   String name = "";
  //   patient?.name?.take(1).forEach((HumanName humanName) {
  //     name = "${humanName.given?[0]}";
  //   });
  //   return name;
  // }

  String _patientFullName() {
    String name = "";
    patient?.name?.take(1).forEach((HumanName humanName) {
      name =
          "${humanName.prefix?[0]} ${humanName.given?[0]} ${humanName.family}";
    });
    return name;
  }

  String _pratitionerFamilyName() {
    String name = "";
    practitioner?.name?.take(1).forEach((HumanName humanName) {
      final prefix = humanName.prefix ?? [];
      final prefixName = prefix.isNotEmpty ? '${prefix[0]} ' : '';
      name = "$prefixName ${humanName.given?[0]}";
    });
    return name;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen =
        Color(0xFF5BAA52); // A vibrant green close to the image
    const Color lightGreen = Color(0xFFC8E6C9);
    final practitionerName = _pratitionerFamilyName();

    return Scaffold(
      appBar: AppBar(
        // Custom leading icon that looks like the app logo
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Icon(
            Icons.circle_outlined,
            color: primaryGreen,
            size: 30,
          ),
        ),
        leadingWidth: 50,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // User icon
          const Icon(
            Icons.person_outline,
            color: Colors.black54,
            size: 24,
          ),
          const SizedBox(width: 4),
          Text(
            practitionerName,
            style: const TextStyle(color: Colors.black),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: <Widget>[
          // Top Icon Row (Labs, Meds, Conditions...)
          _buildTopIconRow(primaryGreen),
          const SizedBox(height: 20),

          //  User Info Section
          _buildUserInfoSection(primaryGreen),
          const SizedBox(height: 20),

          // Health Data Widgets
          _buildHealthDataList(primaryGreen, lightGreen),
          const SizedBox(height: 20),

          _buildEncounterListView(),
        ],
      ),
    );
  }

  void _handleLab() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientObservationPage(
          title: 'Patient Lab Results',
          category: 'laboratory',
          requestUrl: widget.requestUrl,
          tokenData: widget.tokenData,
        ),
      ),
    );
  }

  void _handleVital() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientObservationPage(
          title: 'Patient Vital signs',
          category: 'vital-signs',
          requestUrl: widget.requestUrl,
          tokenData: widget.tokenData,
        ),
      ),
    );
  }

  void _handleMedication() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientMedicationPage(
          requestUrl: widget.requestUrl,
          tokenData: widget.tokenData,
        ),
      ),
    );
  }

  void _handleCondition() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientConditionPage(
          requestUrl: widget.requestUrl,
          tokenData: widget.tokenData,
        ),
      ),
    );
  }

  void _handleAllergy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientAllergyPage(
          requestUrl: widget.requestUrl,
          tokenData: widget.tokenData,
        ),
      ),
    );
  }

  void _handleVaccine() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientVaccinationPage(
          requestUrl: widget.requestUrl,
          tokenData: widget.tokenData,
        ),
      ),
    );
  }

  void _handleEncounter() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDiagnosticReportPage(
          requestUrl: widget.requestUrl,
          tokenData: widget.tokenData,
        ),
      ),
    );
  }

  Widget _buildTopIconRow(Color primaryGreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _IconCard(
          icon: Icons.science_outlined,
          label: 'Labs',
          color: primaryGreen,
          onTap: _handleLab,
        ),
        _IconCard(
          icon: Icons.assignment_ind,
          label: 'Vital',
          color: primaryGreen,
          onTap: _handleVital,
        ),
        _IconCard(
          icon: Icons.medication_outlined,
          label: 'Meds',
          color: primaryGreen,
          onTap: _handleMedication,
        ),
        _IconCard(
          icon: Icons.sick_outlined,
          label: 'Conditions',
          color: primaryGreen,
          onTap: _handleCondition,
        ),
        _IconCard(
          icon: Icons.flare_outlined,
          label: 'Allergies',
          color: primaryGreen,
          onTap: _handleAllergy,
        ),
        _IconCard(
          icon: Icons.vaccines_outlined,
          label: 'Vaccines',
          color: primaryGreen,
          onTap: _handleVaccine,
        ),
        _IconCard(
          icon: Icons.event_note_outlined,
          label: 'Report',
          color: primaryGreen,
          onTap: _handleEncounter,
        ),
        // _IconCard(
        //   icon: Icons.mediation_outlined,
        //   label: 'Genetics',
        //   color: primaryGreen,
        //   onTap: () {},
        // ),
      ],
    );
  }

  String _patientAge() {
    String bd = patient?.birthDate.toString() ?? '';
    DateTime? birthDate = DateTime.tryParse(bd);
    if (birthDate == null) {
      return "";
    }
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }

    DateTime lastBirthday;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      lastBirthday = DateTime(now.year - 1, birthDate.month, birthDate.day);
    } else {
      lastBirthday = DateTime(now.year, birthDate.month, birthDate.day);
    }
    final difference = now.difference(lastBirthday);
    final days = difference.inDays;
    return '$bd ($years yrs • $days days)';
  }

  String _patientHeight() {
    if (height == null) {
      return "";
    }
    final value = height?.valueQuantity?.value?.valueNumber?.toStringAsFixed(2);
    final unit = height?.valueQuantity?.unit;
    String heightText = "Height: $value $unit";
    return heightText;
  }

  String _patientWeight() {
    final value = weight?.valueQuantity?.value?.valueNumber?.toStringAsFixed(2);
    final unit = weight?.valueQuantity?.unit;
    String weightText = "Weight: $value $unit";
    return weightText;
  }

  String _patientBloodType() {
    final abo = aboGroup?.text;
    String rh = "";
    if ((rhGroup?.text ?? '') == "Positive") {
      rh = "+";
    } else if ((rhGroup?.text ?? '') == "Negative") {
      rh = "-";
    }
    return '$abo $rh';
  }

  String formatDateTime(FhirDateTime? d) {
    DateTime? dt = DateTime.tryParse(d?.toIso8601String() ?? '');
    if (dt == null) {
      return "N/A";
    }
    final format = DateFormat("yyyy-MM-dd");
    return format.format(dt);
  }

  Widget _buildUserInfoSection(Color primaryGreen) {
    final fullName = _patientFullName();
    final age = _patientAge();
    final heightText = _patientHeight();
    final weightText = _patientWeight();
    final bloodTypeText = _patientBloodType();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Text(
                    fullName,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  age,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (height != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          heightText,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (weight != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          weightText,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (aboGroup != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          bloodTypeText,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthDataList(Color primaryGreen, Color lightGreen) {
    final systolic = bloodPressure?.component
        ?.firstWhere((c) => c.code.coding?[0].code.toString() == "8480-6");
    final diastolic = bloodPressure?.component
        ?.firstWhere((c) => c.code.coding?[0].code.toString() == "8462-4");
    return Column(
      children: <Widget>[
        Row(
          children: [
            Image.asset('assets/images/icons/vital-signs.png',
                width: 26, height: 26),
            const SizedBox(width: 10),
            const Text(
              'Vital Signs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (heartRate != null)
          _HealthDataTile(
            icon: Image.asset('assets/images/icons/heart-rate.png',
                width: 24, height: 24),
            title: 'Heart Rate',
            subtitle: formatDateTime(heartRate?.effectiveDateTime),
            value: heartRate?.valueQuantity?.value?.valueNumber
                    ?.toStringAsFixed(2) ??
                'N/A',
            unit: heartRate?.valueQuantity?.unit ?? 'N/A',
            textColor: Colors.black,
          ),
        if (bloodPressure != null)
          _HealthDataTile(
            icon: Image.asset('assets/images/icons/blood-pressure.png',
                width: 24, height: 24),
            title: 'Blood Pressure',
            subtitle: formatDateTime(bloodPressure?.effectiveDateTime),
            value: systolic != null
                ? '${systolic.valueQuantity?.value?.valueNumber?.toInt()}/${diastolic?.valueQuantity?.value?.valueNumber?.toInt()}'
                : 'N/A',
            unit: systolic?.valueQuantity?.unit ?? 'N/A',
            textColor: Colors.black,
          ),
        if (respiratoryRate != null)
          _HealthDataTile(
            icon: Image.asset('assets/images/icons/lungs.png',
                width: 24, height: 24),
            title: 'Respiratory Rate',
            subtitle: formatDateTime(respiratoryRate?.effectiveDateTime),
            value: respiratoryRate?.valueQuantity?.value?.valueNumber
                    ?.toStringAsFixed(2) ??
                'N/A',
            unit: respiratoryRate?.valueQuantity?.unit ?? 'N/A',
            textColor: Colors.black,
          ),
        if (oxygenSaturation != null)
          _HealthDataTile(
            icon: Image.asset('assets/images/icons/oxygen.png',
                width: 24, height: 24),
            title: 'Oxygen Saturation',
            subtitle: formatDateTime(oxygenSaturation?.effectiveDateTime),
            value: oxygenSaturation?.valueQuantity?.value?.valueNumber
                    ?.toStringAsFixed(2) ??
                'N/A',
            unit: oxygenSaturation?.valueQuantity?.unit ?? 'N/A',
            textColor: Colors.black,
          ),
        if (bmi != null)
          _HealthDataTile(
            icon: Image.asset('assets/images/icons/bmi.png',
                width: 24, height: 24),
            title: 'BMI',
            subtitle: formatDateTime(bmi?.effectiveDateTime),
            value: bmi?.valueQuantity?.value?.valueNumber?.toStringAsFixed(2) ??
                'N/A',
            unit: bmi?.valueQuantity?.unit ?? 'N/A',
            textColor: Colors.black,
          ),
      ],
    );
  }

  Widget _buildEncounterListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/images/icons/encounter.png',
                width: 26, height: 26),
            const SizedBox(width: 10),
            const Text(
              'Encounter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FixedTimeline.tileBuilder(
          theme: TimelineThemeData(
            nodePosition: 0, // Aligns the line to the left
            connectorTheme: ConnectorThemeData(
              thickness: 3.0,
              color: Colors.indigo.shade100,
            ),
            indicatorTheme: const IndicatorThemeData(
              size: 20.0,
            ),
          ),
          builder: TimelineTileBuilder.connected(
            itemCount: _encounter.length,
            contentsBuilder: (context, index) {
              final e = _encounter[index];
              String visitClass = e.class_.display ?? 'General visit';
              String visitType = e.type?[0].text ?? "Standard Consultation";
              String startDate = formatDateTime(e.period?.start);
              String status = e.status.toString();

              return Padding(
                padding: const EdgeInsets.only(left: 12.0, bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            visitType,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Class: $visitClass",
                        style: TextStyle(color: Colors.grey.shade700)),
                    Text("Date: $startDate",
                        style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              );
            },
            indicatorBuilder: (context, index) {
              return const DotIndicator(
                color: Colors.indigo,
                child: Icon(Icons.event_note, size: 12, color: Colors.white),
              );
            },
            connectorBuilder: (context, index, type) {
              return SolidLineConnector(color: Colors.indigo.shade100);
            },
          ),
        ),
      ],
    );
  }

  // Helper for the status tag
  Widget _buildStatusChip(String status) {
    bool isFinished = status == 'finished';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFinished ? Colors.green.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isFinished ? Colors.green.shade900 : Colors.blue.shade900,
        ),
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IconCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return InkWell(
      customBorder: RoundedRectangleBorder(
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: borderRadius,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _HealthDataTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final String value;
  final String unit;
  final Color textColor;

  const _HealthDataTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 15),
          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Value & Unit
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 16),
              children: <TextSpan>[
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }
}

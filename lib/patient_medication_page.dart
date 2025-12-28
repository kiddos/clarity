import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PatientMedicationPage extends StatefulWidget {
  const PatientMedicationPage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientMedicationPage> createState() => _PatientMedicationPageState();
}

class _PatientMedicationPageState extends State<PatientMedicationPage> {
  Future<List<dynamic>> fetchMedications() async {
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    // Querying MedicationRequest for a specific patient
    final url =
        "${widget.requestUrl}/MedicationRequest?patient=$patient&_sort=-authoredon";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/fhir+json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['entry'] ?? [];
    } else {
      throw Exception('Failed to load medication data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medications")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchMedications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No medications found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final resource = snapshot.data![index]['resource'];

              // 1. Extract Medication Name (Handles both CodeableConcepts and References)
              String medName = "Unknown Medication";
              if (resource['medicationCodeableConcept'] != null) {
                medName = resource['medicationCodeableConcept']['text'] ??
                    resource['medicationCodeableConcept']['coding']?[0]
                        ['display'] ??
                    "Unknown";
              }

              // 2. Extract Dosage instructions
              String instructions = "No instructions provided";
              if (resource['dosageInstruction'] != null &&
                  resource['dosageInstruction'].isNotEmpty) {
                instructions =
                    resource['dosageInstruction'][0]['text'] ?? "As directed";
              }

              // 3. Extract Status (active, completed, stopped, etc.)
              String status = resource['status'] ?? "unknown";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.medication, color: Colors.redAccent),
                  title: Text(medName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Instructions: $instructions"),
                      const SizedBox(height: 4),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? Colors.green[100]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'active'
                                  ? Colors.green[800]
                                  : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

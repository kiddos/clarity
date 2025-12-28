import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PatientVaccinationPage extends StatefulWidget {
  const PatientVaccinationPage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientVaccinationPage> createState() => _PatientVaccinationPageState();
}

class _PatientVaccinationPageState extends State<PatientVaccinationPage> {
  Future<List<dynamic>> fetchVaccinations() async {
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    final url =
        "${widget.requestUrl}/Immunization?patient=$patient&_sort=-date";
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
      throw Exception('Failed to load vaccination data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vaccination History")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchVaccinations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No vaccinations found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final resource = snapshot.data![index]['resource'];

              // 1. Vaccine Name
              String vaccineName = resource['vaccineCode']?['text'] ??
                  resource['vaccineCode']?['coding']?[0]['display'] ??
                  "Unknown Vaccine";

              // 2. Date Administered
              String date = resource['occurrenceDateTime']?.split('T')[0] ??
                  resource['occurrenceString'] ??
                  "Unknown date";

              // 3. Status (completed, entered-in-error, not-done)
              String status = resource['status'] ?? "unknown";

              // 4. Site/Route (Optional info)
              String site = resource['site']?['coding']?[0]['display'] ?? "";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: const Icon(Icons.vaccines, color: Colors.teal),
                  ),
                  title: Text(vaccineName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Administered: $date"),
                      if (site.isNotEmpty) Text("Site: $site"),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      status.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor:
                        status == 'completed' ? Colors.teal : Colors.grey,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

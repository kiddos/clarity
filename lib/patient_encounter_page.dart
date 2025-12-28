import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Helpful for date formatting

class PatientEncounterPage extends StatefulWidget {
  const PatientEncounterPage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientEncounterPage> createState() => _PatientEncounterPageState();
}

class _PatientEncounterPageState extends State<PatientEncounterPage> {
  Future<List<dynamic>> fetchEncounters() async {
    // Sorting by date descending to see most recent visits first
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    final url = "${widget.requestUrl}/Encounter?patient=$patient&_sort=-date";
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
      throw Exception('Failed to load encounter data');
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return "N/A";
    DateTime dt = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Clinical Encounters")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchEncounters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No encounter history found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final resource = snapshot.data![index]['resource'];

              // 1. Visit Class (Inpatient, Outpatient, Emergency, etc.)
              String visitClass =
                  resource['class']?['display'] ?? "General Visit";

              // 2. Visit Type (Detailed reason or specialty)
              String visitType = resource['type']?[0]?['text'] ??
                  resource['type']?[0]?['coding']?[0]['display'] ??
                  "Standard Consultation";

              // 3. Period (Start and End dates)
              String startDate = formatDate(resource['period']?['start']);

              // 4. Status (planned, arrived, triaged, in-progress, finished)
              String status = resource['status'] ?? "unknown";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: const Icon(Icons.event_note, color: Colors.indigo),
                  ),
                  title: Text(visitType,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Class: $visitClass"),
                      Text("Date: $startDate"),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'finished'
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status == 'finished'
                              ? Colors.green.shade900
                              : Colors.blue.shade900),
                    ),
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

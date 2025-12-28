import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PatientConditionPage extends StatefulWidget {
  const PatientConditionPage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientConditionPage> createState() => _PatientConditionPageState();
}

class _PatientConditionPageState extends State<PatientConditionPage> {
  Future<List<dynamic>> fetchConditions() async {
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    // Fetching conditions for the patient
    final url = "${widget.requestUrl}/Condition?patient=$patient";
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
      throw Exception('Failed to load condition data');
    }
  }

  // Helper to determine status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medical Conditions")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchConditions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No medical conditions recorded."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final resource = snapshot.data![index]['resource'];

              // Extracting Condition Name
              String conditionName = resource['code']?['text'] ??
                  resource['code']?['coding']?[0]['display'] ??
                  "Unspecified Diagnosis";

              // Extracting Clinical Status (active, resolved, inactive, etc.)
              String status = resource['clinicalStatus']?['coding']?[0]
                      ['code'] ??
                  "unknown";

              // Extracting Recorded Date
              String recordedDate = resource['recordedDate']?.split('T')[0] ??
                  "Date not recorded";

              // Extracting Severity (if available)
              String severity =
                  resource['severity']?['coding']?[0]['display'] ?? "";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    child: Icon(Icons.healing, color: _getStatusColor(status)),
                  ),
                  title: Text(conditionName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Recorded on: $recordedDate"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (severity.isNotEmpty)
                        Text(
                          severity,
                          style: const TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
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

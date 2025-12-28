import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PatientLabPage extends StatefulWidget {
  const PatientLabPage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientLabPage> createState() => _PatientLabPageState();
}

class _PatientLabPageState extends State<PatientLabPage> {
  Future<List<dynamic>> fetchLabResults() async {
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    // We filter Observations by patient ID and the 'laboratory' category
    final url =
        "${widget.requestUrl}/Observation?patient=$patient&category=laboratory&_sort=-date";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/fhir+json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // FHIR search results are returned in a 'entry' list
      return data['entry'] ?? [];
    } else {
      throw Exception('Failed to load lab data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Patient Lab Results")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchLabResults(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No lab results found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final observation = snapshot.data![index]['resource'];

              // Extracting data safely from FHIR JSON
              String testName = observation['code']?['text'] ?? "Unknown Test";
              String value =
                  observation['valueQuantity']?['value']?.toStringAsFixed(3) ?? "N/A";
              String unit = observation['valueQuantity']?['unit'] ?? "";
              String date =
                  observation['effectiveDateTime']?.split('T')[0] ?? "No date";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.science, color: Colors.blue),
                  title: Text(testName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Date: $date"),
                  trailing: Text(
                    "$value $unit",
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
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

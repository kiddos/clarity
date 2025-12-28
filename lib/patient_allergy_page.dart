import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PatientAllergyPage extends StatefulWidget {
  const PatientAllergyPage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientAllergyPage> createState() => _PatientAllergyPageState();
}

class _PatientAllergyPageState extends State<PatientAllergyPage> {
  Future<List<dynamic>> fetchAllergies() async {
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    final url = "${widget.requestUrl}/AllergyIntolerance?patient=$patient";
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
      throw Exception('Failed to load allergy data');
    }
  }

  // Highlights high-risk allergies
  Color _getCriticalityColor(String? criticality) {
    switch (criticality?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'unable-to-assess':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Allergies & Intolerances")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchAllergies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No allergies reported."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final resource = snapshot.data![index]['resource'];

              // 1. Substance Name
              String substance = resource['code']?['text'] ??
                  resource['code']?['coding']?[0]['display'] ??
                  "Unknown Substance";

              // 2. Category (food, medication, environment, biologic)
              List<dynamic>? categories = resource['category'];
              String categoryText = categories?.join(", ") ?? "Other";

              // 3. Criticality (low, high, unable-to-assess)
              String? criticality = resource['criticality'];

              // 4. Verification Status (confirmed vs unconfirmed)
              String verification = resource['verificationStatus']?['coding']
                      ?[0]['code'] ??
                  "unconfirmed";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: _getCriticalityColor(criticality),
                    size: 30,
                  ),
                  title: Text(substance,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Category: ${categoryText[0].toUpperCase()}${categoryText.substring(1)}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (criticality == 'high')
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text("HIGH RISK",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 4),
                      Text(verification,
                          style: const TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic)),
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

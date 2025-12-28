import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PatientDiagnosticReportPage extends StatefulWidget {
  const PatientDiagnosticReportPage({
    super.key,
    required this.requestUrl,
    required this.tokenData,
  });

  final String requestUrl;
  final Map<String, dynamic> tokenData;

  @override
  State<PatientDiagnosticReportPage> createState() =>
      _PatientDiagnosticReportPageState();
}

class _PatientDiagnosticReportPageState
    extends State<PatientDiagnosticReportPage> {
  Future<List<dynamic>> fetchReports() async {
    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];
    final url = Uri.parse(
        "${widget.requestUrl}/DiagnosticReport?patient=$patient&_sort=-date");

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/fhir+json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['entry'] ?? [];
    } else {
      throw Exception('Failed to load diagnostic reports');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'final':
        return Colors.green;
      case 'preliminary':
        return Colors.orange;
      case 'corrected':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Diagnostic Reports")),
      body: FutureBuilder<List<dynamic>>(
        future: fetchReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No diagnostic reports found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final report = snapshot.data![index]['resource'];

              // 1. Report Title
              String title = report['code']?['text'] ??
                  report['code']?['coding']?[0]['display'] ??
                  "Unnamed Report";

              // 2. Category (Lab, Radiology, etc.)
              String category =
                  report['category']?[0]?['coding']?[0]['display'] ?? "General";

              // 3. Date (effectiveDateTime or issued)
              String dateRaw =
                  report['effectiveDateTime'] ?? report['issued'] ?? "";
              String dateFormatted = dateRaw.isNotEmpty
                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(dateRaw))
                  : "Date Unknown";

              // 4. Status
              String status = report['status'] ?? "unknown";

              // 5. Result Count (Number of observations inside this report)
              int resultCount = (report['result'] as List?)?.length ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.toLowerCase().contains('lab')
                        ? Colors.purple.shade50
                        : Colors.orange.shade50,
                    child: Icon(
                      category.toLowerCase().contains('lab')
                          ? Icons.science
                          : Icons.settings_remote,
                      color: category.toLowerCase().contains('lab')
                          ? Colors.purple
                          : Colors.orange,
                    ),
                  ),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "$category • $dateFormatted\n$resultCount associated results"),
                  isThreeLine: true,
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () {
                    // Navigate to details to see the specific Observations (results)
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

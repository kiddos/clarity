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
  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _medications = [];
  String? _nextPageUrl;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchNextPage(initial: true);

    _scrollController.addListener(() {
      // Trigger load when user reaches 90% of the scroll height
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        if (!_isLoading && _hasMore) {
          _fetchNextPage();
        }
      }
    });
  }

  Future<void> _fetchNextPage({bool initial = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final patient = widget.tokenData['patient'];
    final accessToken = widget.tokenData['access_token'];

    // Initial URL or the next page URL provided by FHIR bundle
    final url = initial
        ? "${widget.requestUrl}/MedicationRequest?patient=$patient&_sort=-authoredon&_count=10"
        : _nextPageUrl;

    if (url == null) {
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/fhir+json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newEntries = data['entry'] ?? [];

        // Find the "next" relation link in the Bundle
        final links = data['link'] as List<dynamic>?;
        final nextLink = links?.firstWhere((l) => l['relation'] == 'next',
            orElse: () => null);

        setState(() {
          _medications.addAll(newEntries);
          _nextPageUrl = nextLink?['url'];
          _hasMore = _nextPageUrl != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching medications: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medications")),
      body: _medications.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListView(),
    );
  }

  ListView _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _medications.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _medications.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resource = _medications[index]['resource'];

        // Extract Medication Name
        String medName = "Unknown Medication";
        if (resource['medicationCodeableConcept'] != null) {
          medName = resource['medicationCodeableConcept']['text'] ??
              resource['medicationCodeableConcept']['coding']?[0]['display'] ??
              "Unknown";
        }

        // Extract Dosage instructions
        String instructions = "No instructions provided";
        if (resource['dosageInstruction'] != null &&
            resource['dosageInstruction'].isNotEmpty) {
          instructions =
              resource['dosageInstruction'][0]['text'] ?? "As directed";
        }

        // Extract Status
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
                _buildStatusBadge(status),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green[800] : Colors.black54,
        ),
      ),
    );
  }
}

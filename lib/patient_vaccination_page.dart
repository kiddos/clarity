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
  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _vaccinations = [];
  String? _nextPageUrl;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchNextPage(initial: true);

    _scrollController.addListener(() {
      // Trigger when user is 90% through the list
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

    // FHIR Immunization resource uses date/occurrence date for sorting
    final url = initial
        ? "${widget.requestUrl}/Immunization?patient=$patient&_sort=-date&_count=10"
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

        final links = data['link'] as List<dynamic>?;
        final nextLink = links?.firstWhere((l) => l['relation'] == 'next',
            orElse: () => null);

        setState(() {
          _vaccinations.addAll(newEntries);
          _nextPageUrl = nextLink?['url'];
          _hasMore = _nextPageUrl != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching vaccinations: $e");
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
      appBar: AppBar(title: const Text("Vaccination History")),
      body: _vaccinations.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListView(),
    );
  }

  ListView _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _vaccinations.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _vaccinations.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resource = _vaccinations[index]['resource'];

        // Extract Data
        String vaccineName = resource['vaccineCode']?['text'] ??
            resource['vaccineCode']?['coding']?[0]['display'] ??
            "Unknown Vaccine";

        String date = resource['occurrenceDateTime']?.split('T')[0] ??
            resource['occurrenceString'] ??
            "Unknown date";

        String status = resource['status'] ?? "unknown";
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
  }
}

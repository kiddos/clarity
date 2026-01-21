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
  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _labResults = [];
  String? _nextPageUrl;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // Fetch initial page
    _fetchNextPage(initial: true);

    // Setup listener for scroll events
    _scrollController.addListener(() {
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

    // Use the "next" link if available, otherwise construct the initial search URL
    final url = initial
        ? "${widget.requestUrl}/Observation?patient=$patient&category=laboratory&_sort=-date&_count=10"
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

        // Find the "next" page URL in the FHIR Bundle links
        final links = data['link'] as List<dynamic>?;
        final nextLink = links?.firstWhere((l) => l['relation'] == 'next',
            orElse: () => null);

        setState(() {
          _labResults.addAll(newEntries);
          _nextPageUrl = nextLink?['url'];
          _hasMore = _nextPageUrl != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching lab data: $e");
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
      appBar: AppBar(title: const Text("Patient Lab Results")),
      body: _labResults.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListView(),
    );
  }

  ListView _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _labResults.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _labResults.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final observation = _labResults[index]['resource'];
        final String testName = observation['code']?['text'] ?? "Unknown Test";
        final String value =
            observation['valueQuantity']?['value']?.toStringAsFixed(3) ?? "N/A";
        final String unit = observation['valueQuantity']?['unit'] ?? "";
        final String date =
            observation['effectiveDateTime']?.split('T')[0] ?? "No date";

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: const Icon(Icons.science, color: Colors.blue),
            title: Text(testName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Date: $date"),
            trailing: Text("$value $unit",
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

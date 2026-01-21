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
  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _reports = [];
  String? _nextPageUrl;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchNextPage(initial: true);

    _scrollController.addListener(() {
      // Trigger load when 90% of the way down
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

    // Initial FHIR search URL or the next page link provided by the server
    final url = initial
        ? "${widget.requestUrl}/DiagnosticReport?patient=$patient&_sort=-date&_count=10"
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

        // Extract the pagination link from the FHIR Bundle
        final links = data['link'] as List<dynamic>?;
        final nextLink = links?.firstWhere((l) => l['relation'] == 'next',
            orElse: () => null);

        setState(() {
          _reports.addAll(newEntries);
          _nextPageUrl = nextLink?['url'];
          _hasMore = _nextPageUrl != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching diagnostic reports: $e");
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Diagnostic Reports")),
      body: _reports.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : buildListView(),
    );
  }

  ListView buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _reports.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _reports.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final report = _reports[index]['resource'];

        // Report Title
        String title = report['code']?['text'] ??
            report['code']?['coding']?[0]['display'] ??
            "Unnamed Report";

        // Category
        String category =
            report['category']?[0]?['coding']?[0]['display'] ?? "General";

        // Date
        String dateRaw = report['effectiveDateTime'] ?? report['issued'] ?? "";
        String dateFormatted = dateRaw.isNotEmpty
            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(dateRaw))
            : "Date Unknown";

        // Status
        String status = report['status'] ?? "unknown";

        // Result Count
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              // Navigate to details
            },
          ),
        );
      },
    );
  }
}

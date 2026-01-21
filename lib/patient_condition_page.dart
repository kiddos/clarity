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
  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _conditions = [];
  String? _nextPageUrl;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchNextPage(initial: true);

    // Listener to detect when user scrolls near the bottom
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

    // FHIR Standard search or use the 'next' link from previous response
    final url = initial
        ? "${widget.requestUrl}/Condition?patient=$patient&_count=10"
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

        // Find the 'next' relation in the links array for pagination
        final links = data['link'] as List<dynamic>?;
        final nextLink = links?.firstWhere((l) => l['relation'] == 'next',
            orElse: () => null);

        setState(() {
          _conditions.addAll(newEntries);
          _nextPageUrl = nextLink?['url'];
          _hasMore = _nextPageUrl != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching conditions: $e");
    }
  }

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medical Conditions")),
      body: _conditions.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListView(),
    );
  }

  ListView _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _conditions.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loader at the bottom if more data is coming
        if (index == _conditions.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resource = _conditions[index]['resource'];

        String conditionName = resource['code']?['text'] ??
            resource['code']?['coding']?[0]['display'] ??
            "Unspecified Diagnosis";

        String status =
            resource['clinicalStatus']?['coding']?[0]['code'] ?? "unknown";

        String recordedDate =
            resource['recordedDate']?.split('T')[0] ?? "Date not recorded";

        String severity = resource['severity']?['coding']?[0]['display'] ?? "";

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
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
                        fontSize: 10, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

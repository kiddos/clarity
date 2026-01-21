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
  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _allergies = [];
  String? _nextPageUrl;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchNextPage(initial: true);

    _scrollController.addListener(() {
      // Trigger load when user is 90% through the current list
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

    // Construct initial URL or use the next page link provided by FHIR
    final url = initial
        ? "${widget.requestUrl}/AllergyIntolerance?patient=$patient&_count=10"
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

        // FHIR uses the 'link' array with relation 'next' for pagination
        final links = data['link'] as List<dynamic>?;
        final nextLink = links?.firstWhere((l) => l['relation'] == 'next',
            orElse: () => null);

        setState(() {
          _allergies.addAll(newEntries);
          _nextPageUrl = nextLink?['url'];
          _hasMore = _nextPageUrl != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching allergies: $e");
    }
  }

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Allergies & Intolerances")),
      body: _allergies.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildListView(),
    );
  }

  ListView _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _allergies.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _allergies.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resource = _allergies[index]['resource'];

        // Substance Name
        String substance = resource['code']?['text'] ??
            resource['code']?['coding']?[0]['display'] ??
            "Unknown Substance";

        // Category
        List<dynamic>? categories = resource['category'];
        String categoryText = categories?.join(", ") ?? "Other";

        // Criticality
        String? criticality = resource['criticality'];

        // Verification Status
        String verification = resource['verificationStatus']?['coding']?[0]
                ['code'] ??
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
  }
}

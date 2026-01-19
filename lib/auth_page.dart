import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log.dart';
import 'auth.dart';
import 'patient_profile_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class LaunchOption {
  String launch;
  String display;
  LaunchOption(this.launch, this.display);
}

class _AuthPageState extends State<AuthPage> {
  final List<String> _defaultUrls = [
    'https://thas.mohw.gov.tw/v/r4'
  ];

  final List<LaunchOption> _launchOptions = [
    LaunchOption('eyJoIjoiMSJ9', 'Practitioner'), // base64 decode: {"h":"1"}
    LaunchOption('eyJrIjoiMSIsImoiOiIxIn0', 'Patient'), // base64 decode: {"k":"1","j":"1"}
  ];

  List<String> _customUrls = [];
  static const String _addNewUrlValue = "__ADD_NEW_ITEM__";
  static const String kCustomUrlKey = 'custom_urls';
  String? _selectedValue;
  String? _selectedLaunch;

  @override
  void initState() {
    super.initState();
    _loadCustomOptions();
    _selectedValue = _defaultUrls[0];
    _selectedLaunch = _launchOptions[0].launch;
  }

  Future<void> _loadCustomOptions() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customUrls = prefs.getStringList(kCustomUrlKey) ?? [];
    });
  }

  Future<void> _saveNewOption(String newItem) async {
    final trimmed = newItem.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customUrls.add(trimmed);
      _selectedValue = trimmed;
    });
    await prefs.setStringList(kCustomUrlKey, _customUrls);
  }

  void _authenticate() async {
    if (_selectedValue == null || _selectedLaunch == null) {
      return;
    }

    final tokenData = await authenticate(_selectedValue!, _selectedLaunch!);
    log.i('token: $tokenData');
    if (!mounted) {
      return;
    }

    if (tokenData != null) {
      final String requestUrl = '$_selectedValue/fhir';
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => PatientProfilePage(
                requestUrl: requestUrl, tokenData: tokenData)),
      );
    }
  }

  void _showAddDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New URL"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter item name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _saveNewOption(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildUrlDropdown(),
            _buildLaunchSelection(),
            const SizedBox(height: 80),
            ElevatedButton(
              child: const Text('Authenticate'),
              onPressed: () => _authenticate(),
            ),
          ],
        ),
      ),
    );
  }

  Padding _buildUrlDropdown() {
    List<String> combinedList = [..._defaultUrls, ..._customUrls];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: DropdownButton<String>(
        isExpanded: true,
        value: _selectedValue,
        hint: const Text("Select an option"),
        items: [
          ...combinedList.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              )),
          const DropdownMenuItem<String>(
            value: _addNewUrlValue,
            child: Row(
              children: [
                Icon(Icons.add, color: Colors.blue),
                SizedBox(width: 10),
                Text("Add custom option...",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          if (value == _addNewUrlValue) {
            _showAddDialog();
          } else {
            setState(() => _selectedValue = value);
          }
        },
      ),
    );
  }

  Widget _buildLaunchSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: DropdownButton<String>(
        value: _selectedLaunch,
        isExpanded: true,
        hint: const Text('Select a launch option'),
        items: _launchOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option.launch,
            child: Text(option.display),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedLaunch = newValue;
          });
        },
      ),
    );
  }
}

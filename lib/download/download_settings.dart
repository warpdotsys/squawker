import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_service.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  bool _archiveMode = true;
  String _apiEndpoint = 'https://get.warpdotsys.com/download';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _archiveMode = prefs.getBool('download_archive_mode') ?? true;
      _apiEndpoint = prefs.getString('download_api_endpoint') ?? 'https://get.warpdotsys.com/download';
    });
  }

  Future<void> _saveSettings() async {
    await DownloadService.setArchiveMode(_archiveMode);
    await DownloadService.setApiEndpoint(_apiEndpoint);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Archive Mode'),
            subtitle: const Text('Pack all files into a ZIP for download'),
            value: _archiveMode,
            onChanged: (v) {
              setState(() => _archiveMode = v);
              _saveSettings();
            },
          ),
          ListTile(
            title: const Text('API Server'),
            subtitle: Text(_apiEndpoint),
            trailing: const Icon(Symbols.edit),
            onTap: () => _editApiEndpoint(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Symbols.info_outline),
            title: const Text('About'),
            subtitle: const Text('Download tweets using gallery-dl backend'),
          ),
        ],
      ),
    );
  }

  Future<void> _editApiEndpoint(BuildContext context) async {
    final controller = TextEditingController(text: _apiEndpoint);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Server Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/download',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _apiEndpoint = result);
      _saveSettings();
    }
  }
}

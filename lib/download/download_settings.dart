import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squawker/generated/l10n.dart';
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
        SnackBar(content: Text(L10n.of(context).settings_saved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.download_settings),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.archive_mode),
            subtitle: Text(l10n.archive_mode_description),
            value: _archiveMode,
            onChanged: (v) {
              setState(() => _archiveMode = v);
              _saveSettings();
            },
          ),
          ListTile(
            title: Text(l10n.api_server),
            subtitle: Text(_apiEndpoint),
            trailing: const Icon(Symbols.edit),
            onTap: () => _editApiEndpoint(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Symbols.info),
            title: Text(l10n.about_download),
            subtitle: Text(l10n.about_download_description),
          ),
        ],
      ),
    );
  }

  Future<void> _editApiEndpoint(BuildContext context) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController(text: _apiEndpoint);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.api_server_address),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://example.com/download',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
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

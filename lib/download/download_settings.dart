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
  int _tValue = 0;
  String _apiEndpoint = 'https://get.warpdotsys.com/download';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tValue = prefs.getInt('download_t_value') ?? 0;
      _apiEndpoint = prefs.getString('download_api_endpoint') ?? 'https://get.warpdotsys.com/download';
    });
  }

  Future<void> _saveSettings() async {
    await DownloadService.setTValue(_tValue);
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
          ListTile(
            title: Text(l10n.download_mode),
            subtitle: Text(DownloadService.getTValueLabel(_tValue)),
            trailing: const Icon(Symbols.arrow_drop_down),
            onTap: () => _showTValuePicker(context),
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

  Future<void> _showTValuePicker(BuildContext context) async {
    final l10n = L10n.of(context);
    final options = [
      {'value': 0, 'label': l10n.download_mode_full_scan},
      {'value': 3, 'label': l10n.download_mode_fast},
      {'value': 20, 'label': l10n.download_mode_safe},
    ];

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.download_mode),
        children: options.map((opt) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, opt['value'] as int),
          child: Row(
            children: [
              if (_tValue == opt['value'])
                Icon(Symbols.check, color: Theme.of(context).colorScheme.primary)
              else
                const SizedBox(width: 24),
              const SizedBox(width: 12),
              Text(opt['label'] as String),
            ],
          ),
        )).toList(),
      ),
    );

    if (result != null) {
      setState(() => _tValue = result);
      _saveSettings();
    }
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

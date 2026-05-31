import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:squawker/client/client.dart';
import 'package:squawker/database/entities.dart';
import 'package:squawker/database/repository.dart';
import 'package:squawker/generated/l10n.dart';
import 'package:squawker/group/group_model.dart';
import 'package:squawker/import_data_model.dart';
import 'package:squawker/subscriptions/users_model.dart';

class ImportFollowingToTagDialog extends StatefulWidget {
  const ImportFollowingToTagDialog({Key? key}) : super(key: key);

  @override
  State<ImportFollowingToTagDialog> createState() => _ImportFollowingToTagDialogState();
}

class _ImportFollowingToTagDialogState extends State<ImportFollowingToTagDialog> {
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedGroupId;
  StreamController<int>? _streamController;
  bool _isImporting = false;
  int _importedCount = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    _streamController?.close();
    super.dispose();
  }

  Future<void> _import() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || _selectedGroupId == null) return;

    setState(() {
      _isImporting = true;
      _streamController = StreamController();
      _importedCount = 0;
    });

    try {
      String? cursor;
      var importModel = context.read<ImportDataModel>();
      var groupModel = context.read<GroupsModel>();
      var createdAt = DateTime.now();

      while (true) {
        var response = await Twitter.getProfileFollows(
          username,
          'following',
          cursor: cursor,
        );

        cursor = response.cursorBottom;

        if (response.users.isNotEmpty) {
          // Import users to subscription table
          await importModel.importData({
            tableSubscription: [
              ...response.users.map((e) => UserSubscription(
                id: e.idStr!,
                name: e.name!,
                profileImageUrlHttps: e.profileImageUrlHttps,
                screenName: e.screenName!,
                verified: e.verified ?? false,
                inFeed: true,
                createdAt: createdAt,
              ))
            ]
          });

          // Add users to the selected tag
          var repository = await Repository.writable();
          for (var user in response.users) {
            try {
              await repository.insert(tableSubscriptionGroupMember, {
                'group_id': _selectedGroupId,
                'subscription_id': user.idStr,
              });
            } catch (e) {
              // Ignore duplicate entries
            }
          }

          setState(() {
            _importedCount += response.users.length;
          });
          _streamController?.add(_importedCount);
        }

        if (response.users.isEmpty || cursor == null || cursor == '0' || cursor == '-1' || cursor!.isEmpty) {
          break;
        }
      }

      await groupModel.reloadGroups();
      _streamController?.close();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导入 $_importedCount 个用户到标签'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _streamController?.addError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return AlertDialog(
      title: Text(l10n.import_following),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('输入用户名，将其关注的人列表导入到指定标签'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.enter_your_twitter_username,
                prefixText: '@',
                labelText: l10n.username,
              ),
              maxLength: 15,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9_]+'))],
            ),
            const SizedBox(height: 16),
            // Tag selector
            FutureBuilder<List<SubscriptionGroup>>(
              future: _loadGroups(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final groups = snapshot.data!;
                return DropdownButtonFormField<String>(
                  value: _selectedGroupId,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: l10n.tag,
                  ),
                  items: groups.map((g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.name),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                );
              },
            ),
            if (_isImporting) ...[
              const SizedBox(height: 16),
              StreamBuilder<int>(
                stream: _streamController?.stream,
                builder: (context, snapshot) {
                  return Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text('已导入 ${snapshot.data ?? 0} 个用户'),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isImporting ? null : _import,
          child: Text(l10n.import),
        ),
      ],
    );
  }

  Future<List<SubscriptionGroup>> _loadGroups() async {
    var repository = await Repository.writable();
    var groups = await repository.query(tableSubscriptionGroup);
    return groups.map((e) => SubscriptionGroup(
      id: e['id'] as String,
      name: e['name'] as String,
      icon: e['icon'] as String? ?? 'group',
    )).toList();
  }
}

class SubscriptionGroup {
  final String id;
  final String name;
  final String icon;

  SubscriptionGroup({required this.id, required this.name, required this.icon});
}

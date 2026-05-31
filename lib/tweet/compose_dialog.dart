import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:squawker/client/client.dart';
import 'package:squawker/generated/l10n.dart';

enum ReplyControlMode {
  everyone,
  following,
  mentioned,
  verified,
}

class _MediaItem {
  final File file;
  final String type; // 'image' or 'video'
  String? mediaId;
  List<String> taggedUsers = [];

  _MediaItem({required this.file, required this.type});
}

class ComposeDialog extends StatefulWidget {
  final String? replyToTweetId;
  final String? replyToUsername;
  final String? quoteTweetUrl;

  const ComposeDialog({
    Key? key,
    this.replyToTweetId,
    this.replyToUsername,
    this.quoteTweetUrl,
  }) : super(key: key);

  @override
  State<ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<ComposeDialog> {
  final TextEditingController _textController = TextEditingController();
  ReplyControlMode _replyControl = ReplyControlMode.everyone;
  bool _isAiGenerated = false;
  bool _isPaidPromotion = false;
  bool _showPoll = false;
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _pollDuration = 1440;
  final List<_MediaItem> _mediaItems = [];
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    for (var c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (var file in result.files) {
          if (file.path != null) {
            final ext = file.extension?.toLowerCase() ?? '';
            final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
            _mediaItems.add(_MediaItem(
              file: File(file.path!),
              type: isVideo ? 'video' : 'image',
            ));
          }
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> _uploadMedia() async {
    final mediaEntities = <Map<String, dynamic>>[];

    for (var item in _mediaItems) {
      setState(() => _isUploading = true);

      final bytes = await item.file.readAsBytes();
      final mediaType = item.type == 'video' ? 'video/mp4' : 'image/${item.file.path.split('.').last}';

      // INIT
      String? mediaId;
      if (item.type == 'video') {
        mediaId = await Twitter.mediaInit(
          bytes.length,
          mediaType,
          mediaCategory: 'tweet_video',
        );
      } else {
        mediaId = await Twitter.mediaInit(
          bytes.length,
          mediaType,
          mediaCategory: 'tweet_image',
        );
      }

      if (mediaId == null) continue;

      // APPEND (upload in 4MB chunks)
      const chunkSize = 4 * 1024 * 1024;
      int segmentIndex = 0;
      for (int offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, bytes.length);
        final chunk = bytes.sublist(offset, end);
        final ok = await Twitter.mediaAppend(mediaId, chunk, segmentIndex);
        if (!ok) break;
        segmentIndex++;
      }

      // FINALIZE
      final result = await Twitter.mediaFinalize(mediaId);
      if (result != null) {
        item.mediaId = mediaId;

        // For video, wait for processing
        if (item.type == 'video') {
          for (int i = 0; i < 30; i++) {
            await Future.delayed(const Duration(seconds: 2));
            final status = await Twitter.mediaStatus(mediaId);
            if (status?['processing_info']?['state'] == 'succeeded') break;
            if (status?['processing_info']?['state'] == 'failed') {
              mediaId = null;
              break;
            }
          }
        }

        if (mediaId != null) {
          mediaEntities.add({
            'media_id': mediaId,
            'tagged_users': item.taggedUsers,
          });
        }
      }

      setState(() => _isUploading = false);
    }

    return mediaEntities;
  }

  Map<String, dynamic>? _buildConversationControl() {
    switch (_replyControl) {
      case ReplyControlMode.everyone:
        return null;
      case ReplyControlMode.following:
        return {'mode': 'ByInvitation'};
      case ReplyControlMode.mentioned:
        return {'mode': 'ByInvitation'};
      case ReplyControlMode.verified:
        return {'mode': 'Verified'};
    }
  }

  Map<String, dynamic>? _buildContentDisclosure() {
    if (!_isAiGenerated && !_isPaidPromotion) return null;

    final disclosure = <String, dynamic>{};
    if (_isPaidPromotion) {
      disclosure['advertising_disclosure'] = {'is_paid_promotion': true};
    }
    if (_isAiGenerated) {
      disclosure['ai_generated_disclosure'] = {
        'has_ai_generated_media': true,
        'ai_generated_detection_source': 'UserDeclared',
      };
    }
    return disclosure;
  }

  Map<String, dynamic>? _buildPoll() {
    if (!_showPoll) return null;
    final options = _pollOptions
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (options.length < 2) return null;

    return {
      'cards_locale': 'en',
      'poll_options': options,
      'poll_duration_minutes': _pollDuration,
    };
  }

  String _getReplyControlLabel() {
    switch (_replyControl) {
      case ReplyControlMode.everyone:
        return L10n.of(context).everyone_can_reply;
      case ReplyControlMode.following:
        return '我关注的人可回复';
      case ReplyControlMode.mentioned:
        return L10n.of(context).mentioned_only;
      case ReplyControlMode.verified:
        return L10n.of(context).verified_only;
    }
  }

  IconData _getReplyControlIcon() {
    switch (_replyControl) {
      case ReplyControlMode.everyone:
        return Symbols.public;
      case ReplyControlMode.following:
        return Symbols.people;
      case ReplyControlMode.mentioned:
        return Symbols.alternate_email;
      case ReplyControlMode.verified:
        return Symbols.verified;
    }
  }

  void _showReplyControlPicker() {
    final l10n = L10n.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.reply_settings,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Symbols.public),
              title: Text(l10n.everyone_can_reply),
              selected: _replyControl == ReplyControlMode.everyone,
              onTap: () {
                setState(() => _replyControl = ReplyControlMode.everyone);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.people),
              title: const Text('我关注的人可回复'),
              selected: _replyControl == ReplyControlMode.following,
              onTap: () {
                setState(() => _replyControl = ReplyControlMode.following);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.alternate_email),
              title: Text(l10n.mentioned_only),
              selected: _replyControl == ReplyControlMode.mentioned,
              onTap: () {
                setState(() => _replyControl = ReplyControlMode.mentioned);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.verified),
              title: Text(l10n.verified_only),
              selected: _replyControl == ReplyControlMode.verified,
              onTap: () {
                setState(() => _replyControl = ReplyControlMode.verified);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isReply = widget.replyToTweetId != null;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Symbols.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(isReply
                ? l10n.reply_to(widget.replyToUsername ?? '')
                : l10n.compose_tweet),
            actions: [
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isReply ? l10n.reply : l10n.compose_tweet),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text input
                TextField(
                  controller: _textController,
                  maxLines: 8,
                  minLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isReply ? l10n.reply_hint : '有什么新鲜事？',
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                // Media preview
                if (_mediaItems.isNotEmpty) ...[
                  const Divider(),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mediaItems.length,
                      itemBuilder: (ctx, i) {
                        final item = _mediaItems[i];
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[300],
                              ),
                              child: item.type == 'image'
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(item.file, fit: BoxFit.cover),
                                    )
                                  : const Center(child: Icon(Symbols.videocam, size: 32)),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _mediaItems.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Symbols.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                            // Tag users button
                            Positioned(
                              bottom: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _showTagUsersDialog(i),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Symbols.person_add, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                const Divider(),

                // Reply control
                if (!isReply) ...[
                  InkWell(
                    onTap: _showReplyControlPicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(_getReplyControlIcon(), size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(_getReplyControlLabel(),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary)),
                          const Spacer(),
                          Icon(Symbols.arrow_drop_down, size: 18,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                ],

                // Poll section
                if (_showPoll) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(l10n.add_poll,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Symbols.close, size: 18),
                                onPressed: () =>
                                    setState(() => _showPoll = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._pollOptions.asMap().entries.map((e) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: e.value,
                                  decoration: InputDecoration(
                                    hintText: '选项 ${e.key + 1}',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: _pollOptions.length > 2
                                        ? IconButton(
                                            icon: const Icon(
                                                Symbols.remove_circle_outline,
                                                size: 18),
                                            onPressed: () => setState(() =>
                                                _pollOptions
                                                    .removeAt(e.key)),
                                          )
                                        : null,
                                  ),
                                ),
                              )),
                          if (_pollOptions.length < 4)
                            TextButton.icon(
                              onPressed: () => setState(
                                  () => _pollOptions.add(TextEditingController())),
                              icon: const Icon(Symbols.add, size: 18),
                              label: const Text('添加选项'),
                            ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _pollDuration,
                            decoration: const InputDecoration(
                              labelText: '持续时间',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5 分钟')),
                              DropdownMenuItem(value: 15, child: Text('15 分钟')),
                              DropdownMenuItem(value: 30, child: Text('30 分钟')),
                              DropdownMenuItem(value: 60, child: Text('1 小时')),
                              DropdownMenuItem(value: 720, child: Text('12 小时')),
                              DropdownMenuItem(value: 1440, child: Text('1 天')),
                              DropdownMenuItem(value: 10080, child: Text('7 天')),
                            ],
                            onChanged: (v) =>
                                setState(() => _pollDuration = v!),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Action buttons row
                Wrap(
                  spacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Symbols.image, size: 18),
                      label: Text(l10n.add_media),
                      onPressed: _pickMedia,
                    ),
                    ActionChip(
                      avatar: const Icon(Symbols.add_chart, size: 18),
                      label: Text(l10n.add_poll),
                      onPressed: () => setState(() => _showPoll = !_showPoll),
                    ),
                    ActionChip(
                      avatar: Icon(
                        Symbols.smart_toy,
                        size: 18,
                        color: _isAiGenerated
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      label: Text(l10n.ai_generated),
                      onPressed: () =>
                          setState(() => _isAiGenerated = !_isAiGenerated),
                    ),
                    ActionChip(
                      avatar: Icon(
                        Symbols.attach_money,
                        size: 18,
                        color: _isPaidPromotion
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      label: Text(l10n.paid_promotion),
                      onPressed: () => setState(
                          () => _isPaidPromotion = !_isPaidPromotion),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTagUsersDialog(int mediaIndex) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('标记用户'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入用户名（逗号分隔）',
            prefixText: '@',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final users = controller.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              setState(() {
                _mediaItems[mediaIndex].taggedUsers = users;
              });
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaItems.isEmpty) return;

    setState(() => _isSubmitting = true);

    final scaffold = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    Navigator.pop(context);

    try {
      // Upload media first
      List<Map<String, dynamic>> mediaEntities = [];
      if (_mediaItems.isNotEmpty) {
        mediaEntities = await _uploadMedia();
      }

      final result = await Twitter.createTweet(
        text: text,
        replyToTweetId: widget.replyToTweetId,
        mediaEntities: mediaEntities,
        conversationControl: _buildConversationControl(),
        contentDisclosure: _buildContentDisclosure(),
        poll: _buildPoll(),
      );

      if (result != null &&
          result['data']?['create_tweet']?['tweet_results']?['result']
                  ?['rest_id'] !=
              null) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(widget.replyToTweetId != null
                ? l10n.reply_sent
                : '推文已发布'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.action_failed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('${l10n.action_failed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

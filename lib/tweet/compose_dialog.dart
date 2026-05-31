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
  int _pollDuration = 1440; // 24 hours in minutes

  @override
  void dispose() {
    _textController.dispose();
    for (var c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
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
      'poll_end_date_utc': DateTime.now()
          .add(Duration(minutes: _pollDuration))
          .toUtc()
          .toIso8601String(),
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
                onPressed: _submit,
                child: Text(isReply ? l10n.reply : l10n.compose_tweet),
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
                      avatar: const Icon(Symbols.add_chart, size: 18),
                      label: Text(l10n.add_poll),
                      onPressed: () => setState(() => _showPoll = !_showPoll),
                    ),
                    ActionChip(
                      avatar: Icon(
                        _isAiGenerated ? Symbols.smart_toy : Symbols.smart_toy,
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

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final scaffold = ScaffoldMessenger.of(context);
    final l10n = L10n.of(context);
    Navigator.pop(context);

    final result = await Twitter.createTweet(
      text: text,
      replyToTweetId: widget.replyToTweetId,
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
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:squawker/client/client.dart';
import 'package:squawker/generated/l10n.dart';
import 'package:squawker/status.dart';
import 'package:squawker/tweet/tweet.dart';
import 'package:squawker/utils/route_util.dart';
import 'package:squawker/utils/tweet_history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        actions: [
          IconButton(
            icon: const Icon(Symbols.delete_sweep),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.are_you_sure),
                  content: const Text('清除所有历史记录？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
                  ],
                ),
              );
              if (confirmed == true) {
                await TweetHistoryService.clearHistory();
                setState(() {});
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.viewed, icon: const Icon(Symbols.visibility, size: 18)),
            Tab(text: l10n.opened, icon: const Icon(Symbols.open_in_new, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryList(isViewed: true),
          _HistoryList(isViewed: false),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final bool isViewed;

  const _HistoryList({Key? key, required this.isViewed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: isViewed
          ? TweetHistoryService.getViewedHistory()
          : TweetHistoryService.getOpenedHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: Text(isViewed ? '没有浏览记录' : '没有打开记录'),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final tweetId = item['tweet_id'] as String;
            final screenName = item['screen_name'] as String?;
            final viewedAt = item['viewed_at'] as String?;

            return ListTile(
              leading: Icon(
                isViewed ? Symbols.visibility : Symbols.open_in_new,
                size: 20,
              ),
              title: Text('@${screenName ?? 'unknown'}'),
              subtitle: Text('Tweet ID: $tweetId'),
              trailing: viewedAt != null
                  ? Text(
                      _formatTime(viewedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : null,
              onTap: () {
                pushNamedRoute(
                  context,
                  routeStatus,
                  StatusScreenArguments(id: tweetId, username: screenName),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${dt.month}/${dt.day}';
    } catch (e) {
      return '';
    }
  }
}

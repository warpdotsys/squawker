import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pref/pref.dart';
import 'package:squawker/constants.dart';
import 'package:squawker/group/_feed.dart';
import 'package:squawker/group/group_screen.dart';
import 'package:squawker/home/_home_timeline_feed.dart';
import 'package:squawker/home/home_screen.dart';
import 'package:squawker/generated/l10n.dart';
import 'package:squawker/utils/data_service.dart';


enum FeedMode {
  forYou,
  following,
  subscriptions,
}

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final String id;
  final String name;

  const FeedScreen({Key? key, required this.scrollController, required this.id, required this.name}) : super(key: key);

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> with AutomaticKeepAliveClientMixin<FeedScreen> {
  FeedMode _feedMode = FeedMode.forYou;
  final GlobalKey<HomeTimelineFeedState> _forYouKey = GlobalKey<HomeTimelineFeedState>();
  final GlobalKey<HomeTimelineFeedState> _followingKey = GlobalKey<HomeTimelineFeedState>();

  @override
  void initState() {
    super.initState();
    _loadFeedMode();
  }

  void _loadFeedMode() {
    final prefs = PrefService.of(context, listen: false);
    final mode = prefs.get(optionFeedMode) ?? optionFeedModeForYou;
    setState(() {
      switch (mode) {
        case optionFeedModeForYou:
          _feedMode = FeedMode.forYou;
          break;
        case optionFeedModeFollowing:
          _feedMode = FeedMode.following;
          break;
        case optionFeedModeSubscriptions:
          _feedMode = FeedMode.subscriptions;
          break;
        default:
          _feedMode = FeedMode.forYou;
      }
    });
  }

  void _saveFeedMode(FeedMode mode) {
    final prefs = PrefService.of(context, listen: false);
    String modeStr;
    switch (mode) {
      case FeedMode.forYou:
        modeStr = optionFeedModeForYou;
        break;
      case FeedMode.following:
        modeStr = optionFeedModeFollowing;
        break;
      case FeedMode.subscriptions:
        modeStr = optionFeedModeSubscriptions;
        break;
    }
    prefs.set(optionFeedMode, modeStr);
  }

  Future<void> checkUpdateOrRefreshFeed() async {
    if (DataService().map.containsKey('toggleKeepFeed')) {
      setState(() {
        DataService().map.remove('toggleKeepFeed');
        DataService().map['keepFeed'] = false;
        updateKeepAlive();
      });
    }
    if (DataService().map.containsKey('toggleRefreshFeed')) {
      DataService().map.remove('toggleRefreshFeed');

      // Refresh the appropriate feed based on current mode
      if (_feedMode == FeedMode.forYou) {
        _forYouKey.currentState?.reloadData();
      } else if (_feedMode == FeedMode.following) {
        _followingKey.currentState?.reloadData();
      } else {
        GlobalKey<SubscriptionGroupFeedState>? sgfKey = DataService().map['feed_key_${widget.id.replaceAll('-', '_')}'];
        if (sgfKey?.currentState != null) {
          sgfKey!.currentState!.refresh();
        }
      }
    }
  }

  @override
  bool get wantKeepAlive {
    bool ret = true;
    if (DataService().map.containsKey('keepFeed')) {
      ret = DataService().map['keepFeed'] as bool;
    }
    return ret;
  }

  Widget _buildFeedContent() {
    switch (_feedMode) {
      case FeedMode.forYou:
        return HomeTimelineFeed(
          key: _forYouKey,
          type: HomeTimelineType.forYou,
          scrollController: widget.scrollController,
        );
      case FeedMode.following:
        return HomeTimelineFeed(
          key: _followingKey,
          type: HomeTimelineType.following,
          scrollController: widget.scrollController,
        );
      case FeedMode.subscriptions:
        return SubscriptionGroupScreen(
          scrollController: widget.scrollController,
          id: widget.id,
          name: widget.name,
          actions: createCommonAppBarActions(context),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    DataService().map['keepFeed'] = true;

    final l10n = L10n.of(context);

    return Column(
      children: [
        // Mode selector at the top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<FeedMode>(
            segments: [
              ButtonSegment<FeedMode>(
                value: FeedMode.forYou,
                label: Text(l10n.feed_for_you),
                icon: const Icon(Symbols.auto_awesome, size: 18),
              ),
              ButtonSegment<FeedMode>(
                value: FeedMode.following,
                label: Text(l10n.feed_following),
                icon: const Icon(Symbols.people, size: 18),
              ),
              ButtonSegment<FeedMode>(
                value: FeedMode.subscriptions,
                label: Text(l10n.feed),
                icon: const Icon(Symbols.rss_feed, size: 18),
              ),
            ],
            selected: {_feedMode},
            onSelectionChanged: (Set<FeedMode> selected) {
              final mode = selected.first;
              setState(() {
                _feedMode = mode;
              });
              _saveFeedMode(mode);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        // Feed content
        Expanded(
          child: _buildFeedContent(),
        ),
      ],
    );
  }
}

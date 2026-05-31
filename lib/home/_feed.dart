import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pref/pref.dart';
import 'package:squawker/constants.dart';
import 'package:squawker/group/_feed.dart';
import 'package:squawker/group/group_screen.dart';
import 'package:squawker/home/_home_timeline_feed.dart';
import 'package:squawker/home/home_screen.dart';
import 'package:squawker/generated/l10n.dart';
import 'package:squawker/tweet/compose_dialog.dart';
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
  late PageController _pageController;
  final GlobalKey<HomeTimelineFeedState> _forYouKey = GlobalKey<HomeTimelineFeedState>();
  final GlobalKey<HomeTimelineFeedState> _followingKey = GlobalKey<HomeTimelineFeedState>();
  int _lastTapTime = 0;

  @override
  void initState() {
    super.initState();
    _loadFeedMode();
    _pageController = PageController(initialPage: _feedMode.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadFeedMode() {
    final prefs = PrefService.of(context, listen: false);
    final mode = prefs.get(optionFeedMode) ?? optionFeedModeForYou;
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

  void _onPageChanged(int index) {
    final mode = FeedMode.values[index];
    setState(() {
      _feedMode = mode;
    });
    _saveFeedMode(mode);
  }

  void _switchMode(FeedMode mode) {
    setState(() {
      _feedMode = mode;
    });
    _saveFeedMode(mode);
    _pageController.animateToPage(
      mode.index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _handleEdgeSwipe(bool forward) {
    // forward=true means swiped left (towards next tab)
    // forward=false means swiped right (towards previous tab)
    final navigationKey = DataService().map['navigationKey'] as GlobalKey<ScaffoldWithBottomNavigationState>?;
    if (navigationKey?.currentState != null) {
      final pages = navigationKey!.currentState!.widget.pages;
      final currentIndex = navigationKey.currentState!.selectedIndex;
      if (forward && currentIndex < pages.length - 1) {
        navigationKey.currentState!.switchToPage(pages[currentIndex + 1].id);
      } else if (!forward && currentIndex > 0) {
        navigationKey.currentState!.switchToPage(pages[currentIndex - 1].id);
      }
    }
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
      _refreshCurrentFeed();
    }
  }

  void _refreshCurrentFeed() {
    switch (_feedMode) {
      case FeedMode.forYou:
        _forYouKey.currentState?.silentRefresh();
        break;
      case FeedMode.following:
        _followingKey.currentState?.silentRefresh();
        break;
      case FeedMode.subscriptions:
        GlobalKey<SubscriptionGroupFeedState>? sgfKey = DataService().map['feed_key_${widget.id.replaceAll('-', '_')}'];
        if (sgfKey?.currentState != null) {
          sgfKey!.currentState!.refresh();
        }
        break;
    }
  }

  void _handleDoubleTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < 300) {
      // Double tap detected - refresh without scrolling to top
      _refreshCurrentFeed();
      _lastTapTime = 0;
    } else {
      _lastTapTime = now;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    DataService().map['keepFeed'] = true;

    final l10n = L10n.of(context);

    return SafeArea(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _handleDoubleTap,
            behavior: HitTestBehavior.translucent,
            child: Column(
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
                      _switchMode(selected.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                // Feed content with PageView for swipe
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Detect edge swipe to switch outer tabs
                      if (notification is OverscrollNotification) {
                        if (notification.overscroll < -50 && _feedMode == FeedMode.forYou) {
                          _handleEdgeSwipe(false); // swipe right -> previous tab
                        } else if (notification.overscroll > 50 && _feedMode == FeedMode.subscriptions) {
                          _handleEdgeSwipe(true); // swipe left -> next tab
                        }
                      }
                      return false;
                    },
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      children: [
                        HomeTimelineFeed(
                          key: _forYouKey,
                          type: HomeTimelineType.forYou,
                        ),
                        HomeTimelineFeed(
                          key: _followingKey,
                          type: HomeTimelineType.following,
                        ),
                        SubscriptionGroupScreen(
                          scrollController: widget.scrollController,
                          id: widget.id,
                          name: widget.name,
                          actions: createCommonAppBarActions(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Compose FAB
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const ComposeDialog(),
                );
              },
              child: const Icon(Symbols.edit),
            ),
          ),
        ],
      ),
    );
  }
}

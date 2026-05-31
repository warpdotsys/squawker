import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:squawker/client/client.dart';
import 'package:squawker/client/client_account.dart';
import 'package:squawker/constants.dart';
import 'package:squawker/database/entities.dart';
import 'package:squawker/database/repository.dart';
import 'package:squawker/generated/l10n.dart';
import 'package:squawker/tweet/_video.dart';
import 'package:squawker/tweet/conversation.dart';
import 'package:squawker/tweet/tweet.dart';
import 'package:squawker/ui/errors.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:synchronized/synchronized.dart';

enum HomeTimelineType {
  forYou,
  following,
}

class HomeTimelineFeed extends StatefulWidget {
  final HomeTimelineType type;
  final ItemScrollController? scrollController;

  const HomeTimelineFeed({
    Key? key,
    required this.type,
    this.scrollController,
  }) : super(key: key);

  @override
  State<HomeTimelineFeed> createState() => HomeTimelineFeedState();
}

class HomeTimelineFeedState extends State<HomeTimelineFeed> with WidgetsBindingObserver {
  static final log = Logger('HomeTimelineFeedState');
  static final Lock _lock = Lock();

  final GlobalKey<ScaffoldState> _key = GlobalKey<ScaffoldState>();

  late VisiblePositionState _visiblePositionState;
  late ItemPositionsListener _itemPositionsListener;
  bool _insertOffset = true;
  bool _keepFeedOffset = false;
  final List<TweetChain> _lastData = [];
  final List<TweetChain> _data = [];
  bool _toScroll = false;
  Response? _errorResponse;
  int? _positionShowing;
  OverlayEntry? _overlayEntry;
  final Map<String, int> _tweetIdxDic = {};
  bool _isLoading = true;
  String? _cursorBottom;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _visiblePositionState = VisiblePositionState();
    _itemPositionsListener = ItemPositionsListener.create();
    _itemPositionsListener.itemPositions.addListener(() {
      _checkFetchData();
    });
    Future.delayed(Duration.zero, () {
      _checkFetchData();
    });
  }

  @override
  void dispose() {
    updateOffset();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      updateOffset();
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    updateOffset();
    return super.didRequestAppExit();
  }

  Future<void> _checkFetchData() async {
    if (_data.isEmpty || (_data.length > _lastData.length && (_data.length - _itemPositionsListener.itemPositions.value.first.index) < 20)) {
      await _lock.synchronized(() async {
        if (_data.isEmpty || (_data.length > _lastData.length && (_data.length - _itemPositionsListener.itemPositions.value.first.index) < 20)) {
          _lastData.clear();
          _lastData.addAll(_data);
          await _listTweets();
        }
      });
    }
  }

  Future<void> updateOffset() async {
    try {
      if (_keepFeedOffset && _visiblePositionState.initialized && _visiblePositionState.visibleChainId != null) {
        if (kDebugMode) {
          print('*** HomeTimelineFeedState._updateOffset - visibleChainId=${_visiblePositionState.visibleChainId}, visibleTweetId=${_visiblePositionState.visibleTweetId}, insert=$_insertOffset');
        }
        var repository = await Repository.writable();
        String groupId = 'home_timeline_${widget.type.name}';
        if (_insertOffset) {
          await repository.insert(tableFeedGroupPositionState, {'group_id': groupId, 'chain_id': _visiblePositionState.visibleChainId, 'tweet_id': _visiblePositionState.visibleTweetId});
        } else {
          await repository.update(tableFeedGroupPositionState, {'chain_id': _visiblePositionState.visibleChainId, 'tweet_id': _visiblePositionState.visibleTweetId}, where: 'group_id = ?', whereArgs: [groupId]);
        }
      }
    } catch (e, stackTrace) {
      log.warning('*** ERROR _updateOffset');
      log.warning(e);
      log.warning(stackTrace);
    }
  }

  void _resetData() {
    _visiblePositionState.initialized = false;
    _data.clear();
    _cursorBottom = null;
    _lastData.clear();
  }

  void refresh() {
    setState(() {});
  }

  Future<void> reloadData() async {
    await updateOffset();
    _resetData();
    _checkFetchData();
  }

  void setLoading() {
    setState(() {
      _isLoading = true;
    });
  }

  Future<void> _listTweets() async {
    try {
      BasePrefService prefs = PrefService.of(context);
      _keepFeedOffset = prefs.get(optionKeepFeedOffset);
      var repository = await Repository.writable();

      String groupId = 'home_timeline_${widget.type.name}';
      String? positionedChainId;
      String? positionedTweetId;

      if (_keepFeedOffset) {
        var positionStateData = await repository.query(tableFeedGroupPositionState, where: 'group_id = ?', whereArgs: [groupId]);
        _insertOffset = positionStateData.isEmpty;
        if (positionStateData.isNotEmpty) {
          positionedChainId = positionStateData[0]['chain_id'] as String?;
          positionedTweetId = positionStateData[0]['tweet_id'] as String?;
        }
      }

      _errorResponse = null;

      RateFetchContext fetchContext = RateFetchContext(
        widget.type == HomeTimelineType.forYou
            ? '/i/api/graphql/-M5P8LkjBRfeMF2MRJfbqA/HomeTimeline'
            : '/i/api/graphql/v8D8YuUcH9097nKOVvRPgA/HomeLatestTimeline',
        1,
      );

      TweetStatus result;
      try {
        if (widget.type == HomeTimelineType.forYou) {
          result = await Twitter.getHomeTimeline(
            cursor: _data.isNotEmpty ? _cursorBottom : null,
            count: 20,
            fetchContext: fetchContext,
          );
        } else {
          result = await Twitter.getHomeLatestTimeline(
            cursor: _data.isNotEmpty ? _cursorBottom : null,
            count: 20,
            fetchContext: fetchContext,
          );
        }
      } catch (rsp) {
        if (rsp is Exception) {
          log.severe(rsp.toString());
        }
        setState(() {
          _errorResponse = rsp is Exception ? ExceptionResponse(rsp) : rsp as Response;
          _isLoading = false;
        });
        return;
      }

      List<TweetChain> threads = result.chains;
      _cursorBottom = result.cursorBottom;

      // Handle position restoration
      if (positionedChainId != null && !_visiblePositionState.initialized) {
        int positionedChainIdx = threads.indexWhere((e) => e.id == positionedChainId);
        int positionedTweetIdx = -1;
        if (positionedChainIdx > -1 && positionedTweetId != null) {
          positionedTweetIdx = threads[positionedChainIdx].tweets.indexWhere((e) => e.idStr == positionedTweetId);
        }
        if (positionedChainIdx == -1 && threads.isNotEmpty) {
          int refId = int.parse(positionedChainId);
          TweetChain tc = threads.lastWhere((e) {
            int id = int.parse(e.id);
            return id > refId;
          }, orElse: () {
            return threads[threads.length - 1];
          });
          positionedChainIdx = threads.indexWhere((e) => e.id == tc.id);
        }
        _visiblePositionState.scrollChainIdx = positionedChainIdx > -1 ? positionedChainIdx : null;
        _visiblePositionState.scrollTweetIdx = positionedTweetIdx > -1 ? positionedTweetIdx : null;
      }

      _positionShowing = null;

      if (!mounted) return;

      setState(() {
        _data.addAll(threads);
        _isLoading = false;
      });

      _tweetIdxDic.clear();
      int idx = 0;
      for (var cElm in _data) {
        for (var tElm in cElm.tweets) {
          _tweetIdxDic[tElm.idStr!] = idx;
          idx++;
        }
      }

      _toScroll = false;
      if (threads.isNotEmpty && !_visiblePositionState.initialized && _visiblePositionState.scrollChainIdx != null) {
        _toScroll = true;
      }
    } catch (e, stackTrace) {
      if (e is Exception) {
        log.severe(e.toString());
        setState(() {
          _errorResponse ??= ExceptionResponse(e);
          _isLoading = false;
        });
      }
    } finally {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showOverlay(BuildContext context) {
    if (_overlayEntry == null) {
      RenderBox renderBoxWindow = _key.currentContext!.findRenderObject() as RenderBox;
      Offset positionWindow = renderBoxWindow.localToGlobal(Offset.zero);
      _overlayEntry = OverlayEntry(builder: (context) {
        return Positioned(
          right: 5,
          top: positionWindow.dy + 5,
          child: Material(
            child: Text(
              _positionShowing == null ? '' : _positionShowing!.toString(),
              style: TextStyle(fontSize: Theme.of(context).textTheme.titleMedium!.fontSize),
            ),
          ),
        );
      });
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _hideOverlay(BuildContext context) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    TwitterAccount.setCurrentContext(context);
    BasePrefService prefs = PrefService.of(context, listen: false);
    _keepFeedOffset = prefs.get(optionKeepFeedOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_toScroll) {
        _toScroll = false;
        widget.scrollController!.jumpTo(index: _visiblePositionState.scrollChainIdx!);
      }
      if (_errorResponse != null && _data.isNotEmpty && (_errorResponse!.statusCode < 200 || _errorResponse!.statusCode >= 300)) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_errorResponse!.body),
        ));
        _errorResponse = null;
      }
    });

    if (_errorResponse != null && _data.isEmpty && (_errorResponse!.statusCode < 200 || _errorResponse!.statusCode >= 300)) {
      var errorPage = Scaffold(
        body: FullPageErrorWidget(error: _errorResponse, prefix: 'Error request Twitter/X', stackTrace: null),
      );
      _errorResponse = null;
      return errorPage;
    }

    return Stack(
      children: [
        Scaffold(
          key: _key,
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _isLoading = true;
              });
              await reloadData();
            },
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<TweetContextState>(
                  create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive)),
                ),
                ChangeNotifierProvider<VideoContextState>(
                  create: (_) => VideoContextState(prefs.get(optionMediaDefaultMute)),
                ),
              ],
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (!_keepFeedOffset || !_visiblePositionState.initialized) {
                    return false;
                  }
                  if (notification is UserScrollNotification) {
                    if (notification.direction == ScrollDirection.forward) {
                      if (_visiblePositionState.visibleTweetIdx != null) {
                        _positionShowing = _visiblePositionState.visibleTweetIdx!;
                        _showOverlay(context);
                      }
                    } else if (notification.direction == ScrollDirection.idle) {
                      _positionShowing = null;
                      Future.delayed(const Duration(seconds: 2), () {
                        if (_positionShowing == null) {
                          _hideOverlay(context);
                        }
                      });
                    }
                  }
                  return false;
                },
                child: _data.isEmpty && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_empty, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              widget.type == HomeTimelineType.forYou
                                  ? 'No recommended tweets available'
                                  : 'No tweets from followed accounts',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => reloadData(),
                              child: Text(L10n.of(context).retry),
                            ),
                          ],
                        ),
                      )
                    : ScrollablePositionedList.builder(
                        itemCount: _data.length,
                        itemBuilder: (context, index) {
                          TweetChain tc = _data[index];
                          return TweetConversation(
                            key: ValueKey(tc.id),
                            id: tc.id,
                            username: null,
                            isPinned: tc.isPinned,
                            tweets: tc.tweets,
                            tweetIdxDic: _tweetIdxDic,
                            visiblePositionState: _visiblePositionState,
                          );
                        },
                        itemScrollController: widget.scrollController,
                        itemPositionsListener: _itemPositionsListener,
                        padding: const EdgeInsets.only(top: 4),
                      ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Opacity(
            opacity: 0.5,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

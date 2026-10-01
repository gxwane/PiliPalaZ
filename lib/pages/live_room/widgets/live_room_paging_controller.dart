import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/live.dart';
import 'package:pilipalaz/models/live/item.dart';

/// 直播间切房播放列表领域管理器
///
/// 负责双模式列表初始化、去重增补、边界预拉取与 PageController 协同。
class LiveRoomPlaylistManager {
  final RxList<LiveItemModel> playlist = <LiveItemModel>[].obs;
  final RxInt currentIndex = 0.obs;
  final PageController pageController;

  bool _isFetchingMore = false;
  int _recommendPage = 1;
  int? parentAreaId;
  String? sortType;
  bool _isDisposed = false;

  LiveRoomPlaylistManager({int initialIndex = 0})
    : pageController = PageController(initialPage: initialIndex) {
    currentIndex.value = initialIndex;
  }

  /// 双模式进入策略：优先消费外部列表上下文，否则使用单房种子并异步补全
  void initDualEntry({
    List<LiveItemModel>? initialList,
    int initialIndex = 0,
    int? initialRoomId,
    LiveItemModel? initialItem,
    int? parentAreaId,
    String? sortType,
  }) {
    this.parentAreaId = parentAreaId;
    this.sortType = sortType;
    if (initialList != null && initialList.isNotEmpty) {
      playlist.assignAll(initialList);
      currentIndex.value = initialIndex.clamp(0, playlist.length - 1);
      return;
    }

    final seed = initialItem ?? LiveItemModel(roomId: initialRoomId);
    playlist.assignAll([seed]);
    currentIndex.value = 0;
    unawaited(backfillRecommendations());
  }

  /// 外部/单房直入模式下的推荐池静默回填
  Future<void> backfillRecommendations() async {
    if (_isDisposed) return;
    final res = (parentAreaId != null && parentAreaId! > 0)
        ? await LiveHttp.areaLiveList(
            parentAreaId: parentAreaId!,
            page: 1,
            sortType: sortType,
          )
        : await LiveHttp.liveList(pn: 1);
    if (_isDisposed) return;

    if (res case ApiSuccess(:final data)) {
      _appendUniqueItems(data);
      _recommendPage = 1;
    }
  }

  /// 边界检测与自动增量预加载
  Future<void> checkAndPreloadMore(int index) async {
    if (_isFetchingMore || _isDisposed) return;
    if (index < playlist.length - 2) return;

    _isFetchingMore = true;
    try {
      final nextPage = _recommendPage + 1;
      final res = (parentAreaId != null && parentAreaId! > 0)
          ? await LiveHttp.areaLiveList(
              parentAreaId: parentAreaId!,
              page: nextPage,
              sortType: sortType,
            )
          : await LiveHttp.liveList(pn: nextPage);
      if (_isDisposed) return;

      if (res case ApiSuccess(:final data)) {
        final added = _appendUniqueItems(data);
        if (added > 0) {
          _recommendPage = nextPage;
        }
      }
    } finally {
      _isFetchingMore = false;
    }
  }

  int _appendUniqueItems(List<LiveItemModel> items) {
    final existingIds = playlist.map((e) => e.roomId).toSet();
    final newItems = items
        .where((e) => e.roomId != null && !existingIds.contains(e.roomId))
        .toList(growable: false);
    if (newItems.isNotEmpty && !_isDisposed) {
      playlist.addAll(newItems);
    }
    return newItems.length;
  }

  void dispose() {
    _isDisposed = true;
    sortType = null;
    parentAreaId = null;
    pageController.dispose();
    playlist.clear();
  }
}

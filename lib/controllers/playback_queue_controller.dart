import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/bangumi/info.dart' as pgc;
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/models/model_hot_video_item.dart';
import 'package:pilipalaz/models/video_detail_res.dart' as ugc;
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';

class PlaybackQueueController extends GetxController {
  final String heroTag;
  Future<bool> Function(PlayQueueItem item)? onPlayItem;
  VoidCallback? onQueueEmptied;
  Future<List<HotVideoItemModel>> Function()? onRequestRelated;
  PlayRepeat? mockPlayRepeatForTesting;

  PlaybackQueueController({
    required this.heroTag,
    this.onPlayItem,
    this.onQueueEmptied,
    this.onRequestRelated,
    this.mockPlayRepeatForTesting,
  });

  // ---------------------------------------------------------------------------
  // Active Instance Stack Management (for AudioHandler & System Controls)
  // ---------------------------------------------------------------------------
  static final List<PlaybackQueueController> _activeStack =
      <PlaybackQueueController>[];

  static PlaybackQueueController? get activeInstance =>
      _activeStack.isNotEmpty ? _activeStack.last : null;

  static void resetActiveStackForTesting() {
    _activeStack.clear();
  }

  void markActive() {
    _activeStack.remove(this);
    _activeStack.add(this);
  }

  // ---------------------------------------------------------------------------
  // Reactive State
  // ---------------------------------------------------------------------------
  final RxList<PlayQueueItem> queue = <PlayQueueItem>[].obs;
  final RxInt currentIndex = 0.obs;
  final Rx<PlayQueueSourceType> sourceType = PlayQueueSourceType.part.obs;
  final RxBool hasPrevious = false.obs;
  final RxBool hasNext = false.obs;
  final RxBool isExternalQueue = false.obs;

  PlayQueueItem? get currentItem =>
      queue.isNotEmpty &&
          currentIndex.value >= 0 &&
          currentIndex.value < queue.length
      ? queue[currentIndex.value]
      : null;

  PlayRepeat get playRepeat {
    if (mockPlayRepeatForTesting != null) {
      return mockPlayRepeatForTesting!;
    }
    try {
      return PlPlayerController.getInstance().playRepeat;
    } catch (_) {
      return PlayRepeat.pause;
    }
  }

  void setPlayRepeat(PlayRepeat mode) {
    if (mockPlayRepeatForTesting != null) {
      mockPlayRepeatForTesting = mode;
    } else {
      try {
        PlPlayerController.getInstance().setPlayRepeat(mode);
      } catch (_) {}
    }
    syncState();
  }

  @override
  void onInit() {
    super.onInit();
    markActive();
  }

  @override
  void onClose() {
    _activeStack.remove(this);
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Queue Initialization Methods
  // ---------------------------------------------------------------------------

  /// 从多 P 视频初始化队列
  void initFromPages({
    required List<ugc.Part> pages,
    required String bvid,
    required int aid,
    required int currentCid,
    String? cover,
    String? author,
  }) {
    if (isExternalQueue.value) return;

    final items = pages
        .map(
          (p) => PlayQueueItem.fromPart(
            p,
            bvid: bvid,
            aid: aid,
            cover: cover,
            author: author,
          ),
        )
        .toList();

    sourceType.value = PlayQueueSourceType.part;
    queue.assignAll(items);

    final idx = items.indexWhere((item) => item.cid == currentCid);
    currentIndex.value = idx >= 0 ? idx : 0;
    syncState();
  }

  /// 从 UGC 合集初始化队列
  void initFromUgcSeason({
    required ugc.UgcSeason ugcSeason,
    required int currentCid,
    String? cover,
    String? author,
  }) {
    if (isExternalQueue.value) return;

    final items = <PlayQueueItem>[];
    for (final section in ugcSeason.sections ?? <ugc.SectionItem>[]) {
      for (final ep in section.episodes ?? <ugc.EpisodeItem>[]) {
        items.add(
          PlayQueueItem.fromUgcEpisode(ep, cover: cover, author: author),
        );
      }
    }

    sourceType.value = PlayQueueSourceType.ugcSeason;
    queue.assignAll(items);

    final idx = items.indexWhere((item) => item.cid == currentCid);
    currentIndex.value = idx >= 0 ? idx : 0;
    syncState();
  }

  /// 从 PGC 番剧/影视初始化队列
  void initFromPgc({
    required List<pgc.EpisodeItem> episodes,
    required int currentCid,
    int? currentEpId,
    int? seasonId,
    String? cover,
  }) {
    if (isExternalQueue.value) return;

    final items = episodes
        .map(
          (ep) => PlayQueueItem.fromPgcEpisode(
            ep,
            seasonId: seasonId,
            cover: cover,
          ),
        )
        .toList();

    sourceType.value = PlayQueueSourceType.pgcEpisode;
    queue.assignAll(items);

    int idx = -1;
    if (currentEpId != null && currentEpId > 0) {
      idx = items.indexWhere((item) => item.epId == currentEpId);
    }
    if (idx < 0) {
      idx = items.indexWhere((item) => item.cid == currentCid);
    }
    currentIndex.value = idx >= 0 ? idx : 0;
    syncState();
  }

  /// 从稍后再看初始化队列（外部锁定队列）
  void initFromWatchLater({
    required List<HotVideoItemModel> items,
    required int initialIndex,
  }) {
    final queueItems = items
        .map(
          (item) => PlayQueueItem.fromHotVideoItem(
            item,
            sourceType: PlayQueueSourceType.watchLater,
          ),
        )
        .toList();

    isExternalQueue.value = true;
    sourceType.value = PlayQueueSourceType.watchLater;
    queue.assignAll(queueItems);
    currentIndex.value = (initialIndex >= 0 && initialIndex < queueItems.length)
        ? initialIndex
        : 0;
    syncState();
  }

  /// 从相关推荐初始化队列
  void initFromRelated({
    required List<HotVideoItemModel> items,
    required PlayQueueItem currentVideo,
  }) {
    if (isExternalQueue.value) return;

    final list = <PlayQueueItem>[currentVideo];
    for (final item in items) {
      list.add(
        PlayQueueItem.fromHotVideoItem(
          item,
          sourceType: PlayQueueSourceType.related,
        ),
      );
    }

    sourceType.value = PlayQueueSourceType.related;
    queue.assignAll(list);
    currentIndex.value = 0;
    syncState();
  }

  // ---------------------------------------------------------------------------
  // Queue Navigation Operations
  // ---------------------------------------------------------------------------

  /// 同步当前播放状态（当外部直接通过选集卡片切换时更新当前索引）
  void syncCurrent({String? bvid, int? cid, int? epId}) {
    if (queue.isEmpty) return;
    int idx = -1;
    if (epId != null && epId > 0) {
      idx = queue.indexWhere((item) => item.epId == epId);
    }
    if (idx < 0 && cid != null && cid > 0) {
      idx = queue.indexWhere((item) => item.cid == cid);
    }
    if (idx < 0 && bvid != null && bvid.isNotEmpty) {
      idx = queue.indexWhere((item) => item.bvid == bvid);
    }
    if (idx >= 0 && idx != currentIndex.value) {
      currentIndex.value = idx;
      syncState();
    }
  }

  void syncState() {
    if (queue.isEmpty) {
      hasPrevious.value = false;
      hasNext.value = false;
      return;
    }

    final mode = playRepeat;
    hasPrevious.value = currentIndex.value > 0 || mode == PlayRepeat.listCycle;
    hasNext.value =
        currentIndex.value < queue.length - 1 ||
        mode == PlayRepeat.listCycle ||
        mode == PlayRepeat.autoPlayRelated;
  }

  Future<bool> playNext({bool autoTriggered = false}) async {
    if (queue.isEmpty) return false;

    final mode = playRepeat;

    // 单曲循环且为播放完毕自动触发
    if (mode == PlayRepeat.singleCycle && autoTriggered) {
      final current = currentItem;
      if (current != null && onPlayItem != null) {
        return await onPlayItem!(current);
      }
      return true;
    }

    // 队内有下一项
    if (currentIndex.value < queue.length - 1) {
      return await jumpToIndex(currentIndex.value + 1);
    }

    // 队尾处理
    if (mode == PlayRepeat.listCycle) {
      return await jumpToIndex(0);
    }

    if (mode == PlayRepeat.autoPlayRelated) {
      // 动态拉取更多相关视频入队
      if (onRequestRelated != null) {
        final moreItems = await onRequestRelated!();
        if (moreItems.isNotEmpty) {
          enqueueAll(
            moreItems
                .map(
                  (e) => PlayQueueItem.fromHotVideoItem(
                    e,
                    sourceType: PlayQueueSourceType.related,
                  ),
                )
                .toList(),
          );
          if (currentIndex.value < queue.length - 1) {
            return await jumpToIndex(currentIndex.value + 1);
          }
        }
      }
    }

    return false;
  }

  Future<bool> playPrevious() async {
    if (queue.isEmpty) return false;

    if (currentIndex.value > 0) {
      return await jumpToIndex(currentIndex.value - 1);
    }

    if (playRepeat == PlayRepeat.listCycle && queue.length > 1) {
      return await jumpToIndex(queue.length - 1);
    }

    return false;
  }

  Future<bool> jumpToIndex(int index) async {
    if (index < 0 || index >= queue.length) return false;

    currentIndex.value = index;
    syncState();

    final target = queue[index];
    if (onPlayItem != null) {
      return await onPlayItem!(target);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Queue Item Manipulation
  // ---------------------------------------------------------------------------

  void removeAt(int index) {
    if (index < 0 || index >= queue.length) return;

    if (queue.length == 1) {
      queue.clear();
      currentIndex.value = 0;
      syncState();
      onQueueEmptied?.call();
      return;
    }

    if (index < currentIndex.value) {
      queue.removeAt(index);
      currentIndex.value--;
      syncState();
    } else if (index == currentIndex.value) {
      if (index == queue.length - 1) {
        queue.removeAt(index);
        final nextIdx = (playRepeat == PlayRepeat.listCycle)
            ? 0
            : queue.length - 1;
        jumpToIndex(nextIdx);
      } else {
        queue.removeAt(index);
        jumpToIndex(currentIndex.value);
      }
    } else {
      queue.removeAt(index);
      syncState();
    }
  }

  void clearUpcoming() {
    if (queue.isEmpty) return;
    if (currentIndex.value < queue.length - 1) {
      queue.removeRange(currentIndex.value + 1, queue.length);
      syncState();
    }
  }

  void enqueue(PlayQueueItem item) {
    if (queue.any((e) => e.id == item.id)) return;
    queue.add(item);
    syncState();
  }

  void enqueueAll(List<PlayQueueItem> items) {
    final existingIds = queue.map((e) => e.id).toSet();
    final toAdd = items.where((e) => !existingIds.contains(e.id)).toList();
    if (toAdd.isNotEmpty) {
      queue.addAll(toAdd);
      syncState();
    }
  }
}

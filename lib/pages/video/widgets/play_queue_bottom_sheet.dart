import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:pilipalaz/common/widgets/my_dialog.dart';
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/models/bangumi/info.dart' as pgc;
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/utils.dart';

/// 统一可视化播放队列面板
class PlayQueueBottomSheet extends StatefulWidget {
  const PlayQueueBottomSheet({super.key, required this.controller});

  final PlaybackQueueController controller;

  /// 快捷弹出方法
  static void show(
    BuildContext context, {
    required PlaybackQueueController controller,
  }) {
    MyDialog.showCorner(context, PlayQueueBottomSheet(controller: controller));
  }

  @override
  State<PlayQueueBottomSheet> createState() => _PlayQueueBottomSheetState();
}

class _PlayQueueBottomSheetState extends State<PlayQueueBottomSheet> {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  bool reverse = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentIndex();
    });
  }

  void _scrollToCurrentIndex() {
    final idx = widget.controller.currentIndex.value;
    if (widget.controller.queue.isNotEmpty &&
        idx >= 0 &&
        idx < widget.controller.queue.length) {
      final targetIdx = reverse
          ? widget.controller.queue.length - 1 - idx
          : idx;
      if (itemScrollController.isAttached) {
        itemScrollController.scrollTo(
          index: targetIdx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: 0.3,
        );
      } else {
        itemScrollController.jumpTo(index: targetIdx, alignment: 0.3);
      }
    }
  }

  String _getSourceTypeName(PlayQueueSourceType type) {
    switch (type) {
      case PlayQueueSourceType.part:
        return '分P选集';
      case PlayQueueSourceType.ugcSeason:
        return '合集';
      case PlayQueueSourceType.pgcEpisode:
        return '影视剧集';
      case PlayQueueSourceType.watchLater:
        return '稍后再看';
      case PlayQueueSourceType.related:
        return '相关连播';
      case PlayQueueSourceType.custom:
        return '自定义';
    }
  }

  IconData _getRepeatModeIcon(PlayRepeat mode) {
    switch (mode) {
      case PlayRepeat.pause:
        return Icons.pause_circle_outline;
      case PlayRepeat.listOrder:
        return Icons.format_list_numbered;
      case PlayRepeat.listCycle:
        return Icons.repeat;
      case PlayRepeat.singleCycle:
        return Icons.repeat_one;
      case PlayRepeat.autoPlayRelated:
        return Icons.playlist_play;
    }
  }

  String _getRepeatModeLabel(PlayRepeat mode) {
    return mode.description;
  }

  void _toggleRepeatMode() {
    const modes = [
      PlayRepeat.pause,
      PlayRepeat.listOrder,
      PlayRepeat.listCycle,
      PlayRepeat.singleCycle,
      PlayRepeat.autoPlayRelated,
    ];
    final current = widget.controller.playRepeat;
    final next = modes[(modes.indexOf(current) + 1) % modes.length];
    widget.controller.setPlayRepeat(next);
    SmartDialog.showToast('播放模式：${_getRepeatModeLabel(next)}');
    setState(() {});
  }

  void _handleItemTap(int actualIndex, PlayQueueItem item) {
    // 会员权益拦截
    if (item.rawData is pgc.EpisodeItem) {
      final ep = item.rawData as pgc.EpisodeItem;
      if (ep.badge != null && ep.badge == '会员') {
        dynamic userInfo = GStorage.userInfo.get('userInfoCache');
        int vipStatus = 0;
        if (userInfo != null) {
          vipStatus = userInfo.vipStatus;
        }
        if (vipStatus != 1) {
          SmartDialog.showToast('需要大会员');
          return;
        }
      }
    }

    SmartDialog.showToast('切换到：${item.title}');
    Get.back();
    widget.controller.jumpToIndex(actualIndex);
  }

  Widget _buildQueueItem(
    BuildContext context,
    PlayQueueItem item,
    int displayIndex,
    int actualIndex,
    bool isCurrent,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    String? badgeText;
    bool isVipBadge = false;
    if (item.rawData is pgc.EpisodeItem) {
      final ep = item.rawData as pgc.EpisodeItem;
      if (ep.badge != null && ep.badge!.isNotEmpty) {
        badgeText = ep.badge;
        isVipBadge = ep.badge == '会员';
      }
    }

    String metaInfo = '';
    if (item.duration > 0) {
      metaInfo = Utils.timeFormat(item.duration);
    }
    if (item.author != null && item.author!.isNotEmpty) {
      metaInfo = metaInfo.isNotEmpty
          ? '$metaInfo · ${item.author}'
          : item.author!;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleItemTap(actualIndex, item),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                // 序号或当前播放标志
                Container(
                  width: 32,
                  alignment: Alignment.centerLeft,
                  child: isCurrent
                      ? Icon(
                          Icons.volume_up_rounded,
                          color: primary,
                          size: 20,
                          semanticLabel: '正在播放',
                        )
                      : Text(
                          (actualIndex + 1).toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                // 标题与副文本
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrent
                              ? primary
                              : theme.colorScheme.onSurface,
                        ),
                        semanticsLabel: isCurrent
                            ? '正在播放：${item.title}'
                            : item.title,
                      ),
                      if (metaInfo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            metaInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // VIP / 权益角标
                if (badgeText != null) ...[
                  const SizedBox(width: 8),
                  if (isVipBadge)
                    Image.asset(
                      'assets/images/big-vip.png',
                      height: 18,
                      semanticLabel: '大会员',
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(color: primary, fontSize: 10),
                      ),
                    ),
                ],
                const SizedBox(width: 4),
                // 移除单项按钮 (48x48 触控热区与语义保障)
                Semantics(
                  label: '从队列移除 ${item.title}',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                    tooltip: '从队列移除',
                    onPressed: () => widget.controller.removeAt(actualIndex),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Obx(() {
      final queue = widget.controller.queue;
      final currentIndex = widget.controller.currentIndex.value;
      final currentRepeat = widget.controller.playRepeat;
      final sourceName = _getSourceTypeName(widget.controller.sourceType.value);
      final hasUpcoming = currentIndex < queue.length - 1;

      return Container(
        height: 520,
        width: min(MediaQuery.sizeOf(context).width, 520),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Column(
          children: [
            // 顶部标题栏与控制区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '播放队列',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 队列来源胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sourceName,
                      style: TextStyle(
                        fontSize: 11,
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${queue.length})',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  // 循环模式切换
                  IconButton(
                    icon: Icon(
                      _getRepeatModeIcon(currentRepeat),
                      size: 20,
                      color: currentRepeat != PlayRepeat.pause
                          ? primary
                          : theme.colorScheme.outline,
                    ),
                    tooltip: '播放模式: ${_getRepeatModeLabel(currentRepeat)}',
                    onPressed: _toggleRepeatMode,
                  ),
                  // 定位当前播放条目
                  IconButton(
                    tooltip: '定位到当前播放',
                    icon: const Icon(Icons.my_location, size: 20),
                    onPressed: _scrollToCurrentIndex,
                  ),
                  // 反序切换
                  IconButton(
                    tooltip: reverse ? '正序排列' : '倒序排列',
                    icon: Icon(
                      !reverse
                          ? MdiIcons.sortAscending
                          : MdiIcons.sortDescending,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        reverse = !reverse;
                      });
                    },
                  ),
                  // 清空待播
                  if (hasUpcoming)
                    IconButton(
                      tooltip: '清空待播',
                      icon: const Icon(Icons.playlist_remove, size: 21),
                      onPressed: () {
                        widget.controller.clearUpcoming();
                        SmartDialog.showToast('已清空后续待播项');
                      },
                    ),
                  // 关闭
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: Get.back,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: theme.dividerColor.withValues(alpha: 0.15),
            ),
            // 列表区域
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Text(
                        '队列已清空',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    )
                  : ScrollablePositionedList.separated(
                      itemScrollController: itemScrollController,
                      itemPositionsListener: itemPositionsListener,
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: MediaQuery.paddingOf(context).bottom + 12,
                      ),
                      itemCount: queue.length,
                      separatorBuilder: (_, __) => Divider(
                        indent: 52,
                        endIndent: 14,
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.08),
                      ),
                      itemBuilder: (context, displayIndex) {
                        final actualIndex = reverse
                            ? queue.length - 1 - displayIndex
                            : displayIndex;
                        final item = queue[actualIndex];
                        final isCurrent = actualIndex == currentIndex;

                        return _buildQueueItem(
                          context,
                          item,
                          displayIndex,
                          actualIndex,
                          isCurrent,
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}

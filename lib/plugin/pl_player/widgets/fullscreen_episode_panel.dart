import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/utils.dart';

class FullScreenEpisodePanel extends StatefulWidget {
  const FullScreenEpisodePanel({
    super.key,
    required this.episodes,
    required this.currentCid,
    required this.onSelect,
    this.onDismiss,
    this.isMovie = false,
    this.bvid,
    this.aid,
  });

  final List<dynamic> episodes;
  final int currentCid;
  final ValueChanged<dynamic> onSelect;
  final VoidCallback? onDismiss;
  final bool isMovie;
  final String? bvid;
  final int? aid;

  static Future<void> show({
    required BuildContext context,
    required List<dynamic> episodes,
    required int currentCid,
    required ValueChanged<dynamic> onSelect,
    bool isMovie = false,
    String? bvid,
    int? aid,
  }) {
    if (episodes.isEmpty) return Future.value();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭选集列表',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FullScreenEpisodePanel(
            episodes: episodes,
            currentCid: currentCid,
            onSelect: onSelect,
            isMovie: isMovie,
            bvid: bvid,
            aid: aid,
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  @override
  State<FullScreenEpisodePanel> createState() => _FullScreenEpisodePanelState();
}

class _FullScreenEpisodePanelState extends State<FullScreenEpisodePanel> {
  final ScrollController _scrollController = ScrollController();
  late final int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _calculateInitialIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentIndex > 0 && _scrollController.hasClients) {
        final double targetOffset = (_currentIndex * 68.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(targetOffset);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _calculateInitialIndex() {
    if (widget.episodes.isEmpty) return -1;
    return widget.episodes.indexWhere((dynamic e) {
      try {
        if (e is PlayQueueItem) {
          if (widget.bvid != null &&
              widget.bvid!.isNotEmpty &&
              e.bvid == widget.bvid) {
            return e.cid == widget.currentCid || widget.currentCid == 0;
          }
          return e.cid == widget.currentCid;
        }
        return e.cid == widget.currentCid;
      } catch (_) {
        return false;
      }
    });
  }

  void _dismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _handleEpisodeTap(dynamic episode) {
    String? badge;
    try {
      badge = episode.badge?.toString();
    } catch (_) {}

    if (badge != null && badge == '会员') {
      try {
        final dynamic userInfo = GStorage.userInfo.get('userInfoCache');
        int vipStatus = 0;
        if (userInfo != null) {
          vipStatus = userInfo.vipStatus ?? 0;
        }
        if (vipStatus != 1) {
          SmartDialog.showToast('需要大会员');
          return;
        }
      } catch (_) {
        // If storage not initialized (e.g. in test env), allow navigation
      }
    }

    _dismiss();
    widget.onSelect(episode);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.orientationOf(context) == Orientation.portrait) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dismiss();
        }
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = min(420.0, max(300.0, screenWidth * 0.38));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 150) {
          _dismiss();
        }
      },
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 10) {
          _dismiss();
        }
      },
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        elevation: 16,
        child: SafeArea(
          left: false,
          top: true,
          bottom: true,
          right: true,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme),
                const Divider(height: 1, thickness: 0.5),
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: widget.episodes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final episode = widget.episodes[index];
                      return _buildEpisodeItem(
                        context: context,
                        episode: episode,
                        index: index,
                        primaryColor: primaryColor,
                        theme: theme,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    String titleText = widget.isMovie ? '电影选集' : '剧集选集';
    String countText = widget.isMovie
        ? '共 ${widget.episodes.length} 部'
        : '共 ${widget.episodes.length} 话';

    if (widget.episodes.isNotEmpty && widget.episodes.first is PlayQueueItem) {
      final firstItem = widget.episodes.first as PlayQueueItem;
      titleText = firstItem.sourceType.label;
      countText = '共 ${widget.episodes.length} 个视频';
    } else if (!widget.isMovie &&
        widget.episodes.isNotEmpty &&
        widget.episodes.first is! EpisodeItem) {
      titleText = '视频选集';
      countText = '共 ${widget.episodes.length} P';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  countText,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem({
    required BuildContext context,
    required dynamic episode,
    required int index,
    required Color primaryColor,
    required ThemeData theme,
  }) {
    final bool isCurrent = index == _currentIndex;

    String title = '';
    String? longTitle;
    String? badge;

    if (episode is PlayQueueItem) {
      title = episode.title;
      if (episode.duration > 0) {
        longTitle = Utils.timeFormat(episode.duration);
      }
      badge = episode.badge;
    } else if (episode is EpisodeItem) {
      title = episode.title ?? '第${index + 1}话';
      longTitle = episode.longTitle;
      badge = episode.badge;
    } else {
      // Fallback for Part / PageItem
      try {
        title = (episode.pagePart ?? episode.part ?? '第${index + 1}P')
            .toString();
      } catch (_) {
        title = '第${index + 1}集';
      }
    }

    return Material(
      color: isCurrent
          ? primaryColor.withValues(alpha: 0.14)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _handleEpisodeTap(episode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (isCurrent) ...[
                Image.asset(
                  'assets/images/live.png',
                  color: primaryColor,
                  height: 12,
                  semanticLabel: '正在播放：',
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isCurrent
                            ? primaryColor
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (longTitle != null && longTitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        longTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent
                              ? primaryColor.withValues(alpha: 0.85)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null && badge.isNotEmpty) ...[
                const SizedBox(width: 8),
                if (badge == '会员')
                  Image.asset(
                    'assets/images/big-vip.png',
                    height: 16,
                    semanticLabel: '大会员',
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(fontSize: 11, color: primaryColor),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

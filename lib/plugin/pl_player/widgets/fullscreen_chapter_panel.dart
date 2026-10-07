import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/video/play/chapter.dart';
import 'package:pilipalaz/utils/utils.dart';

class FullScreenChapterPanel extends StatefulWidget {
  const FullScreenChapterPanel({
    super.key,
    required this.chapters,
    required this.activeChapter,
    required this.onSelect,
    this.onDismiss,
  });

  final List<VideoChapter> chapters;
  final Rx<VideoChapter?> activeChapter;
  final ValueChanged<VideoChapter> onSelect;
  final VoidCallback? onDismiss;

  static Future<void> show({
    required BuildContext context,
    required List<VideoChapter> chapters,
    required Rx<VideoChapter?> activeChapter,
    required ValueChanged<VideoChapter> onSelect,
  }) {
    if (chapters.isEmpty) return Future.value();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭看点列表',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FullScreenChapterPanel(
            chapters: chapters,
            activeChapter: activeChapter,
            onSelect: onSelect,
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
  State<FullScreenChapterPanel> createState() => _FullScreenChapterPanelState();
}

class _FullScreenChapterPanelState extends State<FullScreenChapterPanel> {
  void _dismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _handleChapterTap(VideoChapter chapter) {
    _dismiss();
    widget.onSelect(chapter);
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
    final panelWidth = min(380.0, max(280.0, screenWidth * 0.42));

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: widget.chapters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final chapter = widget.chapters[index];
                      return _buildChapterItem(
                        context: context,
                        chapter: chapter,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '看点列表',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '共 ${widget.chapters.length} 个分段',
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

  Widget _buildChapterItem({
    required BuildContext context,
    required VideoChapter chapter,
    required Color primaryColor,
    required ThemeData theme,
  }) {
    final hasThumb = chapter.imgUrl != null && chapter.imgUrl!.isNotEmpty;
    final timeStr =
        '${Utils.timeFormat(chapter.from)} - ${Utils.timeFormat(chapter.to)}';

    return Obx(() {
      final isActive = widget.activeChapter.value == chapter;
      return Material(
        color: isActive
            ? primaryColor.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleChapterTap(chapter),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 80,
                    height: 48,
                    child: hasThumb
                        ? NetworkImgLayer(
                            src: chapter.imgUrl!,
                            width: 80,
                            height: 48,
                            errorWidget: Container(
                              color: primaryColor.withValues(alpha: 0.08),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.play_circle_outline,
                                color: primaryColor,
                                size: 22,
                              ),
                            ),
                          )
                        : Container(
                            color: primaryColor.withValues(alpha: 0.08),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.play_circle_outline,
                              color: primaryColor,
                              size: 22,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chapter.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? primaryColor
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '播放中',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

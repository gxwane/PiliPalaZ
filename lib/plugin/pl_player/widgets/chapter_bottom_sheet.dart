import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/video/play/chapter.dart';
import 'package:pilipalaz/utils/utils.dart';

/// 视频分段/看点列表抽屉组件
class ChapterBottomSheet extends StatelessWidget {
  final List<VideoChapter> chapters;
  final VideoChapter? activeChapter;
  final ValueChanged<VideoChapter> onSelect;

  const ChapterBottomSheet({
    required this.chapters,
    required this.onSelect,
    this.activeChapter,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final maxHeight = min(520.0, MediaQuery.sizeOf(context).height * 0.65);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Text(
                    '看点列表',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '共 ${chapters.length} 个分段',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: chapters.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isActive = chapter == activeChapter;
                  return _buildChapterItem(
                    context: context,
                    chapter: chapter,
                    isActive: isActive,
                    primaryColor: primaryColor,
                    theme: theme,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterItem({
    required BuildContext context,
    required VideoChapter chapter,
    required bool isActive,
    required Color primaryColor,
    required ThemeData theme,
  }) {
    final hasThumb = chapter.imgUrl != null && chapter.imgUrl!.isNotEmpty;
    final timeStr =
        '${Utils.timeFormat(chapter.from)} - ${Utils.timeFormat(chapter.to)}';

    return Material(
      color: isActive
          ? primaryColor.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(chapter),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 88,
                  height: 50,
                  child: hasThumb
                      ? NetworkImgLayer(
                          src: chapter.imgUrl!,
                          width: 88,
                          height: 50,
                        )
                      : Container(
                          color: primaryColor.withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.play_circle_outline,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isActive ? primaryColor : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? primaryColor.withValues(alpha: 0.8)
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '播放中',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

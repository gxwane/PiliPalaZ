import 'package:flutter/material.dart';
import 'package:pilipalaz/pages/download/controller.dart';

/// 离线缓存存储空间占用仪表盘
class CacheDiskIndicator extends StatelessWidget {
  const CacheDiskIndicator({
    super.key,
    required this.usedBytes,
    required this.availableBytes,
  });

  final int usedBytes;
  final int availableBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int totalKnown = usedBytes + availableBytes;
    final double fraction = totalKnown > 0
        ? (usedBytes / totalKnown).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PiliPalaZ 离线缓存: ${DownloadPageController.formatBytes(usedBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '系统剩余可用: ${DownloadPageController.formatBytes(availableBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.4,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

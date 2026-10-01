import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/live/area.dart';

import '../controller.dart';

/// 直播官方分区选择吸顶胶囊栏（内联右侧微型排序入口）
class LiveAreaHeader extends StatelessWidget {
  final LiveController liveController;

  const LiveAreaHeader({super.key, required this.liveController});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final areas = liveController.areaList;
      final selectedId = liveController.selectedAreaId.value;
      final showSort = selectedId > 0;

      return RepaintBoundary(
        child: Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: areas.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final area = areas[index];
                    final isSelected = area.id == selectedId;
                    return _buildAreaChip(context, area, isSelected);
                  },
                ),
              ),
              if (showSort) ...[
                _buildDivider(context),
                _buildSortButton(context),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }

  Widget _buildSortButton(BuildContext context) {
    final theme = Theme.of(context);
    final selectedSort = liveController.selectedSortType.value;
    final isCustomSort = selectedSort == 'live_time';
    final sortLabel = isCustomSort ? '最新' : '热门';

    return PopupMenuButton<String>(
      key: const Key('live_sort_button'),
      tooltip: '排序方式',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) => liveController.switchSortType(val),
      itemBuilder: (context) => [
        _buildPopupItem(context, 'online', '热门排行', selectedSort == 'online'),
        _buildPopupItem(context, 'live_time', '最新开播', isCustomSort),
      ],
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isCustomSort
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.7,
                ),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                sortLabel,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isCustomSort
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isCustomSort
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    BuildContext context,
    String value,
    String title,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildAreaChip(
    BuildContext context,
    LiveAreaItemModel area,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: () => liveController.switchArea(area.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
          borderRadius: BorderRadius.circular(19),
        ),
        alignment: Alignment.center,
        child: Text(
          area.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

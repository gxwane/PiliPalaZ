import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller.dart';

/// 直播大分区排序切换栏（🔥 热门排行 vs ⏱️ 最新开播）
///
/// 仅在选定官方大分区（selectedAreaId > 0）时挂载显示；
/// 推荐流模式下折叠为零尺寸 SizedBox.shrink()。
class LiveSortBar extends StatelessWidget {
  final LiveController liveController;

  const LiveSortBar({super.key, required this.liveController});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedAreaId = liveController.selectedAreaId.value;
      if (selectedAreaId == 0) {
        return const SizedBox.shrink();
      }

      final selectedSort = liveController.selectedSortType.value;
      final theme = Theme.of(context);

      return RepaintBoundary(
        child: Container(
          height: 32,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '排序',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              _buildSortOption(
                context,
                label: '🔥 热门',
                sortType: 'online',
                isSelected: selectedSort == 'online',
              ),
              const SizedBox(width: 8),
              _buildSortOption(
                context,
                label: '⏱️ 最新',
                sortType: 'live_time',
                isSelected: selectedSort == 'live_time',
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSortOption(
    BuildContext context, {
    required String label,
    required String sortType,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => liveController.switchSortType(sortType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? primaryColor
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/live/area.dart';

import '../controller.dart';

/// 直播官方分区选择吸顶胶囊栏
class LiveAreaHeader extends StatelessWidget {
  final LiveController liveController;

  const LiveAreaHeader({super.key, required this.liveController});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final areas = liveController.areaList;
      final selectedId = liveController.selectedAreaId.value;

      return RepaintBoundary(
        child: Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 8),
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
      );
    });
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

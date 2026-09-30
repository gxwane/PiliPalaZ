import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/my_dialog.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import '../controller.dart';

class LiveQualitySheet extends StatelessWidget {
  final LiveRoomController controller;
  const LiveQualitySheet({required this.controller, super.key});

  static Future<void> show(
    BuildContext context,
    LiveRoomController controller,
  ) {
    final isFullScreen = controller.plPlayerController.isFullScreen.value;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isFullScreen || isLandscape) {
      return MyDialog.showCorner(
        context,
        SafeArea(
          child: SizedBox(
            width: 320,
            child: LiveQualitySheet(controller: controller),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(child: LiveQualitySheet(controller: controller)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme),
            const SizedBox(height: 12),
            _buildQualitySection(theme),
            const SizedBox(height: 12),
            _buildLinesSection(theme),
            const SizedBox(height: 12),
            _buildCodecSection(theme),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '画质与线路设置',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildQualitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('画质选择', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Obx(() {
          final qualities = controller.availableQualities;
          final current = controller.currentQn.value;
          if (qualities.isEmpty) {
            return Text('暂无可选画质', style: theme.textTheme.bodySmall);
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: qualities.map((GQnDesc q) {
              final isSelected = q.qn == current;
              final label = q.desc ?? '${q.qn}P';
              return _buildSelectChip(
                theme: theme,
                label: label,
                isSelected: isSelected,
                onTap: () => controller.changeQuality(q.qn ?? 10000),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildLinesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CDN 线路', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Obx(() {
          final lines = controller.availableLines;
          final currentLine = controller.currentLineIndex.value;
          if (lines.isEmpty) {
            return Text('默认主线', style: theme.textTheme.bodySmall);
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(lines.length, (index) {
              final isSelected = index == currentLine;
              return _buildSelectChip(
                theme: theme,
                label: lines[index],
                isSelected: isSelected,
                onTap: () => controller.changeCdnLine(index),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildCodecSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('编码格式', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Obx(() {
          final codecs = controller.availableCodecs;
          final currentCodec = controller.currentCodec.value;
          if (codecs.isEmpty) {
            return Text('默认编码', style: theme.textTheme.bodySmall);
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: codecs.map((codec) {
              final isSelected =
                  codec.toLowerCase() == currentCodec.toLowerCase();
              final label = codec.toUpperCase();
              return _buildSelectChip(
                theme: theme,
                label: label,
                isSelected: isSelected,
                onTap: () => controller.changeCodec(codec),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildSelectChip({
    required ThemeData theme,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = theme.colorScheme.primary;
    final surfaceContainer = theme.colorScheme.surfaceContainerHighest;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primary
                : surfaceContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? primary
                  : theme.dividerColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isSelected ? theme.colorScheme.onPrimary : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

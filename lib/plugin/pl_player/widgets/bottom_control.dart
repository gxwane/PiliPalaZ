import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:nil/nil.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/models/bottom_control_type.dart';
import 'package:pilipalaz/utils/feed_back.dart';
import 'dart:math';

import '../../../common/widgets/audio_video_progress_bar.dart';

const double bottomControlItemExtent = 42;

List<BottomControlType> buildDefaultBottomControlTypes({
  required bool hasEpisodes,
  required bool isEquivalentFullScreen,
  required bool hasSubtitles,
}) {
  return [
    BottomControlType.playOrPause,
    if (hasEpisodes) BottomControlType.pre,
    if (hasEpisodes) BottomControlType.next,
    if (hasSubtitles) BottomControlType.subtitle,
    if (hasEpisodes) BottomControlType.episode,
    if (isEquivalentFullScreen) BottomControlType.fit,
    BottomControlType.speed,
    BottomControlType.fullscreen,
  ];
}

class BottomControlItem {
  const BottomControlItem({required this.type, required this.child});

  final BottomControlType type;
  final Widget child;
}

class BottomControlLayoutResult {
  const BottomControlLayoutResult({
    required this.visible,
    required this.overflow,
    required this.showOverflow,
  });

  final List<BottomControlType> visible;
  final List<BottomControlType> overflow;
  final bool showOverflow;
}

BottomControlLayoutResult resolveBottomControlLayout({
  required double maxWidth,
  required List<BottomControlType> controls,
}) {
  final actions = controls
      .where(
        (type) =>
            type != BottomControlType.space &&
            type != BottomControlType.spaceButton,
      )
      .toList();
  final capacity = max(0, (maxWidth / bottomControlItemExtent).floor());

  if (actions.length <= capacity) {
    return BottomControlLayoutResult(
      visible: actions,
      overflow: const [],
      showOverflow: false,
    );
  }

  const corePriority = [
    BottomControlType.playOrPause,
    BottomControlType.fullscreen,
  ];
  final core = corePriority.where(actions.contains).toList();
  if (capacity <= core.length) {
    final selected = core.take(capacity).toSet();
    return BottomControlLayoutResult(
      visible: actions.where(selected.contains).toList(),
      overflow: actions.where((type) => !selected.contains(type)).toList(),
      showOverflow: false,
    );
  }

  final visibleSlots = capacity - 1;
  final selected = core.toSet();
  const optionalPriority = [
    BottomControlType.next,
    BottomControlType.pre,
    BottomControlType.episode,
    BottomControlType.speed,
    BottomControlType.subtitle,
    BottomControlType.fit,
  ];
  for (final type in optionalPriority) {
    if (selected.length >= visibleSlots) {
      break;
    }
    if (actions.contains(type)) {
      selected.add(type);
    }
  }
  for (final type in actions) {
    if (selected.length >= visibleSlots) {
      break;
    }
    selected.add(type);
  }

  final visible = actions.where(selected.contains).toList();
  final overflow = actions.where((type) => !selected.contains(type)).toList();
  return BottomControlLayoutResult(
    visible: visible,
    overflow: overflow,
    showOverflow: overflow.isNotEmpty,
  );
}

typedef BottomControlOverflowButtonBuilder =
    Widget Function(
      BuildContext context,
      List<BottomControlType> hiddenControls,
    );

class AdaptiveBottomControlRow extends StatelessWidget {
  const AdaptiveBottomControlRow({
    required this.controls,
    required this.overflowButtonBuilder,
    super.key,
  });

  final List<BottomControlItem> controls;
  final BottomControlOverflowButtonBuilder overflowButtonBuilder;

  static const _leadingTypes = {
    BottomControlType.playOrPause,
    BottomControlType.pre,
    BottomControlType.next,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = resolveBottomControlLayout(
          maxWidth: constraints.maxWidth,
          controls: controls.map((item) => item.type).toList(),
        );
        final itemsByType = {for (final item in controls) item.type: item};
        final visibleItems = layout.visible
            .map((type) => itemsByType[type])
            .whereType<BottomControlItem>()
            .toList();
        final leading = visibleItems
            .where((item) => _leadingTypes.contains(item.type))
            .toList();
        final fullscreen = visibleItems
            .where((item) => item.type == BottomControlType.fullscreen)
            .toList();
        final trailing = visibleItems
            .where(
              (item) =>
                  !_leadingTypes.contains(item.type) &&
                  item.type != BottomControlType.fullscreen,
            )
            .toList();
        final hasTrailing =
            trailing.isNotEmpty || fullscreen.isNotEmpty || layout.showOverflow;

        return Row(
          children: [
            ...leading.map((item) => item.child),
            if (hasTrailing) const Spacer(),
            ...trailing.map((item) => item.child),
            if (layout.showOverflow)
              overflowButtonBuilder(context, layout.overflow),
            ...fullscreen.map((item) => item.child),
          ],
        );
      },
    );
  }
}

class BottomControl extends StatelessWidget implements PreferredSizeWidget {
  final PlPlayerController? controller;
  final List<BottomControlItem> controls;
  final BottomControlOverflowButtonBuilder overflowButtonBuilder;
  const BottomControl({
    this.controller,
    required this.controls,
    required this.overflowButtonBuilder,
    super.key,
  });

  @override
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    Color colorTheme = Theme.of(context).colorScheme.primary;
    final PlPlayerController playerController = controller!;
    //阅读器限制
    Timer? accessibilityDebounce;
    double lastAnnouncedValue = -1;
    return Obx(() {
      final int value = playerController.sliderPositionSeconds.value;
      final int durationSec = playerController.durationSeconds.value;
      final int buffer = playerController.bufferedSeconds.value;
      if (value > durationSec || durationSec <= 0) {
        return nil;
      }
      bool isEquivalentFullScreen =
          playerController.isFullScreen.value ||
          !playerController.horizontalScreen &&
              MediaQuery.of(context).orientation == Orientation.landscape;
      return Container(
        color: Colors.transparent,
        height: 70 + (isEquivalentFullScreen ? Get.height * 0.08 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: 10,
                right: 10,
                bottom: 3 + (isEquivalentFullScreen ? Get.height * 0.01 : 0),
              ),
              child: Semantics(
                // label: '${(value / max * 100).round()}%',
                value: '${(value / durationSec * 100).round()}%',
                // enabled: false,
                child: ProgressBar(
                  progress: Duration(seconds: value),
                  buffered: Duration(seconds: buffer),
                  total: Duration(seconds: durationSec),
                  progressBarColor: colorTheme,
                  baseBarColor: Colors.white.withOpacity(0.2),
                  bufferedBarColor: colorTheme.withOpacity(0.4),
                  timeLabelLocation: TimeLabelLocation.sides,
                  timeLabelTextStyle: const TextStyle(color: Colors.white),
                  // timeLabelLocation: TimeLabelLocation.none,
                  thumbColor: colorTheme,
                  barHeight: 3.5,
                  thumbRadius: 7,
                  onDragStart: (duration) {
                    feedBack();
                    playerController.onChangedSliderStart();
                  },
                  onDragUpdate: (duration) {
                    double newProgress =
                        duration.timeStamp.inSeconds / durationSec;
                    if ((newProgress - lastAnnouncedValue).abs() > 0.02) {
                      accessibilityDebounce?.cancel();
                      accessibilityDebounce = Timer(
                        const Duration(milliseconds: 200),
                        () {
                          SemanticsService.announce(
                            "${(newProgress * 100).round()}%",
                            TextDirection.ltr,
                          );
                          lastAnnouncedValue = newProgress;
                        },
                      );
                    }
                    playerController.onUpdatedSliderProgress(
                      duration.timeStamp,
                    );
                  },
                  onSeek: (duration) {
                    playerController.onChangedSliderEnd();
                    playerController.onChangedSlider(
                      duration.inSeconds.toDouble(),
                    );
                    playerController.seekTo(
                      Duration(seconds: duration.inSeconds),
                      type: 'slider',
                    );
                    SemanticsService.announce(
                      "${(duration.inSeconds / durationSec * 100).round()}%",
                      TextDirection.ltr,
                    );
                  },
                ),
              ),
            ),
            AdaptiveBottomControlRow(
              controls: controls,
              overflowButtonBuilder: overflowButtonBuilder,
            ),
            const SizedBox(height: 6),
            if (isEquivalentFullScreen)
              SizedBox(height: max(Get.height * 0.08 - 15, 0)),
          ],
        ),
      );
    });
  }
}

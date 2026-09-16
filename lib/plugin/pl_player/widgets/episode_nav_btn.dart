import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/common_btn.dart';

class PreEpisodeButton extends StatelessWidget {
  final PlaybackQueueController? queueController;
  final VoidCallback? onPlay;

  const PreEpisodeButton({super.key, this.queueController, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final qc = queueController;
    if (qc == null) {
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: ComBtn(
          semanticsLabel: '上一集',
          icon: const Icon(Icons.skip_previous, size: 22, color: Colors.white),
          fuc: onPlay,
        ),
      );
    }

    return Obx(() {
      final bool hasPrev = qc.hasPrevious.value;
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: ComBtn(
          semanticsLabel: '上一集',
          icon: Icon(
            Icons.skip_previous,
            size: 22,
            color: hasPrev ? Colors.white : Colors.white38,
          ),
          fuc: hasPrev ? onPlay : null,
        ),
      );
    });
  }
}

class NextEpisodeButton extends StatelessWidget {
  final PlaybackQueueController? queueController;
  final VoidCallback? onPlay;

  const NextEpisodeButton({super.key, this.queueController, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final qc = queueController;
    if (qc == null) {
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: ComBtn(
          semanticsLabel: '下一集',
          icon: const Icon(Icons.skip_next, size: 22, color: Colors.white),
          fuc: onPlay,
        ),
      );
    }

    return Obx(() {
      final bool hasNxt = qc.hasNext.value;
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: ComBtn(
          semanticsLabel: '下一集',
          icon: Icon(
            Icons.skip_next,
            size: 22,
            color: hasNxt ? Colors.white : Colors.white38,
          ),
          fuc: hasNxt ? onPlay : null,
        ),
      );
    });
  }
}

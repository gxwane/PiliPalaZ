import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';

class PlayOrPauseButton extends StatelessWidget {
  final double? iconSize;
  final Color? iconColor;
  final PlPlayerController? controller;

  const PlayOrPauseButton({
    super.key,
    this.iconSize,
    this.iconColor,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final PlPlayerController? controller = this.controller;
    return Obx(() {
      final bool canControl = controller?.canControlPlayback ?? false;
      final bool playing = controller?.isPlaying ?? false;
      return SizedBox(
        width: 42,
        height: 38,
        child: InkWell(
          onTap: canControl ? controller!.togglePlay : null,
          child: Center(
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              semanticLabel: playing ? '暂停' : '播放',
              color: canControl ? (iconColor ?? Colors.white) : Colors.white54,
              size: iconSize ?? 24,
            ),
          ),
        ),
      );
    });
  }
}

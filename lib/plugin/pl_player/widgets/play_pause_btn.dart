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
    if (this.controller == null) {
      return Semantics(
        button: true,
        enabled: false,
        label: '开始播放',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: InkWell(
            onTap: null,
            child: Center(
              child: Icon(
                Icons.play_arrow,
                color: Colors.white54,
                size: iconSize ?? 24,
              ),
            ),
          ),
        ),
      );
    }
    final PlPlayerController? controller = this.controller;
    return Obx(() {
      final bool canControl = controller?.canControlPlayback ?? false;
      final bool playing = controller?.isPlaying ?? false;
      return Semantics(
        button: true,
        enabled: canControl,
        label: playing ? '暂停播放' : '开始播放',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: InkWell(
            onTap: canControl ? controller!.togglePlay : null,
            child: Center(
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                color:
                    canControl ? (iconColor ?? Colors.white) : Colors.white54,
                size: iconSize ?? 24,
              ),
            ),
          ),
        ),
      );
    });
  }
}

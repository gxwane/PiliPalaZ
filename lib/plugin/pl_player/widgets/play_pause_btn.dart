import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/playback_lifecycle.dart';

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
    final PlPlayerController? activeController = controller;
    if (activeController == null) {
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
    return Obx(() {
      final PlayerStatus status = activeController.playerStatus.status.value;
      final PlaybackLifecycleState lifecycle =
          activeController.playbackLifecycleState.value;
      final bool canControl =
          lifecycle == PlaybackLifecycleState.ready &&
          activeController.canControlPlayback;
      final bool playing = canControl && status == PlayerStatus.playing;
      return Semantics(
        button: true,
        enabled: canControl,
        label: playing ? '暂停播放' : '开始播放',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: InkWell(
            onTap: canControl ? activeController.togglePlay : null,
            child: Center(
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                color: canControl
                    ? (iconColor ?? Colors.white)
                    : Colors.white54,
                size: iconSize ?? 24,
              ),
            ),
          ),
        ),
      );
    });
  }
}

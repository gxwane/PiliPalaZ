import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/pages/live_room/controller.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/utils/storage.dart';

class LiveDanmaku extends StatefulWidget {
  final LiveRoomController liveRoomCtr;
  final PlPlayerController playerController;

  const LiveDanmaku({
    super.key,
    required this.liveRoomCtr,
    required this.playerController,
  });

  @override
  State<LiveDanmaku> createState() => _LiveDanmakuState();
}

class _LiveDanmakuState extends State<LiveDanmaku> {
  DanmakuController? _controller;
  final Box setting = GStorage.setting;

  @override
  void initState() {
    super.initState();
    final bool enableShowDanmaku =
        setting.get(SettingBoxKey.enableShowDanmaku, defaultValue: true)
            as bool;
    debugPrint(
      '[LiveDanmakuWidget] initState: enableShowDanmaku=$enableShowDanmaku',
    );
    widget.playerController.isOpenDanmu.value = enableShowDanmaku;
    widget.playerController.addStatusLister(_playerListener);
  }

  void _playerListener(PlayerStatus? status) {
    debugPrint(
      '[LiveDanmakuWidget] _playerListener: status=$status, hasCtr=${_controller != null}',
    );
    if (status == PlayerStatus.playing) {
      _controller?.resume();
    } else {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    widget.playerController.removeStatusLister(_playerListener);
    if (widget.playerController.danmakuController == _controller) {
      widget.playerController.danmakuController = null;
    }
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedOpacity(
        opacity: widget.playerController.isOpenDanmu.value ? 1 : 0,
        duration: const Duration(milliseconds: 100),
        child: DanmakuScreen(
          createdController: (DanmakuController e) async {
            debugPrint(
              '[LiveDanmakuWidget] DanmakuScreen createdController attached!',
            );
            widget.playerController.danmakuController = _controller = e;
            if (widget.playerController.playerStatus.playing) {
              _controller?.resume();
            }
          },
          option: DanmakuOption(
            fontSize: 15 * widget.playerController.fontSizeVal,
            fontWeight: widget.playerController.fontWeight,
            area: widget.playerController.showArea,
            opacity: widget.playerController.opacityVal,
            duration: widget.playerController.danmakuDurationVal,
            strokeWidth: widget.playerController.strokeWidth,
            massiveMode: widget.playerController.massiveMode,
          ),
        ),
      ),
    );
  }
}

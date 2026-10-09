import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';
import 'package:pilipalaz/pages/danmaku/index.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/utils/danmaku.dart';
import 'package:pilipalaz/utils/storage.dart';

/// 传入播放器控制器，监听播放进度，加载对应弹幕
class PlDanmaku extends StatefulWidget {
  final int cid;
  final PlPlayerController playerController;
  final bool isOffline;
  final File? offlineDanmakuFile;

  const PlDanmaku({
    super.key,
    required this.cid,
    required this.playerController,
    this.isOffline = false,
    this.offlineDanmakuFile,
  });

  @override
  State<PlDanmaku> createState() => _PlDanmakuState();
}

class _PlDanmakuState extends State<PlDanmaku> {
  late PlPlayerController playerController;
  late PlDanmakuController _plDanmakuController;
  DanmakuController? _controller;
  // bool danmuPlayStatus = true;
  Box setting = GStorage.setting;
  late bool enableShowDanmaku;
  late List blockTypes;
  late double showArea;
  late double opacityVal;
  late double fontSizeVal;
  late int danmakuDurationVal;
  late double strokeWidth;
  late int fontWeight;
  late bool massiveMode;
  int latestAddedPosition = -1;
  StreamSubscription<bool>? _openDanmuSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  void initState() {
    super.initState();
    enableShowDanmaku = setting.get(
      SettingBoxKey.enableShowDanmaku,
      defaultValue: true,
    );
    _plDanmakuController = PlDanmakuController(
      widget.cid,
      isOffline: widget.isOffline,
    );
    if (mounted) {
      playerController = widget.playerController;
      playerController.plDanmakuController = _plDanmakuController;
      if (enableShowDanmaku || playerController.isOpenDanmu.value) {
        _plDanmakuController.initiate(
          playerController.duration.value.inMilliseconds,
          playerController.position.value.inMilliseconds,
          offlineDanmakuFile: widget.offlineDanmakuFile,
        );
      }
      playerController
        ..addStatusLister(playerListener)
        ..addPositionListener(videoPositionListen);
    }
    _openDanmuSub = playerController.isOpenDanmu.listen((p0) {
      if (p0 && !_plDanmakuController.initiated) {
        _plDanmakuController.initiate(
          playerController.duration.value.inMilliseconds,
          playerController.position.value.inMilliseconds,
          offlineDanmakuFile: widget.offlineDanmakuFile,
        );
      }
    });
    _durationSub = playerController.duration.listen((d) {
      if (d.inMilliseconds > 0 &&
          !_plDanmakuController.initiated &&
          (enableShowDanmaku || playerController.isOpenDanmu.value)) {
        _plDanmakuController.initiate(
          d.inMilliseconds,
          playerController.position.value.inMilliseconds,
          offlineDanmakuFile: widget.offlineDanmakuFile,
        );
      }
    });
    blockTypes = playerController.blockTypes;
    showArea = playerController.showArea;
    opacityVal = playerController.opacityVal;
    fontSizeVal = playerController.fontSizeVal;
    strokeWidth = playerController.strokeWidth;
    fontWeight = playerController.fontWeight;
    danmakuDurationVal = playerController.danmakuDurationVal;
    massiveMode = playerController.massiveMode;
  }

  // 播放器状态监听
  void playerListener(PlayerStatus? status) {
    if (status == PlayerStatus.playing) {
      _controller?.onResume();
      _flushPendingLocalDanmakus();
    } else {
      _controller?.pause();
    }
  }

  /// 恢复起播时将暂停期间发射的自发弹幕即刻推流，保证起播瞬间准时呈现且不跑飞
  void _flushPendingLocalDanmakus() {
    final pending = _plDanmakuController.drainPendingLocalDanmakus();
    if (pending.isNotEmpty && _controller != null) {
      Color? defaultColor = playerController.blockTypes.contains(6)
          ? Colors.white
          : null;
      DanmakuItemType convertType(int type) {
        if (PlDanmakuController.convertToScrollDanmaku &&
            playerController.blockTypes.contains(type)) {
          return DanmakuItemType.scroll;
        } else {
          return DmUtils.getPosition(type);
        }
      }

      for (final e in pending) {
        _controller!.addDanmaku(
          DanmakuContentItem(
            e.content,
            color: defaultColor ?? DmUtils.decimalToColor(e.color),
            type: convertType(e.mode),
            selfSend: true,
          ),
        );
      }
    }
  }

  void videoPositionListen(Duration position) {
    if (!playerController.isOpenDanmu.value) {
      return;
    }
    int currentPosition = position.inMilliseconds;
    currentPosition -= currentPosition % 100; //取整百的毫秒数

    if (currentPosition == latestAddedPosition) {
      return;
    }
    latestAddedPosition = currentPosition;

    List<DanmakuElem>? currentDanmakuList = _plDanmakuController
        .getCurrentDanmaku(currentPosition);

    if (currentDanmakuList != null && _controller != null) {
      Color? defaultColor = playerController.blockTypes.contains(6)
          ? Colors
                .white //DmUtils.decimalToColor(16777215)
          : null;
      DanmakuItemType convertType(int type) {
        if (PlDanmakuController.convertToScrollDanmaku &&
            playerController.blockTypes.contains(type)) {
          return DanmakuItemType.scroll;
        } else {
          return DmUtils.getPosition(type);
        }
      }

      for (final e in currentDanmakuList) {
        // 如果是刚刚在播放中即时发射并已渲染的自发弹幕，跳过本次帧监听的重复渲染
        if (_plDanmakuController.renderedLocalDanmakuIds.remove(e.idStr)) {
          continue;
        }
        final bool isSelfSend = e.idStr.startsWith('local_') || e.weight >= 100;
        _controller!.addDanmaku(
          DanmakuContentItem(
            e.content,
            color: defaultColor ?? DmUtils.decimalToColor(e.color),
            type: convertType(e.mode),
            selfSend: isSelfSend,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _openDanmuSub?.cancel();
    _durationSub?.cancel();
    playerController.removePositionListener(videoPositionListen);
    playerController.removeStatusLister(playerListener);
    if (playerController.plDanmakuController == _plDanmakuController) {
      playerController.plDanmakuController = null;
    }
    _plDanmakuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // double initDuration = box.maxWidth / 12;
        return Obx(
          () => AnimatedOpacity(
            opacity: playerController.isOpenDanmu.value ? 1 : 0,
            duration: const Duration(milliseconds: 100),
            child: DanmakuScreen(
              createdController: (DanmakuController e) async {
                playerController.danmakuController = _controller = e;
              },
              option: DanmakuOption(
                fontSize: 15 * fontSizeVal,
                fontWeight: fontWeight,
                area: showArea,
                opacity: opacityVal,
                hideTop: blockTypes.contains(5),
                hideScroll: blockTypes.contains(2),
                hideBottom: blockTypes.contains(4),
                duration: (danmakuDurationVal / playerController.playbackSpeed)
                    .round(),
                strokeWidth: strokeWidth,
                // initDuration /
                //     (danmakuSpeedVal * widget.playerController.playbackSpeed),
              ),
            ),
          ),
        );
      },
    );
  }
}

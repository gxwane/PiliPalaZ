import 'dart:async';
import 'dart:io';

import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating/floating/manager/floating_manager.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/models/live/room_info_h5.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/screen_utils.dart';

import 'controller.dart';
import 'widgets/bottom_control.dart';
import 'widgets/live_danmaku.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late final String _tag;
  late final LiveRoomController _liveRoomController;
  PlPlayerController? plPlayerController;
  late Future<ApiResult<RoomInfoH5Model>>? _futureBuilder;
  late Future<ApiResult<RoomInfoModel>>? _futureBuilderFuture;

  bool isShowCover = true;
  bool isPlay = true;

  @override
  void initState() {
    super.initState();
    final argRoomId = Get.arguments is Map
        ? (Get.arguments['roomId'] ??
              Get.arguments['roomid'] ??
              Get.arguments['heroTag'])
        : null;
    final paramRoomId =
        Get.parameters['roomid'] ??
        Get.parameters['roomId'] ??
        Get.parameters['room_id'];
    final roomId = (paramRoomId != null && paramRoomId != '0')
        ? paramRoomId
        : (argRoomId?.toString() ?? '0');
    _tag = 'live_${roomId}_$hashCode';
    _liveRoomController = Get.put(LiveRoomController(), tag: _tag);
    if (_liveRoomController.roomId == 0) {
      _liveRoomController.roomId = int.tryParse(roomId) ?? 0;
    }
    videoSourceInit();
    _futureBuilderFuture = _liveRoomController.queryLiveInfo();
    plPlayerController?.autoEnterFullScreen();
    floatingManager.closeFloating(globalId);
  }

  Future<void> videoSourceInit() async {
    _futureBuilder = _liveRoomController.queryLiveInfoH5();
    plPlayerController = _liveRoomController.plPlayerController;
  }

  @override
  void dispose() {
    Get.delete<LiveRoomController>(tag: _tag);
    if (!ScreenUtils.isTabletDevice()) {
      unawaited(verticalScreen());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget videoPlayerPanel = FutureBuilder<ApiResult<RoomInfoModel>>(
      future: _futureBuilderFuture,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.data is ApiSuccess<RoomInfoModel>) {
          return Obx(() {
            if (_liveRoomController.hasStream.value &&
                plPlayerController != null) {
              return PLVideoPlayer(
                controller: plPlayerController!,
                bottomControl: BottomControl(
                  controller: plPlayerController,
                  liveRoomCtr: _liveRoomController,
                ),
                danmuWidget: LiveDanmaku(
                  liveRoomCtr: _liveRoomController,
                  playerController: plPlayerController!,
                ),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.tv_off_rounded,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _liveRoomController.isLive.value ? '暂无可用直播流' : '主播未开播',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            );
          });
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        } else {
          return Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _futureBuilderFuture = _liveRoomController.queryLiveInfo();
                });
              },
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text(
                '加载失败，点击重试',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
      },
    );

    final Widget childWhenDisabled = Scaffold(
      primary: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.8,
              child: Image.asset(
                'assets/images/live/default_bg.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Obx(() {
            final appBg =
                _liveRoomController.roomInfoH5.value.roomInfo?.appBackground;
            if (appBg != null && appBg.isNotEmpty) {
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Opacity(
                  opacity: 0.8,
                  child: NetworkImgLayer(
                    width: Get.width,
                    height: Get.height,
                    type: 'bg',
                    src: appBg,
                  ),
                ),
              );
            }
            return const SizedBox();
          }),
          Column(
            children: [
              AppBar(
                centerTitle: false,
                titleSpacing: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                toolbarHeight:
                    MediaQuery.of(context).orientation == Orientation.portrait
                    ? 56
                    : 0,
                title: FutureBuilder<ApiResult<RoomInfoH5Model>>(
                  future: _futureBuilder,
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return const SizedBox();
                    }
                    if (snapshot.data is ApiSuccess<RoomInfoH5Model>) {
                      return Obx(() {
                        final uname =
                            _liveRoomController
                                .roomInfoH5
                                .value
                                .anchorInfo
                                ?.baseInfo
                                ?.uname ??
                            '';
                        final face =
                            _liveRoomController
                                .roomInfoH5
                                .value
                                .anchorInfo
                                ?.baseInfo
                                ?.face ??
                            '';
                        final watchedText = _liveRoomController
                            .roomInfoH5
                            .value
                            .watchedShow?['text_large'];
                        return Row(
                          children: [
                            NetworkImgLayer(
                              width: 34,
                              height: 34,
                              type: 'avatar',
                              src: face,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  uname.isNotEmpty ? uname : '直播间',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 1),
                                if (watchedText != null)
                                  Text(
                                    watchedText.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            // 刷新
                            IconButton(
                              tooltip: '刷新',
                              onPressed: () {
                                setState(() {
                                  _futureBuilderFuture = _liveRoomController
                                      .queryLiveInfo();
                                });
                              },
                              icon: const Icon(Icons.refresh),
                            ),
                            // 内置浏览器打开
                            IconButton(
                              tooltip: '内置浏览器打开',
                              onPressed: () {
                                Get.offNamed(
                                  '/webview',
                                  parameters: {
                                    'url':
                                        'https://live.bilibili.com/h5/${_liveRoomController.roomId}',
                                    'type': 'liveRoom',
                                    'pageTitle': uname.isNotEmpty
                                        ? uname
                                        : '直播间',
                                  },
                                );
                              },
                              icon: const Icon(Icons.open_in_browser),
                            ),
                          ],
                        );
                      });
                    } else {
                      return const SizedBox();
                    }
                  },
                ),
              ),
              PopScope(
                canPop: plPlayerController?.isFullScreen.value != true,
                onPopInvokedWithResult: (bool didPop, Object? result) {
                  if (plPlayerController?.isFullScreen.value == true) {
                    plPlayerController!.triggerFullScreen(status: false);
                  }
                  if (MediaQuery.of(context).orientation ==
                          Orientation.landscape &&
                      !ScreenUtils.isTabletDevice()) {
                    unawaited(verticalScreenForTwoSeconds());
                  }
                },
                child: SizedBox(
                  width: Get.size.width,
                  height:
                      MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? Get.size.height
                      : Get.size.width * 9 / 16,
                  child: videoPlayerPanel,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!Platform.isAndroid) {
      return childWhenDisabled;
    }
    return PiPBuilder(
      builder: (PiPStatusInfo? statusInfo) {
        switch (statusInfo?.status) {
          case PiPStatus.enabled:
            return videoPlayerPanel;
          case PiPStatus.disabled:
          case PiPStatus.unavailable:
          case null:
            return childWhenDisabled;
        }
      },
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating/floating/manager/floating_manager.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/models/live/room_info_h5.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/screen_utils.dart';

import 'controller.dart';
import 'widgets/bottom_control.dart';
import 'widgets/live_anchor_strip.dart';
import 'widgets/live_chat_panel.dart';
import 'widgets/live_danmaku.dart';
import 'widgets/live_input_bar.dart';
import 'widgets/live_nav_helper.dart';
import 'widgets/live_room_paging_controller.dart';
import 'widgets/live_room_preview_card.dart';
import 'widgets/live_sc_ticker.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late final String _tag;
  late final LiveRoomController _liveRoomController;
  late final LiveRoomPlaylistManager _playlistManager;
  PlPlayerController? plPlayerController;
  late Future<ApiResult<RoomInfoH5Model>>? _futureBuilder;
  late Future<ApiResult<RoomInfoModel>>? _futureBuilderFuture;

  bool isShowCover = true;
  bool isPlay = true;

  @override
  void initState() {
    super.initState();
    final argMap = Get.arguments is Map ? (Get.arguments as Map) : null;
    final argRoomId =
        argMap?['roomId'] ?? argMap?['roomid'] ?? argMap?['heroTag'];
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

    final liveList = argMap?['liveList'] as List<LiveItemModel>?;
    final initialIndex = argMap?['initialIndex'] as int? ?? 0;
    final liveItem = argMap?['liveItem'] as LiveItemModel?;
    final parentAreaId = argMap?['parentAreaId'] as int?;
    final sortType = argMap?['sortType'] as String?;

    _playlistManager = LiveRoomPlaylistManager(initialIndex: initialIndex);
    _playlistManager.initDualEntry(
      initialList: liveList,
      initialIndex: initialIndex,
      initialRoomId: _liveRoomController.roomId,
      initialItem: liveItem,
      parentAreaId: parentAreaId,
      sortType: sortType,
    );

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
    _playlistManager.dispose();
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
                key: const ValueKey('single_active_live_player'),
                controller: plPlayerController!,
                enableVerticalGesture:
                    plPlayerController?.isFullScreen.value == true,
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

    final Widget childWhenDisabled = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Obx(() {
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final isFullScreen = plPlayerController?.isFullScreen.value == true;
        final physics = (isFullScreen || isLandscape)
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics();

        return PageView.builder(
          controller: _playlistManager.pageController,
          scrollDirection: Axis.vertical,
          physics: physics,
          itemCount: _playlistManager.playlist.length,
          itemBuilder: (context, index) {
            return Obx(() {
              if (index == _playlistManager.currentIndex.value) {
                return _buildActiveRoomView(context, videoPlayerPanel);
              }
              return LiveRoomPreviewCard(
                item: _playlistManager.playlist[index],
              );
            });
          },
        );
      }),
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

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final page = _playlistManager.pageController.page;
      if (page != null && (page - page.round()).abs() < 0.001) {
        final targetIndex = page.round();
        if (targetIndex != _playlistManager.currentIndex.value &&
            targetIndex >= 0 &&
            targetIndex < _playlistManager.playlist.length) {
          _commitRoomSwitch(targetIndex);
        }
      }
    }
    return false;
  }

  void _commitRoomSwitch(int targetIndex) {
    _playlistManager.currentIndex.value = targetIndex;
    final targetItem = _playlistManager.playlist[targetIndex];
    final targetRoomId = targetItem.roomId ?? 0;
    if (targetRoomId > 0) {
      setState(() {
        _futureBuilderFuture = _liveRoomController.switchRoom(
          targetRoomId,
          item: targetItem,
        );
        _futureBuilder = _liveRoomController.latestH5Future;
      });
      unawaited(_playlistManager.checkAndPreloadMore(targetIndex));
    }
  }

  Widget _buildActiveRoomView(BuildContext context, Widget videoPlayerPanel) {
    return Scaffold(
      primary: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAppBackground(),
          Column(
            children: [
              _buildTopAppBar(context),
              _buildPlayerContainer(context, videoPlayerPanel),
              if (MediaQuery.of(context).orientation != Orientation.landscape)
                Expanded(child: _buildPortraitContent(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBackground() {
    return Stack(
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
      ],
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      toolbarHeight: isPortrait ? 56 : 0,
      title: FutureBuilder<ApiResult<RoomInfoH5Model>>(
        future: _futureBuilder,
        builder: (context, snapshot) {
          if (snapshot.data is ApiSuccess<RoomInfoH5Model>) {
            return _buildAnchorInfoRow(context);
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildAnchorInfoRow(BuildContext context) {
    return Obx(() {
      final h5 = _liveRoomController.roomInfoH5.value;
      final uname = h5.anchorInfo?.baseInfo?.uname ?? '';
      final face = h5.anchorInfo?.baseInfo?.face ?? '';
      final watchedText = h5.watchedShow?['text_large'];
      final mid = h5.roomInfo?.uid ?? 0;

      return Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () =>
                LiveNavHelper.navigateToAnchorMember(context, mid, face),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: NetworkImgLayer(
                    width: 34,
                    height: 34,
                    type: 'avatar',
                    src: face,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uname.isNotEmpty ? uname : '直播间',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    if (watchedText != null)
                      Text(
                        watchedText.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '刷新',
            onPressed: () {
              setState(() {
                _futureBuilderFuture = _liveRoomController.queryLiveInfo();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '内置浏览器打开',
            onPressed: () {
              Get.offNamed(
                '/webview',
                parameters: {
                  'url':
                      'https://live.bilibili.com/h5/${_liveRoomController.roomId}',
                  'type': 'liveRoom',
                  'pageTitle': uname.isNotEmpty ? uname : '直播间',
                },
              );
            },
            icon: const Icon(Icons.open_in_browser),
          ),
        ],
      );
    });
  }

  Widget _buildPlayerContainer(BuildContext context, Widget videoPlayerPanel) {
    return PopScope(
      canPop: plPlayerController?.isFullScreen.value != true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (plPlayerController?.isFullScreen.value == true) {
          plPlayerController!.triggerFullScreen(status: false);
        }
        if (MediaQuery.of(context).orientation == Orientation.landscape &&
            !ScreenUtils.isTabletDevice()) {
          unawaited(verticalScreenForTwoSeconds());
        }
      },
      child: SizedBox(
        width: Get.size.width,
        height: MediaQuery.of(context).orientation == Orientation.landscape
            ? Get.size.height
            : Get.size.width * 9 / 16,
        child: videoPlayerPanel,
      ),
    );
  }

  Widget _buildPortraitContent(BuildContext context) {
    return Column(
      children: [
        LiveAnchorStrip(liveRoomCtr: _liveRoomController),
        LiveScTicker(chatController: _liveRoomController.chatController),
        Expanded(
          child: Obx(
            () => LiveChatPanel(
              chatController: _liveRoomController.chatController,
              anchorUid:
                  _liveRoomController.roomInfoH5.value.roomInfo?.uid ?? 0,
            ),
          ),
        ),
        LiveInputBar(
          key: ValueKey('live_input_${_liveRoomController.roomId}'),
          roomId: _liveRoomController.roomId,
        ),
      ],
    );
  }
}

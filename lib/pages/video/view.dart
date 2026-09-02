import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:pilipalaz/services/service_locator.dart';
import 'package:fl_pip/fl_pip.dart';
// import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/common/video_source_type.dart';
import 'package:pilipalaz/pages/video/introduction/bangumi/index.dart';
import 'package:pilipalaz/pages/danmaku/view.dart';
import 'package:pilipalaz/pages/video/reply/index.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/playback_input.dart';
import 'package:pilipalaz/pages/video/introduction/detail/index.dart';
import 'package:pilipalaz/pages/video/related/index.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipalaz/utils/storage.dart';

import '../../../services/shutdown_timer_service.dart';
import 'widgets/header_control.dart';
import 'package:pilipalaz/common/widgets/spring_physics.dart';
import 'package:flutter_floating/floating/manager/floating_manager.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({super.key});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
}

class _VideoDetailPageState extends State<VideoDetailPage>
    with TickerProviderStateMixin, RouteAware {
  late VideoDetailController videoDetailController;
  PlPlayerController? plPlayerController;
  late StreamController<double> appbarStream;
  late VideoIntroController videoIntroController;
  late BangumiIntroController bangumiIntroController;
  late String heroTag;

  PlayerStatus playerStatus = PlayerStatus.playing;
  double doubleOffset = 0;

  final Box<dynamic> localCache = GStorage.localCache;
  final Box<dynamic> setting = GStorage.setting;
  late Future _futureBuilderFuture;
  // 自动退出全屏
  late bool autoExitFullscreen;
  late bool horizontalScreen;
  late bool enableVerticalExpand;
  late bool autoPiP;
  late bool pipNoDanmaku;
  late bool removeSafeArea;
  late bool showStatusBarBackgroundColor;
  // 生命周期监听
  // late final AppLifecycleListener _lifecycleListener;
  // bool isShowing = true;
  RxBool isFullScreen = false.obs;
  StreamSubscription<bool>? fullScreenStatusListener;
  // late final MethodChannel onUserLeaveHintListener;
  // StreamSubscription<Duration>? _bufferedListener;
  late String myRouteName;
  bool isShowing = true;
  bool _wasPlayingBeforePush = false;
  final GlobalKey relatedVideoPanelKey = GlobalKey();
  final GlobalKey videoReplyPanelKey = GlobalKey();
  final GlobalKey scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    if (Get.arguments != null && Get.arguments['heroTag'] != null) {
      heroTag = Get.arguments['heroTag'];
    }
    // print('heroTagView:$heroTag');
    myRouteName = Get.rawRoute!.settings.name!;
    videoDetailController = Get.put(VideoDetailController(), tag: heroTag);
    if (!videoDetailController.autoPlay.value &&
        floatingManager.containsFloating(globalId)) {
      PlPlayerController.pauseIfExists();
    }
    videoIntroController = Get.put(VideoIntroController(), tag: heroTag);
    // videoIntroController.videoDetail.listen((value) {
    //   if (!context.mounted) return;
    //   videoPlayerServiceHandler.onVideoDetailChange(
    //       value, videoDetailController.cid.value);
    // });
    bangumiIntroController = Get.put(BangumiIntroController(), tag: heroTag);
    // bangumiIntroController.bangumiDetail.listen((value) {
    //   if (!context.mounted) return;
    //   videoPlayerServiceHandler.onVideoDetailChange(
    //       value, videoDetailController.cid.value);
    // });
    // videoDetailController.cid.listen((p0) {
    //   if (!context.mounted) return;
    //   videoPlayerServiceHandler.onVideoDetailChange(
    //       bangumiIntroController.bangumiDetail.value, p0);
    // });
    autoExitFullscreen = setting.get(
      SettingBoxKey.enableAutoExit,
      defaultValue: true,
    );
    horizontalScreen = setting.get(
      SettingBoxKey.horizontalScreen,
      defaultValue: false,
    );
    autoPiP = setting.get(SettingBoxKey.autoPiP, defaultValue: false);
    pipNoDanmaku = setting.get(SettingBoxKey.pipNoDanmaku, defaultValue: true);
    enableVerticalExpand = setting.get(
      SettingBoxKey.enableVerticalExpand,
      defaultValue: false,
    );
    removeSafeArea = setting.get(
      SettingBoxKey.videoPlayerRemoveSafeArea,
      defaultValue: false,
    );
    showStatusBarBackgroundColor = setting.get(
      SettingBoxKey.videoPlayerShowStatusBarBackgroundColor,
      defaultValue: false,
    );
    if (removeSafeArea) hideStatusBar();
    floatingManager.closeFloating(globalId);
    videoSourceInit();
    appbarStreamListen();
    // lifecycleListener();
    autoScreen();

    // onUserLeaveHintListener = const MethodChannel("onUserLeaveHint");
    // onUserLeaveHintListener.setMethodCallHandler((call) async {
    //   if (call.method == 'onUserLeaveHint') {
    //     if (autoPiP &&
    //         plPlayerController != null &&
    //         playerStatus == PlayerStatus.playing) {
    //       autoEnterPip();
    //     }
    //   }
    // });
    // _animationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 300),
    // );
    // _animation = Tween<double>(
    //   begin: MediaQuery.of(context).orientation == Orientation.landscape
    //       ? context.height
    //       : ((enableVerticalExpand &&
    //               plPlayerController?.direction.value == 'vertical')
    //           ? context.width * 5 / 4
    //           : context.width * 9 / 16),
    //   end: 0,
    // ).animate(_animationController);
  }

  // 获取视频资源，初始化播放器
  Future<void> videoSourceInit() async {
    _futureBuilderFuture = videoDetailController.queryVideoUrl();
    if (videoDetailController.autoPlay.value) {
      plPlayerController = videoDetailController.plPlayerController;
      plPlayerController!.addStatusLister(playerListener);
      listenFullScreenStatus();
      await plPlayerController!.autoEnterFullScreen();
      // Future.wait([_futureBuilderFuture]).then((result) {
      //   autoEnterPip();
      // });
    } else {
      _futureBuilderFuture.then((value) async {
        if (value['status']) {
          // fix: 手动播放首个视频前媒体通知不完整
          videoPlayerServiceHandler.onStatusChange(PlayerStatus.paused, false);
          plPlayerController = videoDetailController.plPlayerController;
          plPlayerController!.addStatusLister(playerListener);
          listenFullScreenStatus();
          if (mounted) setState(() {});
        }
      });
    }
  }

  Future<void> retryVideoSource() async {
    final Future<dynamic> retryFuture = videoDetailController.queryVideoUrl();
    _futureBuilderFuture = retryFuture;
    final dynamic result = await retryFuture;
    if (!mounted ||
        videoDetailController.autoPlay.value ||
        result is! Map ||
        result['status'] != true) {
      return;
    }
    videoPlayerServiceHandler.onStatusChange(PlayerStatus.paused, false);
    plPlayerController = videoDetailController.plPlayerController;
    if (!mounted || plPlayerController == null) return;
    plPlayerController!.addStatusLister(playerListener);
    listenFullScreenStatus();
    setState(() {});
  }

  // void autoEnterPip() {
  //   String top = Get.currentRoute;
  //   if (autoPiP && (top.startsWith('/video') || top.startsWith('/live') || floatingManager.containsFloating(globalId))) {
  //     FlPiP().enable(
  //         ios: FlPiPiOSConfig(
  //             enabledWhenBackground: true,
  //             videoPath: videoDetailController.videoUrl,
  //             audioPath: videoDetailController.audioUrl,
  //             packageName: null),
  //         android: FlPiPAndroidConfig(
  //           enabledWhenBackground: true,
  //           aspectRatio: Rational(
  //             videoDetailController.data.dash!.video!.first.width!,
  //             videoDetailController.data.dash!.video!.first.height!,
  //           ),
  //         ));
  //   }
  // }

  // 流
  appbarStreamListen() {
    appbarStream = StreamController<double>();
  }

  // 播放器状态监听
  void playerListener(PlayerStatus? status) async {
    print("playerListener $status");
    playerStatus = status!;
    switch (status) {
      case PlayerStatus.playing:
        if (videoDetailController.isShowCover.value) {
          videoDetailController.isShowCover.value = false;
        }
        break;
      case PlayerStatus.completed:
        shutdownTimerService.handleWaitingFinished();
        bool notExitFlag = false;
        final bool previewEnded =
            videoDetailController.sourceType.isPgc &&
            videoDetailController.data.isPreview;

        if (previewEnded) {
          bangumiIntroController.showPreviewEnded();
        }

        /// 顺序播放 列表循环
        if (!previewEnded &&
            plPlayerController!.playRepeat != PlayRepeat.pause &&
            plPlayerController!.playRepeat != PlayRepeat.singleCycle) {
          if (!videoDetailController.sourceType.isPgc) {
            notExitFlag = videoIntroController.nextPlay();
          }
          if (videoDetailController.sourceType.isPgc) {
            notExitFlag = bangumiIntroController.nextPlay();
          }
        }

        /// 单个循环
        if (!previewEnded &&
            plPlayerController!.playRepeat == PlayRepeat.singleCycle) {
          notExitFlag = true;
          plPlayerController!.play(repeat: true);
        }

        // 结束播放退出全屏
        if (!notExitFlag && autoExitFullscreen) {
          plPlayerController!.triggerFullScreen(status: false);
        }
        // 播放完展示控制栏
        // if (videoDetailController.floating != null && !notExitFlag) {
        //   PiPStatus currentStatus =
        //       await videoDetailController.floating!.pipStatus;
        //   if (currentStatus == PiPStatus.disabled) {
        //     plPlayerController!.onLockControl(false);
        //   }
        // }
        break;
      case PlayerStatus.paused:
        break;
      case PlayerStatus.disabled:
        videoDetailController.isShowCover.value = true;
        break;
    }
  }

  // 继续播放或重新播放
  void continuePlay() async {
    plPlayerController!.play();
  }

  /// 未开启自动播放时触发播放
  Future<void> handlePlay() async {
    if (plPlayerController == null) {
      SmartDialog.showToast('播放器初始化失败，请重新进入本页面');
      return;
    }
    plPlayerController!.play();
    await plPlayerController!.autoEnterFullScreen();
    videoDetailController.autoPlay.value = true;
    // autoEnterPip();
  }

  // // 生命周期监听
  // void lifecycleListener() {
  //   _lifecycleListener = AppLifecycleListener(
  //     onResume: () => _handleTransition('resume'),
  //     // 后台
  //     onInactive: () => _handleTransition('inactive'),
  //     // 在Android和iOS端不生效
  //     onHide: () => _handleTransition('hide'),
  //     onShow: () => _handleTransition('show'),
  //     onPause: () => _handleTransition('pause'),
  //     onRestart: () => _handleTransition('restart'),
  //     onDetach: () => _handleTransition('detach'),
  //     // 只作用于桌面端
  //     onExitRequested: () {
  //       ScaffoldMessenger.maybeOf(context)
  //           ?.showSnackBar(const SnackBar(content: Text("拦截应用退出")));
  //       return Future.value(AppExitResponse.cancel);
  //     },
  //   );
  // }

  void listenFullScreenStatus() {
    unawaited(fullScreenStatusListener?.cancel() ?? Future<void>.value());
    fullScreenStatusListener = plPlayerController!.isFullScreen.listen((
      bool status,
    ) {
      if (status) {
        videoDetailController.hiddenReplyReplyPanel();
        // hideStatusBar();
      }
      isFullScreen.value = status;
      // if (mounted) {
      //   setState(() {});
      // }
      // if (!status) {
      // showStatusBar();
      // if (horizontalScreen) {
      //   autoScreen();
      // } else {
      //   verticalScreenForTwoSeconds();
      // }
      // }
    });
  }

  @override
  void dispose() {
    if (popRouteStackContinuously != "" &&
        Get.currentRoute != popRouteStackContinuously) {
      super.dispose();
      return;
    }
    // floating.dispose();
    // videoDetailController.floating?.dispose();
    videoDetailController.cid.close();
    if (!horizontalScreen) {
      unawaited(verticalScreen());
    }
    shutdownTimerService.handleWaitingFinished();
    // _bufferedListener?.cancel();
    if (plPlayerController != null) {
      if (!floatingManager.containsFloating(globalId)) {
        videoIntroController.videoDetail.close();
        bangumiIntroController.bangumiDetail.close();
        plPlayerController!.removeStatusLister(playerListener);
        unawaited(fullScreenStatusListener?.cancel() ?? Future<void>.value());
        unawaited(
          plPlayerController!.releaseNativeResources(
            videoDetailController.playerResourceOwner,
          ),
        );
        // plPlayerController!.dispose();
      }
    }
    // videoPlayerServiceHandler.onVideoDetailDispose();
    VideoDetailPage.routeObserver.unsubscribe(this);
    // _lifecycleListener.dispose();
    showStatusBar();
    // _animationController.dispose();
    super.dispose();
  }

  @override
  // 离开当前页面时
  void didPushNext() {
    final PlPlayerController? controller = plPlayerController;
    if (controller == null) {
      super.didPushNext();
      return;
    }
    // _bufferedListener?.cancel();
    _wasPlayingBeforePush =
        controller.playerStatus.status.value == PlayerStatus.playing;
    videoDetailController.defaultST = controller.position.value;
    if (!triggerFloatingWindowWhenLeaving() &&
        !floatingManager.containsFloating(globalId)) {
      videoIntroController.isPaused = true;
      unawaited(controller.pause());
      controller.removeStatusLister(playerListener);
      unawaited(fullScreenStatusListener?.cancel() ?? Future<void>.value());
      controller.disable();
    }
    // isShowing = false;
    // if (mounted) {
    //   setState(() => {});
    // }
    super.didPushNext();
  }

  @override
  // 返回当前页面时
  void didPopNext() {
    super.didPopNext();
    // isShowing = true;
    // if (mounted) {
    //   setState(() => {});
    // }
    if (popRouteStackContinuously != "" &&
        Get.currentRoute != popRouteStackContinuously) {
      return;
    }
    unawaited(_restorePlaybackAfterPop());
  }

  Future<void> _restorePlaybackAfterPop() async {
    videoDetailController.isFirstTime = false;
    if (!videoDetailController.autoPlay.value &&
        floatingManager.containsFloating(globalId)) {
      await PlPlayerController.pauseIfExists();
    }
    floatingManager.closeFloating(globalId);
    // final bool autoplay = autoPlayEnable;
    await videoDetailController.playerInit(autoplay: _wasPlayingBeforePush);

    if (!mounted) return;
    final PlPlayerController? restoredController =
        videoDetailController.plPlayerController;
    if (restoredController == null ||
        !restoredController.ownsNativeResources(
          videoDetailController.playerResourceOwner,
        )) {
      return;
    }
    plPlayerController = restoredController;
    if (!videoDetailController.sourceType.isPgc) {
      videoIntroController.videoDetail.refresh();
    } else if (videoDetailController.sourceType.isPgc) {
      bangumiIntroController.bangumiDetail.refresh();
    }

    /// 未开启自动播放时，未播放跳转下一页返回/播放后跳转下一页返回
    videoIntroController.isPaused = false;
    // if (autoplay) {
    //   // await Future.delayed(const Duration(milliseconds: 300));
    //   print(plPlayerController);
    //   if (plPlayerController?.buffered.value == Duration.zero) {
    //     _bufferedListener = plPlayerController?.buffered.listen((p0) {
    //       print("p0");
    //       print(p0);
    //       if (p0 > Duration.zero) {
    //         _bufferedListener!.cancel();
    //         plPlayerController?.seekTo(videoDetailController.defaultST);
    //         plPlayerController?.play();
    //       }
    //     });
    //   } else {
    //     plPlayerController?.seekTo(videoDetailController.defaultST);
    //     plPlayerController?.play();
    //   }
    // }
    restoredController.removeStatusLister(playerListener);
    restoredController.addStatusLister(playerListener);
    listenFullScreenStatus();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted &&
            restoredController.ownsNativeResources(
              videoDetailController.playerResourceOwner,
            )) {
          unawaited(fullAutoScreen());
        }
      }),
    );
  }

  bool triggerFloatingWindowWhenLeaving() {
    if (GStorage.setting.get(
          SettingBoxKey.autoMiniPlayer,
          defaultValue: false,
        ) &&
        plPlayerController?.playerStatus.status.value == PlayerStatus.playing) {
      return plPlayerController!.triggerFloatingWindow(
        videoIntroController,
        bangumiIntroController,
        heroTag,
      );
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    VideoDetailPage.routeObserver.subscribe(
      this,
      ModalRoute.of(context)! as PageRoute,
    );
  }

  // void _handleTransition(String name) {
  //   switch (name) {
  //     case 'inactive':
  //       if (plPlayerController != null &&
  //           playerStatus == PlayerStatus.playing) {
  //         autoEnterPip();
  //       }
  //       break;
  //   }
  // }

  // void autoEnterPip() {
  //   final String routePath = Get.currentRoute;
  //
  //   if (autoPiP && routePath.startsWith('/video')) {
  //     floating.enable(OnLeavePiP(
  //       aspectRatio: plPlayerController != null
  //           ? Rational(
  //               videoDetailController.data.dash!.video!.first.width!,
  //               videoDetailController.data.dash!.video!.first.height!,
  //             )
  //           : const Rational.landscape(),
  //       sourceRectHint: Rectangle<int>(
  //         0,
  //         0,
  //         context.width.toInt(),
  //         context.height.toInt(),
  //       ),
  //     ));
  //     print("enabled");
  //   }
  // }

  Widget get plPlayer => Obx(() {
    final PlaybackLoadState loadState =
        videoDetailController.playbackLoadState.value;
    if (loadState == PlaybackLoadState.failed) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: TextButton.icon(
            onPressed: retryVideoSource,
            icon: const Icon(Icons.refresh),
            label: Text(
              videoDetailController.playbackError.value.isEmpty
                  ? '视频加载失败，点击重试'
                  : videoDetailController.playbackError.value,
            ),
          ),
        ),
      );
    }
    if (loadState == PlaybackLoadState.loading) {
      return const ColoredBox(color: Colors.transparent);
    }
    final PlPlayerController? activePlayerController =
        plPlayerController ?? videoDetailController.plPlayerController;
    if ((!videoDetailController.autoPlay.value &&
            videoDetailController.isShowCover.value) ||
        activePlayerController == null ||
        activePlayerController.videoController == null) {
      return const ColoredBox(color: Colors.transparent);
    }
    return PLVideoPlayer(
      key: Key(heroTag),
      controller: activePlayerController,
      videoIntroController: !videoDetailController.sourceType.isPgc
          ? videoIntroController
          : null,
      bangumiIntroController: videoDetailController.sourceType.isPgc
          ? bangumiIntroController
          : null,
      headerControl: videoDetailController.headerControl,
      danmuWidget: Obx(
        () => PlDanmaku(
          key: Key(videoDetailController.danmakuCid.value.toString()),
          cid: videoDetailController.danmakuCid.value,
          playerController: activePlayerController,
        ),
      ),
    );
  });

  Widget get manualPlayerWidget => Obx(
    () => Visibility(
      visible:
          videoDetailController.isShowCover.value &&
          videoDetailController.isEffective.value,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              primary: false,
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              title: IconButton(
                tooltip: '回到主页',
                icon: const Icon(Icons.home),
                onPressed: () async {
                  if (mounted) {
                    popRouteStackContinuously = Get.currentRoute;
                    Get.until((route) => route.isFirst);
                    popRouteStackContinuously = "";
                  }
                },
              ),
              actions: [
                IconButton(
                  tooltip: '稍后再看',
                  onPressed: () async {
                    var res = await UserHttp.toViewLater(
                      bvid: videoDetailController.bvid,
                    );
                    SmartDialog.showToast(
                      res is ApiSuccess<void>
                          ? 'yeah！稍后再看'
                          : (res as ApiFailure<void>).message,
                    );
                  },
                  icon: const Icon(Icons.history_outlined),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: IconButton(
              tooltip: '播放',
              onPressed: handlePlay,
              icon: Image.asset(
                'assets/images/play.png',
                width: 60,
                height: 60,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget playerStack(videoWidth, videoHeight) => Stack(
    children: <Widget>[
      plPlayer,

      /// 关闭自动播放时 手动播放
      if (!videoDetailController.autoPlay.value) ...<Widget>[
        Obx(
          () => Visibility(
            visible: videoDetailController.isShowCover.value,
            child: Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: handlePlay,
                child: NetworkImgLayer(
                  type: 'emote',
                  src: videoDetailController.videoItem['pic'],
                  width: videoWidth,
                  height: videoHeight,
                ),
              ),
            ),
          ),
        ),
        manualPlayerWidget,
      ],
    ],
  );
  Widget playerPopScope(videoWidth, videoHeight) => Hero(
    tag: heroTag,
    child: PopScope(
      canPop: isFullScreen.value != true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (isFullScreen.value == true) {
          plPlayerController!.triggerFullScreen(status: false);
        }
        if (MediaQuery.of(context).orientation == Orientation.landscape &&
            !horizontalScreen) {
          verticalScreenForTwoSeconds();
        }
        if (didPop) {
          triggerFloatingWindowWhenLeaving();
        }
      },
      child: playerStack(videoWidth, videoHeight),
    ),
  );

  Widget get relatedVideo =>
      RelatedVideoPanel(key: relatedVideoPanelKey, heroTag: heroTag);

  Widget get videoReply => Obx(
    () => VideoReplyPanel(
      key: videoReplyPanelKey,
      bvid: videoDetailController.bvid,
      oid: videoDetailController.oid.value,
      heroTag: heroTag,
    ),
  );
  Widget get videoIntro => (!videoDetailController.sourceType.isPgc)
      ? VideoIntroPanel(heroTag: heroTag)
      : Obx(
          () => BangumiIntroPanel(
            heroTag: heroTag,
            cid: videoDetailController.cid.value,
          ),
        );
  Widget get divider => SliverToBoxAdapter(
    child: Divider(
      indent: 12,
      endIndent: 12,
      color: Theme.of(context).dividerColor.withOpacity(0.06),
    ),
  );

  Widget pullToFullScreen(Widget child) => CustomMaterialIndicator(
    onRefresh: () => plPlayerController!.triggerFullScreen(status: true),
    indicatorBuilder: (BuildContext context, IndicatorController controller) {
      double progress = min(controller.value, 1.0);
      Color color = Theme.of(context).primaryColor.withOpacity(progress);
      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.fullscreen, color: color, size: 27),
            CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
              value: controller.state.isLoading
                  ? null
                  : min(controller.value, 1.0),
            ),
          ],
        ),
      );
    },
    child: child,
  );

  Widget get childWhenDisabled => SafeArea(
    top:
        !removeSafeArea &&
        MediaQuery.of(context).orientation == Orientation.portrait &&
        isFullScreen.value == true,
    bottom:
        !removeSafeArea &&
        MediaQuery.of(context).orientation == Orientation.portrait &&
        isFullScreen.value == true,
    left: false, //isFullScreen != true,
    right: false, //isFullScreen != true,
    child: Scaffold(
      resizeToAvoidBottomInset: false,
      key: scaffoldKey,
      // backgroundColor: Colors.black,
      appBar: removeSafeArea
          ? null
          : AppBar(
              backgroundColor: showStatusBarBackgroundColor
                  ? null
                  : Colors.black,
              elevation: 0,
              toolbarHeight: 0,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarIconBrightness:
                    Theme.of(context).brightness == Brightness.dark ||
                        !showStatusBarBackgroundColor
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
              ),
            ),
      body: Column(
        children: [
          Obx(() {
            double videoHeight = context.width * 9 / 16;
            final double videoWidth = context.width;
            // print(videoDetailController.tabCtr.index);
            if (enableVerticalExpand &&
                plPlayerController?.direction.value == 'vertical') {
              videoHeight = context.width;
            }
            if (MediaQuery.of(context).orientation == Orientation.landscape &&
                !horizontalScreen &&
                !isFullScreen.value &&
                isShowing &&
                mounted) {
              hideStatusBar();
            }
            if (MediaQuery.of(context).orientation == Orientation.portrait &&
                !isFullScreen.value &&
                isShowing &&
                mounted) {
              if (!removeSafeArea) showStatusBar();
            }
            return Container(
              color: showStatusBarBackgroundColor ? null : Colors.black,
              height:
                  MediaQuery.of(context).orientation == Orientation.landscape ||
                      isFullScreen.value == true
                  ? MediaQuery.sizeOf(context).height -
                        (MediaQuery.of(context).orientation ==
                                    Orientation.landscape ||
                                removeSafeArea
                            ? 0
                            : MediaQuery.of(context).padding.top)
                  : videoHeight,
              width: context.width,
              child: playerPopScope(videoWidth, videoHeight),
            );
          }),
          Expanded(
            child: ColoredBox(
              key: Key(heroTag),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  // Opacity(
                  //   opacity: 0,
                  //   child: SizedBox(
                  //     width: context.width,
                  //     height: 0,
                  //     child: Obx(
                  //       () => TabBar(
                  //         controller: videoDetailController.tabCtr,
                  //         dividerColor: Colors.transparent,
                  //         indicatorColor:
                  //             Theme.of(context).colorScheme.surface,
                  //         tabs: videoDetailController.tabs
                  //             .map((String name) => Tab(text: name))
                  //             .toList(),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  Expanded(
                    child: TabBarView(
                      physics: const CustomTabBarViewScrollPhysics(),
                      controller: videoDetailController.tabCtr,
                      children: <Widget>[
                        pullToFullScreen(
                          CustomScrollView(
                            cacheExtent: 3500,
                            key: const PageStorageKey<String>('简介'),
                            slivers: <Widget>[
                              videoIntro,
                              if (!videoDetailController.sourceType.isPgc) ...[
                                divider,
                                relatedVideo,
                              ],
                            ],
                          ),
                        ),
                        videoReply,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget get childWhenDisabledAlmostSquareInner => Obx(() {
    if (enableVerticalExpand &&
        plPlayerController?.direction.value == 'vertical') {
      final double videoHeight =
          context.height -
          (removeSafeArea
              ? 0
              : (MediaQuery.of(context).padding.top +
                    MediaQuery.of(context).padding.bottom));
      final double videoWidth = videoHeight * 9 / 16;
      return Row(
        children: [
          SizedBox(
            height: videoHeight,
            width: isFullScreen.value == true ? context.width : videoWidth,
            child: playerPopScope(videoWidth, videoHeight),
          ),
          Expanded(
            child: TabBarView(
              physics: const CustomTabBarViewScrollPhysics(),
              controller: videoDetailController.tabCtr,
              children: <Widget>[
                pullToFullScreen(
                  CustomScrollView(
                    cacheExtent: 3500,
                    key: const PageStorageKey<String>('简介'),
                    slivers: <Widget>[
                      videoIntro,
                      if (!videoDetailController.sourceType.isPgc) ...[
                        divider,
                        relatedVideo,
                      ],
                    ],
                  ),
                ),
                videoReply,
              ],
            ),
          ),
        ],
      );
    }
    final double videoHeight = context.height / 2.5;
    final double videoWidth = context.width;
    return Column(
      children: [
        SizedBox(
          width: videoWidth,
          height: isFullScreen.value == true
              ? context.height -
                    (removeSafeArea
                        ? 0
                        : (MediaQuery.of(context).padding.top +
                              MediaQuery.of(context).padding.bottom))
              : videoHeight,
          child: playerPopScope(videoWidth, videoHeight),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: pullToFullScreen(
                  CustomScrollView(
                    cacheExtent: 3500,
                    key: PageStorageKey<String>(
                      '简介${videoDetailController.bvid}',
                    ),
                    slivers: <Widget>[
                      videoIntro,
                      if (!videoDetailController.sourceType.isPgc) ...[
                        divider,
                        relatedVideo,
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: videoReply),
            ],
          ),
        ),
      ],
    );
  });
  Widget get childWhenDisabledLandscapeInner => Obx(() {
    if (enableVerticalExpand &&
        plPlayerController?.direction.value == 'vertical') {
      final double videoHeight =
          context.height -
          (removeSafeArea ? 0 : MediaQuery.of(context).padding.top);
      final double videoWidth = videoHeight * 9 / 16;
      return Row(
        children: [
          Expanded(
            child: pullToFullScreen(
              CustomScrollView(
                cacheExtent: 3500,
                key: PageStorageKey<String>('简介${videoDetailController.bvid}'),
                slivers: <Widget>[
                  videoIntro,
                  if (!videoDetailController.sourceType.isPgc) relatedVideo,
                ],
              ),
            ),
          ),
          SizedBox(
            height: videoHeight,
            width: isFullScreen.value == true ? context.width : videoWidth,
            child: playerPopScope(videoWidth, videoHeight),
          ),
          Expanded(child: videoReply),
        ],
      );
    }
    final double videoWidth =
        max(context.height / context.width * 1.04, 1 / 2) * context.width;
    final double videoHeight = videoWidth * 9 / 16;
    return Row(
      children: [
        SizedBox(
          width: isFullScreen.value == true ? context.width : videoWidth,
          height: context.height,
          child: Column(
            children: [
              SizedBox(
                width: isFullScreen.value == true ? context.width : videoWidth,
                height: isFullScreen.value == true
                    ? context.height
                    : videoHeight,
                child: playerPopScope(videoWidth, videoHeight),
              ),
              Expanded(
                child: SizedBox(
                  width: videoWidth,
                  height:
                      context.height -
                      videoHeight -
                      (removeSafeArea ? 0 : MediaQuery.of(context).padding.top),
                  child: pullToFullScreen(
                    CustomScrollView(
                      cacheExtent: 3500,
                      key: PageStorageKey<String>(
                        '简介${videoDetailController.bvid}',
                      ),
                      slivers: <Widget>[videoIntro],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            physics: const CustomTabBarViewScrollPhysics(),
            controller: videoDetailController.tabCtr,
            children: <Widget>[
              if (!videoDetailController.sourceType.isPgc)
                CustomScrollView(cacheExtent: 3500, slivers: [relatedVideo]),
              videoReply,
            ],
          ),
        ),
      ],
    );
  });
  Widget get childWhenDisabledLandscape => Scaffold(
    resizeToAvoidBottomInset: false,
    key: scaffoldKey,
    // backgroundColor: Colors.black,
    appBar: removeSafeArea
        ? null
        : AppBar(
            backgroundColor: showStatusBarBackgroundColor ? null : Colors.black,
            elevation: 0,
            toolbarHeight: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarIconBrightness:
                  Theme.of(context).brightness == Brightness.dark ||
                      !showStatusBarBackgroundColor
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
            ),
          ),
    body: Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        left: !removeSafeArea && isFullScreen.value != true,
        right: !removeSafeArea && isFullScreen.value != true,
        top: !removeSafeArea,
        bottom: false, //!removeSafeArea,
        child: childWhenDisabledLandscapeInner,
      ),
    ),
  );
  Widget get childWhenDisabledAlmostSquare => Scaffold(
    resizeToAvoidBottomInset: false,
    key: scaffoldKey,
    // backgroundColor: Colors.black,
    appBar: removeSafeArea
        ? null
        : AppBar(
            backgroundColor: showStatusBarBackgroundColor ? null : Colors.black,
            elevation: 0,
            toolbarHeight: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarIconBrightness:
                  Theme.of(context).brightness == Brightness.dark ||
                      !showStatusBarBackgroundColor
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: Colors.transparent,
            ),
          ),
    body: Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        left: !removeSafeArea && isFullScreen.value != true,
        right: !removeSafeArea && isFullScreen.value != true,
        top: !removeSafeArea,
        bottom: false, //!removeSafeArea,
        child: childWhenDisabledAlmostSquareInner,
      ),
    ),
  );
  Widget get childWhenEnabled => Obx(
    () => !videoDetailController.autoPlay.value
        ? const SizedBox()
        : PLVideoPlayer(
            key: Key(heroTag),
            controller: plPlayerController!,
            videoIntroController: !videoDetailController.sourceType.isPgc
                ? videoIntroController
                : null,
            bangumiIntroController: videoDetailController.sourceType.isPgc
                ? bangumiIntroController
                : null,
            headerControl: HeaderControl(
              controller: plPlayerController,
              videoDetailCtr: videoDetailController,
              heroTag: heroTag,
            ),
            danmuWidget: pipNoDanmaku
                ? null
                : Obx(
                    () => PlDanmaku(
                      key: Key(
                        videoDetailController.danmakuCid.value.toString(),
                      ),
                      cid: videoDetailController.danmakuCid.value,
                      playerController: plPlayerController!,
                    ),
                  ),
          ),
  );
  Widget autoChoose(Widget childWhenDisabled) {
    if (!Platform.isAndroid) {
      return childWhenDisabled;
    }
    return PiPBuilder(
      builder: (PiPStatusInfo? statusInfo) {
        switch (statusInfo?.status) {
          case PiPStatus.enabled:
            return childWhenEnabled;
          case PiPStatus.disabled:
            return childWhenDisabled;
          case PiPStatus.unavailable:
            return childWhenDisabled;
          case null:
            return childWhenDisabled;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!horizontalScreen) {
      return autoChoose(childWhenDisabled);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        isShowing = Get.currentRoute == myRouteName;
        if (!isShowing && Get.previousRoute != myRouteName) {
          return ColoredBox(color: Theme.of(context).colorScheme.surface);
        }
        if (constraints.maxWidth > constraints.maxHeight * 1.25) {
          //             hideStatusBar();
          //             videoDetailController.hiddenReplyReplyPanel();
          return autoChoose(childWhenDisabledLandscape);
        } else if (constraints.maxWidth * (9 / 16) <
            (2 / 5) * constraints.maxHeight) {
          if (!isFullScreen.value) {
            if (!removeSafeArea && isShowing) {
              showStatusBar();
            }
          }
          return autoChoose(childWhenDisabled);
        } else {
          if (!isFullScreen.value) {
            if (!removeSafeArea && isShowing) {
              showStatusBar();
            }
          }
          return autoChoose(childWhenDisabledAlmostSquare);
        }
      },
    );
  }
}

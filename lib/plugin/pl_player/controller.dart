// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/material.dart';
// import 'package:android_window/main.dart' as android_window;
// import 'android_window.dart';
import 'package:flutter_floating/floating/assist/floating_slide_type.dart';
import 'package:flutter_floating/floating/floating.dart';
import 'package:flutter_floating/floating/listener/event_listener.dart';
import 'package:flutter_floating/floating/manager/floating_manager.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/pages/mine/controller.dart';
import 'package:pilipalaz/plugin/pl_player/external_audio_command.dart';
import 'package:pilipalaz/plugin/pl_player/hardware_decode_fallback_guard.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipalaz/plugin/pl_player/player_buffer_policy.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/playback_lifecycle.dart';
import 'package:pilipalaz/plugin/pl_player/playback_position_guard.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';
import 'package:pilipalaz/services/player_diagnostics.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/feed_back.dart';
import 'package:pilipalaz/utils/storage.dart';
// import 'package:screen_brightness/screen_brightness.dart';
import 'package:universal_platform/universal_platform.dart';
import '../../models/video/play/subtitle.dart';
import '../../pages/danmaku/controller.dart';
import '../../pages/video/controller.dart';
import '../../pages/video/introduction/bangumi/controller.dart';
import '../../pages/video/introduction/detail/controller.dart';
// import '../../pages/video/controller.dart';
// import 'package:wakelock_plus/wakelock_plus.dart';

Box videoStorage = GStorage.video;
Box setting = GStorage.setting;
Box onlineCache = GStorage.onlineCache;

class PlPlayerController with WidgetsBindingObserver {
  static Player? _videoPlayerController;
  VideoController? _videoController;
  PlaybackCommandCoordinator? _playbackCommands;

  // 添加一个私有静态变量来保存实例
  static PlPlayerController? _instance;

  // 流事件  监听播放状态变化
  StreamSubscription? _playerEventSubs;

  /// [playerStatus] has a [status] observable
  final PlPlayerStatus playerStatus = PlPlayerStatus();

  ///
  final PlPlayerDataStatus dataStatus = PlPlayerDataStatus();

  // bool controlsEnabled = false;

  /// 响应数据
  /// 带有Seconds的变量只在秒数更新时更新，以避免频繁触发重绘
  // 播放位置
  final Rx<Duration> _position = Rx(Duration.zero);
  final RxInt positionSeconds = 0.obs;
  final Rx<Duration> _sliderPosition = Rx(Duration.zero);
  final RxInt sliderPositionSeconds = 0.obs;
  // 展示使用
  final Rx<Duration> _sliderTempPosition = Rx(Duration.zero);
  final Rx<Duration> _duration = Rx(Duration.zero);
  final RxInt durationSeconds = 0.obs;
  final Rx<Duration> _buffered = Rx(Duration.zero);
  final Rx<String> _playerLog = Rx("");
  final RxInt bufferedSeconds = 0.obs;

  final Rx<double> _playbackSpeed = 1.0.obs;
  final Rx<double> _longPressSpeed = 2.0.obs;
  final Rx<double> _currentVolume = 1.0.obs;
  final Rx<double> _currentBrightness = 0.0.obs;

  final Rx<bool> _mute = false.obs;
  final Rx<bool> _showControls = false.obs;
  final Rx<bool> _showVolumeStatus = false.obs;
  final Rx<bool> _showBrightnessStatus = false.obs;
  final RxDouble _doubleSpeedStatus = 0.0.obs;
  final Rx<bool> _controlsLock = false.obs;
  final Rx<bool> _isFullScreen = false.obs;
  // 默认投稿视频格式
  static Rx<String> _videoType = 'archive'.obs;

  final Rx<String> _direction = 'horizontal'.obs;

  final Rx<BoxFit> _videoFit = Rx(videoFitType.first['attr']);
  final Rx<String> _videoFitDesc = Rx(videoFitType.first['desc']);
  StreamSubscription<DataStatus>? _dataListenerForVideoFit;
  StreamSubscription<DataStatus>? _dataListenerForEnterFullScreen;
  StreamSubscription<PlayerStatus>? _playerListenerForEnterPip;

  /// 后台播放
  Rx<bool> _continuePlayInBackground = false.obs;

  Rx<bool> _onlyPlayAudio = false.obs;

  Rx<bool> _flipX = false.obs;

  ///
  // ignore: prefer_final_fields
  Rx<bool> _isSliderMoving = false.obs;
  PlaylistMode _looping = PlaylistMode.none;
  bool _autoPlay = false;
  final PlaybackPositionGuard _positionGuard = PlaybackPositionGuard();
  Future<void> _sourceOperation = Future<void>.value();
  Timer? _retryTimer;
  final PlaybackLifecycle _playbackLifecycle = PlaybackLifecycle();
  final Rx<PlaybackLifecycleState> playbackLifecycleState =
      PlaybackLifecycleState.idle.obs;
  bool _positionCorrectionInFlight = false;
  bool _refreshInFlight = false;
  bool _nativePlayerStale = false;
  HardwareDecodeFailureHandler? _onHardwareDecodeFailure;
  final HardwareDecodeFallbackGuard _hardwareDecodeFallbackGuard =
      HardwareDecodeFallbackGuard();
  PlayerDiagnosticSession? _diagnosticSession;
  final PlaybackResourceOwnership _resourceOwnership =
      PlaybackResourceOwnership();

  // 记录历史记录
  String _bvid = '';
  int _cid = 0;
  int _heartDuration = 0;
  bool _enableHeart = true;

  late DataSource dataSource;
  final RxList<Map<String, String>> _vttSubtitles = <Map<String, String>>[].obs;
  final RxInt _vttSubtitlesIndex = 0.obs;

  final RxDouble subtitleFontSize = 60.0.obs;
  final RxDouble subtitleBottomPadding = 24.0.obs;

  late Rx<TextStyle> subtitleStyle;

  Timer? _timer;
  Timer? _timerForSeek;
  Timer? _timerForVolume;
  Timer? _timerForShowingVolume;
  Timer? _timerForGettingVolume;
  Timer? timerForTrackingMouse;

  // final Durations durations;

  static List<Map<String, dynamic>> videoFitType = [
    {'attr': BoxFit.contain, 'desc': '自动', 'toast': '缩放至播放器尺寸，保留黑边'},
    {'attr': BoxFit.cover, 'desc': '裁剪', 'toast': '缩放至填满播放器，裁剪超出部分'},
    {'attr': BoxFit.fill, 'desc': '拉伸', 'toast': '拉伸至播放器尺寸，将产生变形（竖屏改为自动）'},
    {'attr': BoxFit.none, 'desc': '原始', 'toast': '不缩放，以视频原始尺寸显示'},
    {'attr': BoxFit.fitHeight, 'desc': '等高', 'toast': '缩放至撑满播放器高度'},
    {'attr': BoxFit.fitWidth, 'desc': '等宽', 'toast': '缩放至撑满播放器宽度'},
    {'attr': BoxFit.scaleDown, 'desc': '限制', 'toast': '仅超出时缩小至播放器尺寸'},
  ];

  PreferredSizeWidget? headerControl;
  PreferredSizeWidget? bottomControl;
  Widget? danmuWidget;

  String get bvid => _bvid;
  int get cid => _cid;

  /// 数据加载监听
  Stream<DataStatus> get onDataStatusChanged => dataStatus.status.stream;

  /// 播放状态监听
  Stream<PlayerStatus> get onPlayerStatusChanged => playerStatus.status.stream;

  /// 视频时长
  Rx<Duration> get duration => _duration;
  Stream<Duration> get onDurationChanged => _duration.stream;

  /// 视频当前播放位置
  Rx<Duration> get position => _position;
  Stream<Duration> get onPositionChanged => _position.stream;

  /// 视频播放速度
  double get playbackSpeed => _playbackSpeed.value;

  // 长按倍速
  double get longPressSpeed => _longPressSpeed.value;

  /// 视频缓冲
  Rx<Duration> get buffered => _buffered;
  Stream<Duration> get onBufferedChanged => _buffered.stream;

  /// 视频日志
  Rx<String> get playerLog => _playerLog;

  // 视频静音
  Rx<bool> get mute => _mute;
  Stream<bool> get onMuteChanged => _mute.stream;

  // 视频字幕
  RxList<Map<String, String>> get vttSubtitles => _vttSubtitles;
  RxInt get vttSubtitlesIndex => _vttSubtitlesIndex;

  /// [videoPlayerController] instance of Player
  Player? get videoPlayerController => _videoPlayerController;

  int get _playbackSession => _playbackLifecycle.session;

  bool get canControlPlayback =>
      _playbackLifecycle.canControlPlayback &&
      _playbackCommands != null &&
      _videoPlayerController != null;

  bool get isPlaying => canControlPlayback && playerStatus.playing;

  /// [videoController] instance of Player
  VideoController? get videoController => _videoController;

  Rx<bool> get isSliderMoving => _isSliderMoving;

  /// 进度条位置及监听
  Rx<Duration> get sliderPosition => _sliderPosition;
  Stream<Duration> get onSliderPositionChanged => _sliderPosition.stream;

  Rx<Duration> get sliderTempPosition => _sliderTempPosition;
  // Stream<Duration> get onSliderPositionChanged => _sliderPosition.stream;

  /// 是否展示控制条及监听
  Rx<bool> get showControls => _showControls;
  Stream<bool> get onShowControlsChanged => _showControls.stream;

  /// 音量控制条展示/隐藏
  Rx<bool> get showVolumeStatus => _showVolumeStatus;
  Stream<bool> get onShowVolumeStatusChanged => _showVolumeStatus.stream;

  /// 亮度控制条展示/隐藏
  Rx<bool> get showBrightnessStatus => _showBrightnessStatus;
  Stream<bool> get onShowBrightnessStatusChanged =>
      _showBrightnessStatus.stream;

  /// 音量控制条
  Rx<double> get volume => _currentVolume;
  Stream<double> get onVolumeChanged => _currentVolume.stream;

  /// 亮度控制条
  Rx<double> get brightness => _currentBrightness;
  Stream<double> get onBrightnessChanged => _currentBrightness.stream;

  /// 是否循环
  PlaylistMode get looping => _looping;

  /// 是否自动播放
  bool get autoplay => _autoPlay;

  /// 视频比例
  Rx<BoxFit> get videoFit => _videoFit;
  Rx<String> get videoFitDEsc => _videoFitDesc;

  /// 后台播放
  Rx<bool> get continuePlayInBackground => _continuePlayInBackground;

  /// 听视频
  Rx<bool> get onlyPlayAudio => _onlyPlayAudio;

  /// 镜像
  Rx<bool> get flipX => _flipX;

  /// 长按倍速值（0为非长按倍速）
  RxDouble get doubleSpeedStatus => _doubleSpeedStatus;

  Rx<bool> isBuffering = true.obs;

  /// 屏幕锁 为true时，关闭控制栏
  Rx<bool> get controlsLock => _controlsLock;

  /// 全屏状态
  Rx<bool> get isFullScreen => _isFullScreen;

  /// 全屏方向
  Rx<String> get direction => _direction;

  // Rx<int> get playerCount => _playerCount;

  ///
  Rx<String> get videoType => _videoType;

  /// 弹幕开关
  Rx<bool> isOpenDanmu = false.obs;
  // 关联弹幕控制器
  DanmakuController? danmakuController;
  // 弹幕相关配置
  late List blockTypes;
  late double showArea;
  late double opacityVal;
  late double fontSizeVal;
  late double strokeWidth;
  late int fontWeight;
  late int danmakuDurationVal;
  late bool massiveMode;
  late List<double> speedsList;
  // int? defaultDuration;
  late bool enableAutoLongPressSpeed;
  late bool enableLongPressSpeedIncrease;
  late bool enableLongShowControl;
  late bool horizontalScreen;

  // 播放顺序相关
  PlayRepeat playRepeat = PlayRepeat.pause;

  final List<StreamSubscription<dynamic>> subscriptions = [];

  void updateSliderPositionSecond() {
    int newSecond =
        (_sliderPosition.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (sliderPositionSeconds.value != newSecond) {
      sliderPositionSeconds.value = newSecond;
    }
  }

  void updatePositionSecond() {
    int newSecond =
        (_position.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (positionSeconds.value != newSecond) {
      positionSeconds.value = newSecond;
    }
  }

  void updateDurationSecond() {
    int newSecond =
        (_duration.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (durationSeconds.value != newSecond) {
      durationSeconds.value = newSecond;
    }
  }

  void _resetPlaybackPresentationForSource({
    required Duration initialPosition,
    Duration? initialDuration,
  }) {
    final PlaybackPresentationState current = PlaybackPresentationState(
      position: _position.value,
      sliderPosition: _sliderPosition.value,
      sliderTempPosition: _sliderTempPosition.value,
      buffered: _buffered.value,
      duration: _duration.value,
      isSliderMoving: _isSliderMoving.value,
    );
    final PlaybackPresentationState next = current.beginSource(
      initialPosition: initialPosition,
      initialDuration: initialDuration,
    );

    _position.value = next.position;
    _sliderPosition.value = next.sliderPosition;
    _sliderTempPosition.value = next.sliderTempPosition;
    _buffered.value = next.buffered;
    _duration.value = next.duration;
    _isSliderMoving.value = next.isSliderMoving;
    isBuffering.value = false;
    _heartDuration = 0;
    _positionGuard.reset(initialPosition: next.position);
    _positionGuard.expectPosition(next.position);
    updatePositionSecond();
    updateSliderPositionSecond();
    updateBufferedSecond();
    updateDurationSecond();
  }

  void updateBufferedSecond() {
    int newSecond =
        (_buffered.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (bufferedSeconds.value != newSecond) {
      bufferedSeconds.value = newSecond;
    }
  }

  static bool instanceExists() {
    return _instance != null;
  }

  static Future<void> playIfExists({
    bool repeat = false,
    bool hideControls = true,
  }) async {
    await _instance?.play(repeat: repeat, hideControls: hideControls);
  }

  static PlayerStatus? getPlayerStatusIfExists() {
    return _instance?.playerStatus.status.value;
  }

  static Future<void> pauseIfExists({
    bool notify = true,
    bool isInterrupt = false,
  }) async {
    if (_instance?.playerStatus.status.value == PlayerStatus.playing) {
      await _instance?.pause(notify: notify, isInterrupt: isInterrupt);
    }
  }

  static Future<void> disposeIfExists() async {
    final PlPlayerController? controller = _instance;
    if (controller == null) return;
    await controller.dispose();
  }

  static Future<void> seekToIfExists(Duration position, {type = 'seek'}) async {
    await _instance?.seekTo(position, type: type);
  }

  static double? getVolumeIfExists() {
    return _instance?.volume.value;
  }

  static Future<void> setVolumeIfExists(
    double volumeNew, {
    bool videoPlayerVolume = false,
  }) async {
    await _instance?.setVolume(volumeNew, videoPlayerVolume: videoPlayerVolume);
  }

  static void updateSettingsIfExist() {
    _instance?.updateSettings();
  }

  void updateSettings() {
    isOpenDanmu.value = setting.get(
      SettingBoxKey.enableShowDanmaku,
      defaultValue: true,
    );
    blockTypes = setting.get(SettingBoxKey.danmakuBlockType, defaultValue: []);
    showArea = setting
        .get(SettingBoxKey.danmakuShowArea, defaultValue: 0.5)
        .toDouble();
    // 不透明度
    opacityVal = setting
        .get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0)
        .toDouble();
    // 字体大小
    fontSizeVal = setting
        .get(SettingBoxKey.danmakuFontScale, defaultValue: 1.0)
        .toDouble();
    // 弹幕时间
    danmakuDurationVal = setting
        .get(SettingBoxKey.danmakuDuration, defaultValue: 7.29)
        .round();
    // 描边粗细
    strokeWidth = setting
        .get(SettingBoxKey.strokeWidth, defaultValue: 1.5)
        .toDouble();
    // 弹幕字体粗细
    fontWeight = setting.get(SettingBoxKey.fontWeight, defaultValue: 5).round();
    // 弹幕海量模式
    massiveMode = setting.get(
      SettingBoxKey.danmakuMassiveMode,
      defaultValue: false,
    );
    playRepeat = PlayRepeat.values.toList().firstWhere(
      (e) =>
          e.value ==
          videoStorage.get(
            VideoBoxKey.playRepeat,
            defaultValue: PlayRepeat.pause.value,
          ),
    );
    _playbackSpeed.value = videoStorage
        .get(VideoBoxKey.playSpeedDefault, defaultValue: 1.0)
        .toDouble();
    enableAutoLongPressSpeed = setting.get(
      SettingBoxKey.enableAutoLongPressSpeed,
      defaultValue: false,
    );
    enableLongPressSpeedIncrease = setting.get(
      SettingBoxKey.enableLongPressSpeedIncrease,
      defaultValue: false,
    );
    if (!enableAutoLongPressSpeed) {
      _longPressSpeed.value = videoStorage
          .get(VideoBoxKey.longPressSpeedDefault, defaultValue: 3.0)
          .toDouble();
    }
    // 后台播放
    _continuePlayInBackground.value = setting.get(
      SettingBoxKey.continuePlayInBackground,
      defaultValue: false,
    );
    enableLongShowControl = setting.get(
      SettingBoxKey.enableLongShowControl,
      defaultValue: false,
    );
    horizontalScreen = setting.get(
      SettingBoxKey.horizontalScreen,
      defaultValue: false,
    );
    subtitleFontSize.value = videoStorage
        .get(VideoBoxKey.subtitleFontSize, defaultValue: 60.0)
        .toDouble();
    subtitleStyle = TextStyle(
      height: 1.3,
      fontSize: subtitleFontSize.value,
      letterSpacing: 0.1,
      wordSpacing: 0.1,
      color: const Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: const Color(0xaa000000),
    ).obs;
    subtitleBottomPadding.value = videoStorage
        .get(VideoBoxKey.subtitleBottomPadding, defaultValue: 24.0)
        .toDouble();

    List<double> defaultList = <double>[0.5, 0.75, 1.25, 1.5, 1.75, 3.0];
    speedsList = List<double>.from(
      videoStorage
          .get(VideoBoxKey.customSpeedsList, defaultValue: defaultList)
          .map((e) => e.toDouble()),
    );
    for (final PlaySpeed i in PlaySpeed.values) {
      speedsList.add(i.value);
    }
    speedsList.sort();
  }

  // 添加一个私有构造函数
  PlPlayerController._() {
    _videoType = videoType;
    updateSettings();
    WidgetsBinding.instance.addObserver(this);
    // _playerEventSubs = onPlayerStatusChanged.listen((PlayerStatus status) {
    //   if (status == PlayerStatus.playing) {
    //     WakelockPlus.enable();
    //   } else {
    //     WakelockPlus.disable();
    //   }
    // });
    enableAutoPip();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isAndroid) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      final String route = Get.currentRoute;
      final bool isPlayerRoute =
          route.startsWith('/video') || route.startsWith('/live');
      if (!isPlayerRoute && !floatingManager.containsFloating(globalId)) {
        _nativePlayerStale = true;
      }
    }
  }

  @override
  void didHaveMemoryPressure() {
    if (!Platform.isAndroid) return;
    final String route = Get.currentRoute;
    final bool isPlayerRoute =
        route.startsWith('/video') || route.startsWith('/live');
    if (!isPlayerRoute || _videoPlayerController?.state.playing != true) {
      _nativePlayerStale = true;
    }
  }

  void enableAutoPip() async {
    if (!GStorage.setting.get(SettingBoxKey.autoPiP, defaultValue: false)) {
      return;
    }
    if (!await FlPiP().isAvailable) return;
    _playerListenerForEnterPip = onPlayerStatusChanged.listen((
      PlayerStatus status,
    ) async {
      if (status != PlayerStatus.playing) {
        // bool isActive = (await FlPiP().isActive)?.status == PiPStatus.enabled;
        // if (isActive) return;
        FlPiP().setEnableWhenBackground(false);
        print('disable pip EnableWhenBackground');
        return;
      }
      print('enable pip');
      FlPiP().enable(
        ios: FlPiPiOSConfig(
          enabledWhenBackground: true,
          videoPath: dataSource.videoSource!,
          audioPath: dataSource.audioSource!,
          packageName: 'PiliPalaZ',
        ),
        android: FlPiPAndroidConfig(
          enabledWhenBackground: true,
          aspectRatio: Rational(
            direction.value == 'vertical' ? 9 : 16,
            direction.value == 'horizontal' ? 9 : 16,
          ),
        ),
      );
      print('enabled pip');
    });
  }

  // 获取实例 传参
  static PlPlayerController getInstance({String videoType = 'archive'}) {
    // 如果实例尚未创建，则创建一个新实例
    _instance ??= PlPlayerController._();
    // print('getInstance');
    // print(StackTrace.current);
    // _instance!._playerCount.value += 1;
    // print("_playerCount");
    // print(_instance!._playerCount.value);
    _videoType.value = videoType;
    return _instance!;
  }

  Future<void> _recordPlayerFailure(
    DiagnosticFailureKind kind,
    Object error,
    StackTrace? stackTrace, {
    bool completeSession = false,
  }) async {
    final diagnostic = _diagnosticSession;
    if (diagnostic != null) {
      await diagnostic.reportFailure(
        kind,
        error,
        stackTrace,
        completeSession: completeSession,
      );
      return;
    }
    await LocalDiagnostics.instance.recordFailure(kind, error, stackTrace);
  }

  void claimNativeResources(PlayerResourceOwner owner) {
    _resourceOwnership.claim(owner);
  }

  bool ownsNativeResources(PlayerResourceOwner owner) {
    return _resourceOwnership.owns(owner);
  }

  // 初始化资源
  Future<void> setDataSource(
    DataSource dataSource, {
    required PlayerResourceOwner owner,
    bool autoplay = true,
    // 默认不循环
    PlaylistMode looping = PlaylistMode.none,
    // 初始化播放位置
    Duration seekTo = Duration.zero,
    // 初始化播放速度
    double speed = 1.0,
    // 硬件加速
    bool enableHA = true,
    String? hwdec,
    double? width,
    double? height,
    Duration? duration,
    // 方向
    String? direction,
    // 记录历史记录
    String bvid = '',
    int cid = 0,
    // 历史记录开关
    bool enableHeart = true,
    HardwareDecodeFailureHandler? onHardwareDecodeFailure,
  }) async {
    _resourceOwnership.claim(owner);
    final int session = _playbackLifecycle.beginLoading();
    playbackLifecycleState.value = _playbackLifecycle.state;
    _hardwareDecodeFallbackGuard.beginSession(
      session,
      enabled:
          Platform.isAndroid &&
          enableHA &&
          hwdec != 'no' &&
          videoType.value != 'live',
    );
    _resetPlaybackPresentationForSource(
      initialPosition: seekTo,
      initialDuration: duration,
    );
    dataStatus.status.value = DataStatus.loading;
    _retryTimer?.cancel();
    final Future<void> previousOperation = _sourceOperation;
    final Completer<void> operationCompleter = Completer<void>();
    _sourceOperation = operationCompleter.future;
    try {
      await previousOperation;
    } catch (_) {}

    try {
      if (session != _playbackSession) return;
      // if (playerStatus.status.value == PlayerStatus.disabled) return;

      this.dataSource = dataSource;
      _autoPlay = autoplay;
      _looping = looping;
      // 初始化视频倍速
      // _playbackSpeed.value = speed;
      // 初始化全屏方向
      _direction.value = direction ?? 'horizontal';
      _bvid = bvid;
      _cid = cid;
      _enableHeart = enableHeart;
      _onHardwareDecodeFailure = onHardwareDecodeFailure;

      await _diagnosticSession?.complete('session_replaced');
      _diagnosticSession = await PlayerDiagnostics.instance.startSession(
        context: <String, Object?>{
          'enableHardwareAcceleration': enableHA,
          'hwdec': hwdec,
          'videoSync': setting.get(
            SettingBoxKey.videoSync,
            defaultValue: 'display-resample',
          ),
          'expandedBuffer': setting.get(
            SettingBoxKey.expandBuffer,
            defaultValue: false,
          ),
        },
      );
      await _diagnosticSession?.checkpoint('set_data_source_begin');

      if (_nativePlayerStale) {
        await _diagnosticSession?.checkpoint('stale_native_player_recreate');
        await _disposeNativePlayer();
        _nativePlayerStale = false;
        await _diagnosticSession?.checkpoint('stale_native_player_recreated');
      }

      if (_videoPlayerController != null &&
          _videoPlayerController!.state.playing) {
        await pause(notify: false);
      }

      // if (_playerCount.value == 0) {
      //   return;
      // }
      // 配置Player 音轨、字幕等等
      _videoPlayerController = await _createVideoController(
        dataSource,
        _looping,
        enableHA,
        hwdec,
        width,
        height,
        seekTo,
      );
      if (session != _playbackSession) return;
      _attachPlaybackCommands(_videoPlayerController!);
      // 获取视频时长 00:00
      _duration.value = duration ?? _videoPlayerController!.state.duration;
      updateDurationSecond();
      // 数据加载完成
      dataStatus.status.value = DataStatus.loaded;

      // listen the video player events
      startListeners(session);
      await _initializePlayer();
      if (_playbackLifecycle.markReady(session)) {
        playbackLifecycleState.value = _playbackLifecycle.state;
      }
      await _diagnosticSession?.checkpoint('playback_initialized');
      if (videoType.value != 'live' && _cid != 0) {
        refreshVideoMetaInfo().then((_) {
          if (session == _playbackSession) {
            chooseSubtitle();
          }
        });
      }
    } catch (err, stackTrace) {
      dataStatus.status.value = DataStatus.error;
      if (_playbackLifecycle.isCurrent(session)) {
        _playbackLifecycle.markIdle();
        playbackLifecycleState.value = _playbackLifecycle.state;
      }
      await _diagnosticSession?.checkpoint(
        'set_data_source_error',
        <String, Object?>{'error': err.toString()},
      );
      await _recordPlayerFailure(
        DiagnosticFailureKind.playerSetDataSource,
        err,
        stackTrace,
        completeSession: true,
      );
      debugPrint(stackTrace.toString());
      print('plPlayer err:  $err');
    } finally {
      operationCompleter.complete();
    }
  }

  Future<bool> _detectActiveAndroidVpn() async {
    if (!Platform.isAndroid) return false;
    try {
      final List<ConnectivityResult> results = await Connectivity()
          .checkConnectivity();
      return hasActiveVpn(results);
    } catch (err) {
      await _diagnosticSession?.checkpoint(
        'vpn_detection_error',
        <String, Object?>{'error': err.toString()},
      );
      return false;
    }
  }

  // 配置播放器
  Future<Player> _createVideoController(
    DataSource dataSource,
    PlaylistMode looping,
    bool enableHA,
    String? hwdec,
    double? width,
    double? height,
    Duration? seekTo,
  ) async {
    // 每次配置时先移除监听
    await removeListeners();
    final Duration initialPosition = seekTo ?? Duration.zero;
    _resetPlaybackPresentationForSource(
      initialPosition: initialPosition,
      initialDuration: _duration.value,
    );
    // 初始化时清空弹幕，防止上次重叠
    danmakuController?.clear();
    final bool forceExpanded = setting.get(
      SettingBoxKey.expandBuffer,
      defaultValue: false,
    );
    final bool vpnActive = await _detectActiveAndroidVpn();
    final PlayerBufferPolicy bufferPolicy = resolvePlayerBufferPolicy(
      isLive: videoType.value == 'live',
      forceExpanded: forceExpanded,
      vpnActive: vpnActive,
    );
    final int bufferSize = bufferPolicy.bufferSize;
    final String? effectiveHwdec = enableHA
        ? (Platform.isAndroid && (hwdec == null || hwdec == 'auto')
              ? 'auto-safe'
              : hwdec)
        : null;
    await _diagnosticSession
        ?.checkpoint('native_player_prepare', <String, Object?>{
          'reuse': _videoPlayerController != null,
          'bufferSize': bufferSize,
          'bufferReason': bufferPolicy.reason.name,
          'vpnActive': vpnActive,
          'initialPositionMs': initialPosition.inMilliseconds,
          'effectiveHwdec': effectiveHwdec,
        });
    Player player =
        _videoPlayerController ??
        Player(
          configuration: PlayerConfiguration(
            // 默认缓冲 4M 大小
            bufferSize: bufferSize,
            logLevel: MPVLogLevel.v,
          ),
        );
    await _diagnosticSession?.checkpoint('native_player_ready');
    final NativePlayer pp = player.platform as NativePlayer;
    await _diagnosticSession?.checkpoint('native_properties_begin');
    await pp.setProperty('demuxer-max-bytes', bufferSize.toString());
    await pp.setProperty('demuxer-max-back-bytes', bufferSize.toString());
    // 解除倍速限制
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    //  音量不一致
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      String ao = setting.get(SettingBoxKey.useOpenSLES, defaultValue: false)
          ? "opensles,audiotrack"
          : "audiotrack,opensles";
      await pp.setProperty("ao", ao);
    }
    // video-sync=display-resample
    await pp.setProperty(
      "video-sync",
      setting.get(SettingBoxKey.videoSync, defaultValue: 'display-resample'),
    );
    if (Platform.isAndroid && _videoController != null) {
      await pp.setProperty('vf', '');
      await pp.setProperty('fbo-format', 'auto');
      await pp.setProperty('hwdec', effectiveHwdec ?? 'no');
    }
    // await pp.setProperty('vf', 'rotate=90');
    await pp.setProperty('force-seekable', 'yes');
    // await pp.setProperty("video-rotate", "no");
    // await pp.setProperty("video-zoom","0");
    // await pp.setProperty("vf", "tblend=c0_mode=difference,eq=contrast=2");
    // await pp.setProperty("vf", "scale")
    // // vo=gpu-next & gpu-context=android & gpu-api=opengl
    // await pp.setProperty("vo", "gpu-next");
    // await pp.setProperty("gpu-context", "android");
    // await pp.setProperty("gpu-api", "opengl");
    await player.setAudioTrack(AudioTrack.auto());
    // DURL 自带音频；清空外置音轨列表时不能把空字符串当成文件加载。
    await pp.command(
      buildExternalAudioCommand(
        dataSource.audioSource,
        isWindows: UniversalPlatform.isWindows,
      ),
    );
    await _diagnosticSession?.checkpoint('native_properties_complete');

    // 字幕
    if (dataSource.subFiles != '' && dataSource.subFiles != null) {
      await pp.setProperty(
        'sub-files',
        UniversalPlatform.isWindows
            ? dataSource.subFiles!.replaceAll(';', '\\;')
            : dataSource.subFiles!.replaceAll(':', '\\:'),
      );
      await pp.setProperty("subs-with-matching-audio", "no");
      await pp.setProperty("sub-forced-only", "yes");
      await pp.setProperty("blend-subtitles", "video");
    }

    await _diagnosticSession?.checkpoint(
      'video_controller_prepare',
      <String, Object?>{'reuse': _videoController != null},
    );
    if (_videoController == null) {
      _videoController = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: enableHA,
          androidAttachSurfaceAfterVideoParameters: false,
          hwdec: effectiveHwdec,
        ),
      );
    }
    await _diagnosticSession?.checkpoint('video_controller_ready');

    player.setPlaylistMode(looping);
    await _diagnosticSession?.checkpoint('media_open_begin');
    if (dataSource.type == DataSourceType.asset) {
      final assetUrl = dataSource.videoSource!.startsWith("asset://")
          ? dataSource.videoSource!
          : "asset://${dataSource.videoSource!}";
      await player.open(
        Media(assetUrl, httpHeaders: dataSource.httpHeaders, start: seekTo),
        play: false,
      );
    } else {
      await player.open(
        Media(
          dataSource.videoSource!,
          httpHeaders: dataSource.httpHeaders,
          start: seekTo,
        ),
        play: false,
      );
    }
    await _diagnosticSession?.checkpoint('media_open_complete');
    // 音轨
    // player.setAudioTrack(
    //   AudioTrack.uri(dataSource.audioSource!),
    // );

    return player;
  }

  Future<bool> refreshPlayer({int? expectedSession}) async {
    if (expectedSession != null && expectedSession != _playbackSession) {
      return false;
    }
    if (_refreshInFlight) return false;
    _refreshInFlight = true;
    Duration currentPos = _position.value;
    try {
      await _diagnosticSession?.checkpoint(
        'media_refresh_begin',
        <String, Object?>{'positionMs': currentPos.inMilliseconds},
      );
      if (_videoPlayerController == null) {
        SmartDialog.showToast('视频播放器为空，请重新进入本页面');
        return false;
      }
      if (dataSource.videoSource?.isEmpty ?? true) {
        SmartDialog.showToast('视频源为空，请重新进入本页面');
        return false;
      }
      await (_videoPlayerController!.platform as NativePlayer).command(
        buildExternalAudioCommand(
          dataSource.audioSource,
          isWindows: UniversalPlatform.isWindows,
        ),
      );
      if (expectedSession != null && expectedSession != _playbackSession) {
        return false;
      }
      _positionGuard.expectPosition(currentPos);
      await _videoPlayerController!.open(
        Media(
          dataSource.videoSource!,
          httpHeaders: dataSource.httpHeaders,
          start: currentPos,
        ),
        play: true,
      );
      await _diagnosticSession?.checkpoint('media_refresh_complete');
      return true;
    } catch (err) {
      await _diagnosticSession?.checkpoint(
        'media_refresh_error',
        <String, Object?>{'error': err.toString()},
      );
      return false;
    } finally {
      _refreshInFlight = false;
    }
    // seekTo(currentPos);
  }

  Future<void> _handleHardwareDecodeFailure(int session) async {
    if (session != _playbackSession || _videoPlayerController == null) return;
    final Map<String, Object?> nativeState = await _readNativeVideoState();
    final HardwareDecodeFailureContext context = HardwareDecodeFailureContext(
      position: _position.value,
      wasPlaying: _videoPlayerController!.state.playing,
      videoCodec: nativeState['video-codec']?.toString(),
      pixelFormat: _pixelFormatFromState(nativeState),
    );
    await _diagnosticSession
        ?.checkpoint('hardware_decode_recovery_begin', <String, Object?>{
          'positionMs': context.position.inMilliseconds,
          'wasPlaying': context.wasPlaying,
          ...nativeState,
        });

    HardwareDecodeRecoveryDecision decision =
        HardwareDecodeRecoveryDecision.unavailable;
    final HardwareDecodeFailureHandler? handler = _onHardwareDecodeFailure;
    if (handler != null) {
      try {
        decision = await handler(context);
      } catch (err, stackTrace) {
        await _diagnosticSession?.checkpoint(
          'hardware_decode_source_recovery_error',
          <String, Object?>{'error': err.toString()},
        );
        await _recordPlayerFailure(
          DiagnosticFailureKind.hardwareDecodeSourceRecovery,
          err,
          stackTrace,
        );
      }
    }
    await _diagnosticSession?.checkpoint(
      'hardware_decode_source_recovery_result',
      <String, Object?>{'decision': decision.name},
    );
    if (session != _playbackSession ||
        decision == HardwareDecodeRecoveryDecision.sourceReplaced) {
      return;
    }
    await _retryWithSoftwareDecoding(session, initialState: nativeState);
  }

  Future<void> _retryWithSoftwareDecoding(
    int session, {
    Map<String, Object?>? initialState,
  }) async {
    final Future<void> previousOperation = _sourceOperation;
    final Completer<void> operationCompleter = Completer<void>();
    _sourceOperation = operationCompleter.future;
    try {
      try {
        await previousOperation;
      } catch (_) {}
      if (session != _playbackSession || _videoPlayerController == null) {
        return;
      }

      final DataSource fallbackSource = dataSource;
      final Player player = _videoPlayerController!;
      final NativePlayer nativePlayer = player.platform as NativePlayer;
      final Duration resumePosition = _position.value;
      final bool resumePlayback = player.state.playing;
      final Map<String, Object?> stateBeforeFallback =
          initialState ?? await _readNativeVideoState();
      bool compatibilityFilterApplied = _stateRequires8BitOutput(
        stateBeforeFallback,
      );

      dataStatus.status.value = DataStatus.loading;
      await _diagnosticSession
          ?.checkpoint('hardware_decode_fallback_begin', <String, Object?>{
            'positionMs': resumePosition.inMilliseconds,
            'requires8BitOutput': compatibilityFilterApplied,
            ...stateBeforeFallback,
          });

      // mpv allows changing hwdec before reloading the same media. Reusing the
      // player also preserves Android's already attached SurfaceTexture; fully
      // recreating Player here can leave Flutter displaying the disposed
      // texture even though software decoding itself has started successfully.
      await nativePlayer.setProperty('hwdec', 'no');
      if (compatibilityFilterApplied) {
        await _applyAndroid8BitSoftwareOutputFilter(
          nativePlayer,
          detectedState: stateBeforeFallback,
          phase: 'before_software_open',
        );
      }
      await nativePlayer.command(
        buildExternalAudioCommand(
          fallbackSource.audioSource,
          isWindows: UniversalPlatform.isWindows,
        ),
      );
      _positionGuard.expectPosition(resumePosition);
      final String fallbackVideoSource =
          fallbackSource.type == DataSourceType.asset &&
              !fallbackSource.videoSource!.startsWith('asset://')
          ? 'asset://${fallbackSource.videoSource}'
          : fallbackSource.videoSource!;
      await player.open(
        Media(
          fallbackVideoSource,
          httpHeaders: fallbackSource.httpHeaders,
          start: resumePosition,
        ),
        play: resumePlayback,
      );
      if (session != _playbackSession) return;
      Map<String, Object?> stateAfterFallback = await _waitForDecodedVideoState(
        session,
      );
      if (!compatibilityFilterApplied &&
          _stateRequires8BitOutput(stateAfterFallback)) {
        await _applyAndroid8BitSoftwareOutputFilter(
          nativePlayer,
          detectedState: stateAfterFallback,
          phase: 'after_software_open',
        );
        compatibilityFilterApplied = true;
        stateAfterFallback = await _readNativeVideoState();
      }
      _duration.value = player.state.duration;
      updateDurationSecond();
      dataStatus.status.value = DataStatus.loaded;
      chooseSubtitle();
      _hardwareDecodeFallbackGuard.finishFallback(session);
      SmartDialog.showToast('硬件解码失败，已切换为软件解码');
      await _diagnosticSession
          ?.checkpoint('hardware_decode_fallback_complete', <String, Object?>{
            'positionMs': resumePosition.inMilliseconds,
            'compatibilityFilterApplied': compatibilityFilterApplied,
            ...stateAfterFallback,
          });
    } catch (err, stackTrace) {
      if (session != _playbackSession) return;
      _hardwareDecodeFallbackGuard.finishFallback(session);
      dataStatus.status.value = DataStatus.error;
      await _diagnosticSession?.checkpoint(
        'hardware_decode_fallback_error',
        <String, Object?>{'error': err.toString()},
      );
      await _recordPlayerFailure(
        DiagnosticFailureKind.hardwareDecodeFallback,
        err,
        stackTrace,
        completeSession: true,
      );
      SmartDialog.showToast('软件解码仍然失败，请尝试切换画质或关闭硬解');
    } finally {
      operationCompleter.complete();
    }
  }

  String? _pixelFormatFromState(Map<String, Object?> state) {
    for (final String property in <String>[
      'video-out-params/pixelformat',
      'video-params/pixelformat',
    ]) {
      final String value = state[property]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  bool _stateRequires8BitOutput(Map<String, Object?> state) {
    return <String>[
      'video-out-params/pixelformat',
      'video-params/pixelformat',
    ].any(
      (String property) =>
          requiresAndroid8BitSoftwareOutput(state[property]?.toString()),
    );
  }

  Future<Map<String, Object?>> _waitForDecodedVideoState(int session) async {
    Map<String, Object?> state = await _readNativeVideoState();
    String? previousPixelFormat;
    int stableReadCount = 0;
    for (int attempt = 0; attempt < 8; attempt++) {
      if (session != _playbackSession || _stateRequires8BitOutput(state)) {
        return state;
      }
      final String? pixelFormat = _pixelFormatFromState(state);
      if (pixelFormat != null) {
        stableReadCount = pixelFormat == previousPixelFormat
            ? stableReadCount + 1
            : 1;
        previousPixelFormat = pixelFormat;
        if (stableReadCount >= 3) return state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 125));
      state = await _readNativeVideoState();
    }
    return state;
  }

  Future<void> _applyAndroid8BitSoftwareOutputFilter(
    NativePlayer nativePlayer, {
    required Map<String, Object?> detectedState,
    required String phase,
  }) async {
    await nativePlayer.setProperty('vf', 'format=yuv420p');
    await _diagnosticSession?.checkpoint(
      'software_decode_8bit_filter_applied',
      <String, Object?>{'phase': phase, ...detectedState},
    );
  }

  Future<Map<String, Object?>> _readNativeVideoState() async {
    final Player? player = _videoPlayerController;
    if (player == null) return const <String, Object?>{};
    final NativePlayer nativePlayer = player.platform as NativePlayer;
    final Map<String, Object?> state = <String, Object?>{};
    for (final String property in <String>[
      'video-codec',
      'video-format',
      'hwdec-current',
      'current-vo',
      'vo-configured',
      'width',
      'height',
      'estimated-vf-fps',
      'video-params/pixelformat',
      'video-out-params/pixelformat',
      'fbo-format',
      'decoder-frame-drop-count',
      'frame-drop-count',
    ]) {
      try {
        state[property] = await nativePlayer.getProperty(property);
      } catch (err) {
        state[property] = 'error: $err';
      }
    }
    state['videoRect'] = _videoController?.rect.value?.toString();
    state['textureId'] = _videoController?.id.value;
    return state;
  }

  // 开始播放
  Future _initializePlayer({bool? autoplay}) async {
    if (_instance == null) return;
    // 设置倍速
    if (videoType.value == 'live') {
      await setPlaybackSpeed(1.0);
    } else {
      if (_playbackSpeed.value != 1.0) {
        await setPlaybackSpeed(_playbackSpeed.value);
      } else {
        await setPlaybackSpeed(1.0);
      }
    }
    getVideoFit();
    // if (_looping) {
    //   await setLooping(_looping);
    // }

    // 跳转播放
    // if (seekTo != Duration.zero) {
    //   await this.seekTo(seekTo);
    // }

    // 自动播放
    if (autoplay ?? _autoPlay) {
      await playIfExists();
      // await play(duration: duration);
    }
  }

  Future<void> autoEnterFullScreen() async {
    bool autoEnterFullscreen = GStorage.setting.get(
      SettingBoxKey.enableAutoEnter,
      defaultValue: false,
    );
    if (autoEnterFullscreen) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (dataStatus.status.value != DataStatus.loaded) {
          _dataListenerForEnterFullScreen = dataStatus.status.listen((status) {
            if (status == DataStatus.loaded) {
              _dataListenerForEnterFullScreen?.cancel();
              triggerFullScreen(status: true);
            }
          });
        } else {
          triggerFullScreen(status: true);
        }
      });
    }
  }

  final List<Function(Duration position)> _positionListeners = [];
  final List<Function(PlayerStatus status)> _statusListeners = [];

  /// 播放事件监听
  void startListeners(int session) {
    final Player player = videoPlayerController!;
    subscriptions.addAll([
      player.stream.playing.listen((event) {
        if (session != _playbackSession) return;
        if (event) {
          playerStatus.status.value = PlayerStatus.playing;
        } else {
          playerStatus.status.value = PlayerStatus.paused;
        }
        videoPlayerServiceHandler.onStatusChange(
          playerStatus.status.value,
          isBuffering.value,
        );

        /// 触发回调事件
        for (var element in _statusListeners) {
          // if (element != null) {
          element(event ? PlayerStatus.playing : PlayerStatus.paused);
          // }
        }
        if (player.state.position.inSeconds != 0) {
          makeHeartBeat(positionSeconds.value, type: 'status');
        }
      }),
      player.stream.completed.listen((event) {
        if (session != _playbackSession) return;
        if (event) {
          print("stream completed");
          playerStatus.status.value = PlayerStatus.completed;

          /// 触发回调事件
          for (var element in _statusListeners) {
            element(PlayerStatus.completed);
          }
        } else {
          // playerStatus.status.value = PlayerStatus.playing;
        }
        makeHeartBeat(positionSeconds.value, type: 'completed');
      }),
      player.stream.position.listen((event) {
        if (session != _playbackSession) return;
        final PlaybackPositionDecision decision = _positionGuard.evaluate(
          event,
          isPlaying: player.state.playing,
          isBuffering: isBuffering.value,
          isLive: videoType.value == 'live',
        );
        if (decision.action == PlaybackPositionAction.ignore) return;
        if (decision.action == PlaybackPositionAction.correct) {
          unawaited(
            _correctUnexpectedPosition(
              session: session,
              reportedPosition: event,
              targetPosition: decision.correctionTarget!,
              regression: decision.regression!,
            ),
          );
          return;
        }
        _position.value = event;
        updatePositionSecond();
        if (!isSliderMoving.value) {
          _sliderPosition.value = event;
          updateSliderPositionSecond();
        }

        /// 触发回调事件
        for (var element in _positionListeners) {
          element(event);
        }
        makeHeartBeat(event.inSeconds);
      }),
      player.stream.duration.listen((Duration event) {
        if (session != _playbackSession) return;
        duration.value = event;
      }),
      player.stream.buffer.listen((Duration event) {
        if (session != _playbackSession) return;
        _buffered.value = event;
        updateBufferedSecond();
      }),
      player.stream.buffering.listen((bool event) {
        if (session != _playbackSession) return;
        isBuffering.value = event;
        videoPlayerServiceHandler.onStatusChange(
          playerStatus.status.value,
          event,
        );
      }),
      player.stream.log.listen((event) {
        if (session != _playbackSession) return;
        // print('videoPlayerController!.stream.log.listen');
        // print('[pp] $event');
        // if (event.level == "v") {
        if (isBuffering.value) {
          _playerLog.value = "[${event.prefix}]${event.text}";
        }
        // }
        // SmartDialog.showToast('视频加载日志： $event');
      }),
      player.stream.error.listen((String event) {
        if (session != _playbackSession) return;
        final PlayerDiagnosticSession? diagnostic = _diagnosticSession;
        if (diagnostic != null) {
          unawaited(
            diagnostic.checkpoint('native_player_error', <String, Object?>{
              'error': event,
            }),
          );
        }
        // 直播的错误提示没有参考价值，均不予显示
        if (videoType.value == 'live') return;
        final HardwareDecodeFallbackAction fallbackAction =
            _hardwareDecodeFallbackGuard.evaluate(session, event);
        if (fallbackAction == HardwareDecodeFallbackAction.fallback) {
          unawaited(_handleHardwareDecodeFailure(session));
          return;
        }
        if (fallbackAction == HardwareDecodeFallbackAction.suppress) {
          return;
        }
        if (event.startsWith("Failed to open .") ||
            event.startsWith("Cannot open file ''")) {
          SmartDialog.showToast('视频源为空');
        }
        if (event.startsWith("Failed to open https://") ||
            event.startsWith("Can not open external file https://") ||
            //tcp: ffurl_read returned 0xdfb9b0bb
            //tcp: ffurl_read returned 0xffffff99
            event.startsWith('tcp: ffurl_read returned ')) {
          _retryTimer?.cancel();
          if (diagnostic != null) {
            unawaited(diagnostic.checkpoint('network_retry_scheduled'));
          }
          _retryTimer = Timer(const Duration(seconds: 3), () async {
            if (session != _playbackSession) return;
            print("isBuffering.value: ${isBuffering.value}");
            print("_buffered.value: ${_buffered.value}");
            if (isBuffering.value && _buffered.value == Duration.zero) {
              await _diagnosticSession?.checkpoint('network_retry_begin');
              SmartDialog.showToast(
                '视频链接打开失败，重试中',
                displayTime: const Duration(milliseconds: 500),
              );
              if (!await refreshPlayer(expectedSession: session)) {
                await diagnostic?.reportFailure(
                  DiagnosticFailureKind.playerNativeFailure,
                  StateError(event),
                  StackTrace.current,
                );
              }
            }
          });
          return;
        }
        print('videoPlayerController!.stream.error.listen');
        print(event);
        if (event.startsWith('Could not open codec')) {
          unawaited(
            diagnostic?.reportFailure(
              DiagnosticFailureKind.playerNativeFailure,
              StateError(event),
              StackTrace.current,
            ),
          );
          SmartDialog.showToast('视频解码失败，请尝试切换画质或关闭硬解');
          return;
        }
        unawaited(
          diagnostic?.reportFailure(
            DiagnosticFailureKind.playerNativeFailure,
            StateError(event),
            StackTrace.current,
          ),
        );
        SmartDialog.showToast('视频加载错误, $event');
      }),
      // videoPlayerController!.stream.volume.listen((event) {
      //   if (!mute.value && _volumeBeforeMute != event) {
      //     _volumeBeforeMute = event / 100;
      //   }
      // }),
      // 媒体通知监听
      // onPlayerStatusChanged.listen((PlayerStatus event) {
      //   videoPlayerServiceHandler.onStatusChange(event, isBuffering.value);
      // }),
      onPositionChanged.listen((Duration event) {
        if (session != _playbackSession) return;
        EasyThrottle.throttle(
          'mediaServicePosition',
          const Duration(seconds: 1),
          () => videoPlayerServiceHandler.onPositionChange(event),
        );
      }),
    ]);
  }

  Future<void> _correctUnexpectedPosition({
    required int session,
    required Duration reportedPosition,
    required Duration targetPosition,
    required Duration regression,
  }) async {
    if (_positionCorrectionInFlight || session != _playbackSession) return;
    _positionCorrectionInFlight = true;
    _positionGuard.expectPosition(targetPosition);
    try {
      await _diagnosticSession
          ?.checkpoint('unexpected_position_regression', <String, Object?>{
            'reportedPositionMs': reportedPosition.inMilliseconds,
            'targetPositionMs': targetPosition.inMilliseconds,
            'regressionMs': regression.inMilliseconds,
            'bufferedMs': _buffered.value.inMilliseconds,
            'isBuffering': isBuffering.value,
            'playerLog': _playerLog.value,
          });
      if (session != _playbackSession) return;
      await _videoPlayerController?.seek(targetPosition);
    } catch (err) {
      await _diagnosticSession?.checkpoint(
        'position_correction_error',
        <String, Object?>{'error': err.toString()},
      );
      debugPrint('position correction failed: $err');
    } finally {
      _positionCorrectionInFlight = false;
    }
  }

  /// 移除事件监听
  Future<void> removeListeners() async {
    final List<StreamSubscription<dynamic>> current =
        List<StreamSubscription<dynamic>>.from(subscriptions);
    subscriptions.clear();
    await Future.wait(current.map((subscription) => subscription.cancel()));
  }

  /// 跳转至指定位置
  Future<void> seekTo(Duration position, {type = 'seek'}) async {
    // if (position >= duration.value) {
    //   position = duration.value - const Duration(milliseconds: 100);
    // }
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    _positionGuard.expectPosition(position);
    _position.value = position;
    updatePositionSecond();
    _heartDuration = position.inSeconds;
    if (duration.value.inSeconds != 0) {
      if (type != 'slider') {
        /// 拖动进度条调节时，不等待第一帧，防止抖动
        await _videoPlayerController?.stream.buffer.first;
      }
      danmakuController?.clear();
      await _videoPlayerController?.seek(position);
      // if (playerStatus.stopped) {
      //   play();
      // }
    } else {
      print('seek duration else');
      _timerForSeek?.cancel();
      _timerForSeek = Timer.periodic(const Duration(milliseconds: 200), (
        Timer t,
      ) async {
        //_timerForSeek = null;
        if (duration.value.inSeconds != 0) {
          await _videoPlayerController?.stream.buffer.first;
          danmakuController?.clear();
          await _videoPlayerController?.seek(position);
          // if (playerStatus.status.value == PlayerStatus.paused) {
          //   play();
          // }
          t.cancel();
          _timerForSeek = null;
        }
      });
    }
  }

  /// 设置倍速
  Future<void> setPlaybackSpeed(double speed) async {
    /// TODO  _duration.value丢失
    await _videoPlayerController?.setRate(speed);
    // 移除倍速时改变弹幕速度的能力
    // try {
    //   DanmakuOption currentOption = danmakuController!.option;
    //   defaultDuration ??= currentOption.duration;
    //   DanmakuOption updatedOption = currentOption.copyWith(
    //       duration: ((defaultDuration! / speed) * playbackSpeed).round());
    //   danmakuController!.updateOption(updatedOption);
    // } catch (_) {}
    // fix 长按倍速后放开不恢复
    if (doubleSpeedStatus.value == 0) {
      _playbackSpeed.value = speed;
    }
  }

  // 还原默认速度
  Future<void> setDefaultSpeed() async {
    double speed = videoStorage.get(
      VideoBoxKey.playSpeedDefault,
      defaultValue: 1.0,
    );
    await _videoPlayerController?.setRate(speed);
    _playbackSpeed.value = speed;
  }

  /// 设置倍速
  // Future<void> togglePlaybackSpeed() async {
  //   List<double> allowedSpeeds =
  //       PlaySpeed.values.map<double>((e) => e.value).toList();
  //   int index = allowedSpeeds.indexOf(_playbackSpeed.value);
  //   if (index < allowedSpeeds.length - 1) {
  //     setPlaybackSpeed(allowedSpeeds[index + 1]);
  //   } else {
  //     setPlaybackSpeed(allowedSpeeds[0]);
  //   }
  // }

  /// 播放视频
  /// TODO  _duration.value丢失
  Future<void> play({bool repeat = false, bool hideControls = true}) async {
    // String top = Get.currentRoute;
    // print("top:$top");
    // if (!top.startsWith('/video')) {
    //   return;
    // }
    // if (_playerCount.value == 0) return;
    // if (playerStatus.status.value == PlayerStatus.disabled) return;
    final PlaybackCommandCoordinator? commands = _playbackCommands;
    if (commands == null) return;

    await commands.play(
      hideControls: hideControls,
      restart: repeat || playerStatus.completed,
    );

    // Future.delayed(const Duration(milliseconds: 100), () {
    //   getCurrentVolume();
    // });
  }

  /// 暂停播放
  Future<void> pause({bool notify = true, bool isInterrupt = false}) async {
    await _playbackCommands?.pause(isInterrupt: isInterrupt);
  }

  // 感觉用这个管理状态也不是很好用
  void disable() async {
    if (floatingManager.containsFloating(globalId)) return;
    String top = Get.currentRoute;
    print("top:$top");
    if (!top.startsWith('/video') && !top.startsWith('/live')) {
      // playerStatus.status.value = PlayerStatus.disabled;
      _heartDuration = 0;
      _videoPlayerController?.stop();
      videoPlayerServiceHandler.clear();
      return;
    }
  }

  /// 更改播放状态
  Future<void> togglePlay() async {
    await _playbackCommands?.toggle(restart: playerStatus.completed);
  }

  /// 隐藏控制条
  void _hideTaskControls() {
    if (_timer != null) {
      _timer!.cancel();
    }
    Duration waitingTime = Duration(seconds: enableLongShowControl ? 30 : 3);
    _timer = Timer(waitingTime, () {
      if (!isSliderMoving.value) {
        controls = false;
      }
      _timer = null;
    });
  }

  /// 调整播放时间
  onChangedSlider(double v) {
    _sliderPosition.value = Duration(seconds: v.floor());
    updateSliderPositionSecond();
  }

  void onChangedSliderStart() {
    _isSliderMoving.value = true;
  }

  void onUpdatedSliderProgress(Duration value) {
    _sliderTempPosition.value = value;
    _sliderPosition.value = value;
    updateSliderPositionSecond();
  }

  void onChangedSliderEnd() {
    feedBack();
    _isSliderMoving.value = false;
    _hideTaskControls();
  }

  /// 音量
  Future<void> getCurrentVolume() async {
    // mac try...catch
    try {
      _currentVolume.value = (await FlutterVolumeController.getVolume())!;
    } catch (_) {}
  }

  Future<void> setVolume(
    double volumeNew, {
    bool videoPlayerVolume = false,
  }) async {
    if (volumeNew < 0.0) {
      volumeNew = 0.0;
    } else if (volumeNew > 1.0) {
      volumeNew = 1.0;
    }
    if (volume.value == volumeNew) {
      return;
    }
    volume.value = volumeNew;

    try {
      FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(volumeNew);
    } catch (err) {
      print(err);
    }
  }

  void volumeUpdated() {
    showVolumeStatus.value = true;
    _timerForShowingVolume?.cancel();
    _timerForShowingVolume = Timer(const Duration(seconds: 1), () {
      showVolumeStatus.value = false;
    });
  }

  /// 亮度
  // Future<void> getCurrentBrightness() async {
  //   try {
  //     _currentBrightness.value = await ScreenBrightness().current;
  //   } catch (e) {
  //     throw 'Failed to get current brightness';
  //     //return 0;
  //   }
  // }

  // Future<void> setBrightness(double brightness) async {
  //   try {
  //     this.brightness.value = brightness;
  //     await ScreenBrightness.instance.setSystemScreenBrightness(brightness);
  //   } catch (e) {
  //     throw 'Failed to set brightness';
  //   }
  // }

  // Future<void> resetBrightness() async {
  //   try {
  //     await ScreenBrightness().resetScreenBrightness();
  //   } catch (e) {
  //     throw 'Failed to reset brightness';
  //   }
  // }

  /// Toggle Change the videofit accordingly
  void toggleVideoFit() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('视频尺寸'),
          content: StatefulBuilder(
            builder: (context, StateSetter setState) {
              return Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 2,
                children: [
                  for (var i in videoFitType) ...[
                    if (_videoFit.value == i['attr']) ...[
                      FilledButton(
                        onPressed: () async {
                          _videoFit.value = i['attr'];
                          _videoFitDesc.value = i['desc'];
                          setVideoFit();
                          Get.back();
                        },
                        child: Text(i['desc']),
                      ),
                    ] else ...[
                      FilledButton.tonal(
                        onPressed: () async {
                          _videoFit.value = i['attr'];
                          _videoFitDesc.value = i['desc'];
                          setVideoFit();
                          Get.back();
                        },
                        child: Text(i['desc']),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// 缓存fit
  Future<void> setVideoFit() async {
    List attrs = videoFitType.map((e) => e['attr']).toList();
    int index = attrs.indexOf(_videoFit.value);
    SmartDialog.showToast(
      videoFitType[index]['toast'],
      displayTime: const Duration(seconds: 1),
    );
    videoStorage.put(VideoBoxKey.cacheVideoFit, index);
  }

  /// 读取fit
  Future<void> getVideoFit() async {
    int fitValue = videoStorage.get(VideoBoxKey.cacheVideoFit, defaultValue: 0);
    var attr = videoFitType[fitValue]['attr'];
    // 由于none与scaleDown涉及视频原始尺寸，需要等待视频加载后再设置，否则尺寸会变为0，出现错误;
    if (attr == BoxFit.none || attr == BoxFit.scaleDown) {
      if (buffered.value == Duration.zero) {
        attr = BoxFit.contain;
        _dataListenerForVideoFit = dataStatus.status.listen((status) {
          if (status == DataStatus.loaded) {
            _dataListenerForVideoFit?.cancel();
            int fitValue = videoStorage.get(
              VideoBoxKey.cacheVideoFit,
              defaultValue: 0,
            );
            var attr = videoFitType[fitValue]['attr'];
            if (attr == BoxFit.none || attr == BoxFit.scaleDown) {
              _videoFit.value = attr;
            }
          }
        });
      }
      // fill不应该在竖屏视频生效
    } else if (attr == BoxFit.fill && direction.value == 'vertical') {
      attr = BoxFit.contain;
    }
    _videoFit.value = attr;
    _videoFitDesc.value = videoFitType[fitValue]['desc'];
  }

  /// 设置后台播放
  Future<void> setBackgroundPlay(bool val) async {
    setting.put(SettingBoxKey.enableBackgroundPlay, val);
    videoPlayerServiceHandler.revalidateSetting();
  }

  /// 读取亮度
  // Future<void> getVideoBrightness() async {
  //   double brightnessValue =
  //       videoStorage.get(VideoBoxKey.videoBrightness, defaultValue: 0.5);
  //   setBrightness(brightnessValue);
  // }

  set controls(bool visible) {
    if (_showControls.value == visible) return;
    _showControls.value = visible;
    _timer?.cancel();
    if (visible) {
      _hideTaskControls();
    }
  }

  /// 设置长按倍速状态 live模式下禁用
  void setDoubleSpeedStatus(bool val) async {
    if (videoType.value == 'live') {
      return;
    }
    if (controlsLock.value) {
      return;
    }
    if (val) {
      _doubleSpeedStatus.value = enableAutoLongPressSpeed
          ? playbackSpeed * 2
          : longPressSpeed;
      await setPlaybackSpeed(_doubleSpeedStatus.value);
      if (enableLongPressSpeedIncrease) {
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
          if (_doubleSpeedStatus.value > 0) {
            _doubleSpeedStatus.value = min(8, _doubleSpeedStatus.value * 1.15);
            await setPlaybackSpeed(_doubleSpeedStatus.value);
          } else {
            timer.cancel();
          }
        });
      }
    } else {
      print("playbackSpeed: $playbackSpeed");
      _doubleSpeedStatus.value = 0;
      await setPlaybackSpeed(playbackSpeed);
    }
  }

  /// 关闭控制栏
  void onLockControl(bool val) {
    feedBack();
    _controlsLock.value = val;
    showControls.value = !val;
  }

  void toggleFullScreen(bool val) {
    _isFullScreen.value = val;
  }

  // 应用内小窗
  bool triggerFloatingWindow(
    VideoIntroController? videoIntroController,
    BangumiIntroController? bangumiIntroController,
    String heroTag,
  ) {
    if (videoController == null) {
      return false;
    }

    Widget iconButton(IconData icon, VoidCallback onPressed) {
      return Expanded(
        child: IconButton(
          constraints: const BoxConstraints(),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((
              Set<WidgetState> states,
            ) {
              return Theme.of(
                Get.context!,
              ).colorScheme.surface.withOpacity(0.9);
            }),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, color: Theme.of(Get.context!).colorScheme.onSurface),
        ),
      );
    }

    print("enterPip");
    print(videoIntroController);
    print(bangumiIntroController);
    bool isLive =
        videoIntroController == null && bangumiIntroController == null;
    double? videoHeight = videoPlayerController?.state.height?.toDouble();
    double? videoWidth = videoPlayerController?.state.width?.toDouble();
    // bool isVertical = direction.value == 'vertical';
    // 长宽比
    double aspectRatio = direction.value == 'horizontal'
        ? 9.0 / 16.0
        : 16.0 / 9.0;

    if (videoWidth != null && videoHeight != null) {
      if ((videoWidth > videoHeight) ^ (direction.value != 'horizontal')) {
        aspectRatio = videoHeight / videoWidth;
      }
    }
    print('videoHeight: $videoHeight');
    print('videoWidth: $videoWidth');
    print('direction.value: ${direction.value}');
    print('aspectRatio: $aspectRatio');
    double floatingWidth = aspectRatio > 1 ? 150.0 : 240.0;
    double extentHeight = 40.0;
    double floatingHeight = floatingWidth * aspectRatio + extentHeight;

    Widget baseWindow = SizedBox(
      width: floatingWidth,
      height: floatingHeight,
      child: Column(
        children: [
          SizedBox(
            width: floatingWidth,
            height: floatingHeight - extentHeight,
            child: InkWell(
              onTap: () {
                if (videoIntroController != null) {
                  videoIntroController.openVideoDetail();
                } else if (bangumiIntroController != null) {
                  bangumiIntroController.openVideoDetail();
                } else {
                  pauseIfExists();
                }
                floatingManager.closeFloating(globalId);
              },
              child: Video(
                controller: videoController!,
                controls: NoVideoControls,
                pauseUponEnteringBackgroundMode:
                    !_continuePlayInBackground.value,
                resumeUponEnteringForegroundMode: true,
                // 字幕尺寸调节
                subtitleViewConfiguration: SubtitleViewConfiguration(
                  style: subtitleStyle.value,
                  padding: EdgeInsets.only(bottom: subtitleBottomPadding.value),
                ),
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(
            width: floatingWidth,
            height: extentHeight,
            child: Row(
              children: [
                // if (videoIntroController != null &&
                //         videoIntroController.hasNextEpisode() ||
                //     bangumiIntroController != null &&
                //         bangumiIntroController.hasNextEpisode())
                // iconButton(Icons.skip_next, () {
                //   if (videoIntroController != null) {
                //     videoIntroController.nextPlay();
                //   } else if (bangumiIntroController != null) {
                //     bangumiIntroController.nextPlay();
                //   }
                // }),
                if (!isLive)
                  iconButton(
                    MdiIcons.rewind10,
                    () => seekTo(
                      position.value - const Duration(seconds: 10),
                      type: 'slide',
                    ),
                  ),
                if (!isLive)
                  Obx(
                    () => iconButton(
                      playerStatus.playing ? Icons.pause : Icons.play_arrow,
                      () => togglePlay(),
                    ),
                  ),
                if (!isLive)
                  iconButton(
                    MdiIcons.fastForward10,
                    () => seekTo(
                      position.value + const Duration(seconds: 10),
                      type: 'slide',
                    ),
                  ),
                iconButton(Icons.close, () {
                  floatingManager.closeFloating(globalId);
                  pauseIfExists();
                }),
              ],
            ),
          ),
        ],
      ),
    );
    // pauseIfExists();
    // int maxLength = max(videoPlayerController!.state.width!,
    //     videoPlayerController!.state.height!);
    // if (maxLength <= 0) {
    //   SmartDialog.showToast('视频尺寸异常，无法开启小窗');
    //   return;
    // }
    // // dp 转像素
    // double lengthLimit = 0.8 *
    //     min(Get.width, Get.height) *
    //     MediaQuery.of(Get.context!).devicePixelRatio;
    // android_window.open(
    //   size: Size(
    //     videoPlayerController!.state.width! / maxLength * lengthLimit,
    //     videoPlayerController!.state.height! / maxLength * lengthLimit,
    //   ),
    //   position: const Offset(100, 300),
    // );
    // await Future.delayed(const Duration(milliseconds: 300));
    // dataSource.startAt = position.value;
    // final response = await android_window.post(
    //   'play',
    //   // dataSource,
    //   json.encode(dataSource.toJson()),
    // );
    // SmartDialog.showToast(response.toString());

    // if (floatingWindow != null) {
    //   floatingWindow!.close();
    // }
    // floatingManager.closeFloating(globalId);
    floatingWindow = floatingManager.createFloating(
      globalId,
      Floating(
        ClipRRect(borderRadius: BorderRadius.circular(16.0), child: baseWindow),
        isPosCache: true,
        slideType: FloatingSlideType.onRightAndTop,
        right: 0,
        top: 100,
        moveOpacity: 0.5,
        slideBottomHeight: 20,
      ),
    );
    floatingWindow!.open(Get.context!);
    var listener = FloatingEventListener()
      ..closeListener = () {
        VideoDetailController? videoDetailCtr;
        try {
          videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);
        } catch (_) {}
        print("videoDetailCtr: $videoDetailCtr");
        if (videoDetailCtr != null) {
          videoDetailCtr.defaultST = position.value;
        }
      };
    floatingWindow!.addFloatingListener(listener);
    return true;
  }

  // 全屏
  Future<void> triggerFullScreen({
    bool status = true,
    bool equivalent = false,
  }) async {
    stopScreenTimer();
    FullScreenMode mode = FullScreenModeCode.fromCode(
      setting.get(SettingBoxKey.fullScreenMode, defaultValue: 0),
    )!;
    bool removeSafeArea = setting.get(
      SettingBoxKey.videoPlayerRemoveSafeArea,
      defaultValue: false,
    );
    if (!isFullScreen.value && status) {
      // StatusBarControl.setHidden(true, animation: StatusBarAnimation.FADE);
      hideStatusBar();

      /// 按照视频宽高比决定全屏方向
      toggleFullScreen(true);
      await Future.delayed(const Duration(milliseconds: 10));

      /// 进入全屏
      if (mode == FullScreenMode.none) {
        return;
      }
      if (mode == FullScreenMode.gravity) {
        await fullAutoModeForceSensor();
        return;
      }
      if (mode == FullScreenMode.vertical ||
          (mode == FullScreenMode.auto && direction.value == 'vertical') ||
          (mode == FullScreenMode.ratio &&
              (Get.height / Get.width < 1.25 ||
                  direction.value == 'vertical'))) {
        await verticalScreenForTwoSeconds();
      } else {
        await landScape();
      }
    } else if (isFullScreen.value && !status) {
      // StatusBarControl.setHidden(false, animation: StatusBarAnimation.FADE);
      if (!removeSafeArea) showStatusBar();
      toggleFullScreen(false);
      await Future.delayed(const Duration(milliseconds: 10));
      if (mode == FullScreenMode.none) {
        return;
      }
      if (!horizontalScreen) {
        await verticalScreenForTwoSeconds();
      } else {
        await autoScreen();
      }
    }
  }

  void addPositionListener(Function(Duration position) listener) =>
      _positionListeners.add(listener);
  void removePositionListener(Function(Duration position) listener) =>
      _positionListeners.remove(listener);
  void addStatusLister(Function(PlayerStatus status) listener) =>
      _statusListeners.add(listener);
  void removeStatusLister(Function(PlayerStatus status) listener) =>
      _statusListeners.remove(listener);

  /// 截屏
  Future screenshot() async {
    final Uint8List? screenshot = await _videoPlayerController!.screenshot(
      format: 'image/png',
    );
    return screenshot;
  }

  Future<void> videoPlayerClosed() async {
    _timer?.cancel();
    _timerForVolume?.cancel();
    _timerForGettingVolume?.cancel();
    timerForTrackingMouse?.cancel();
    _timerForSeek?.cancel();
  }

  // 记录播放记录
  Future makeHeartBeat(int progress, {type = 'playing'}) async {
    if (!_enableHeart || MineController.anonymity) {
      return false;
    }
    if (videoType.value == 'live') {
      return;
    }
    // print("playerStatus.status.value: ${playerStatus.status.value}");
    // print("type: $type");
    bool isComplete =
        playerStatus.status.value == PlayerStatus.completed ||
        type == 'completed';
    // 播放状态变化时，更新
    if (type == 'status' || type == 'completed') {
      await VideoHttp.heartBeat(
        bvid: _bvid,
        cid: _cid,
        progress: isComplete ? -1 : progress,
      );
      return;
    }
    // 正常播放时，间隔3秒更新一次
    if (progress - _heartDuration >= 3) {
      _heartDuration = progress;
      await VideoHttp.heartBeat(bvid: _bvid, cid: _cid, progress: progress);
    }
  }

  setPlayRepeat(PlayRepeat type) {
    playRepeat = type;
    videoStorage.put(VideoBoxKey.playRepeat, type.value);
  }

  void putDanmakuSettings() {
    setting.put(SettingBoxKey.danmakuWeight, PlDanmakuController.danmakuWeight);
    setting.put(SettingBoxKey.danmakuBlockType, blockTypes);
    setting.put(SettingBoxKey.danmakuShowArea, showArea);
    setting.put(SettingBoxKey.danmakuOpacity, opacityVal);
    setting.put(SettingBoxKey.danmakuFontScale, fontSizeVal);
    setting.put(SettingBoxKey.danmakuDuration, danmakuDurationVal);
    setting.put(SettingBoxKey.strokeWidth, strokeWidth);
    setting.put(SettingBoxKey.fontWeight, fontWeight);
    setting.put(SettingBoxKey.danmakuMassiveMode, massiveMode);
    setting.put(
      SettingBoxKey.convertToScrollDanmaku,
      PlDanmakuController.convertToScrollDanmaku,
    );
  }

  Future<void> releaseNativeResources(PlayerResourceOwner owner) {
    return _releaseNativeResources(owner: owner);
  }

  Future<void> forceReleaseNativeResources() {
    return _releaseNativeResources(force: true);
  }

  Future<void> _releaseNativeResources({
    PlayerResourceOwner? owner,
    bool force = false,
  }) async {
    if (!force && floatingManager.containsFloating(globalId)) return;
    if (!force && !_resourceOwnership.owns(owner!)) return;

    final Future<void> previousOperation = _sourceOperation;
    final Completer<void> operationCompleter = Completer<void>();
    _sourceOperation = operationCompleter.future;
    try {
      await previousOperation;
    } catch (_) {}

    final PlayerDiagnosticSession? diagnostic = _diagnosticSession;
    try {
      await diagnostic?.checkpoint('native_player_release_begin');
      if (force) {
        _resourceOwnership.forceClear();
      } else if (!_resourceOwnership.release(owner!)) {
        return;
      }
      _playbackLifecycle.beginRelease();
      playbackLifecycleState.value = _playbackLifecycle.state;
      _retryTimer?.cancel();
      await _disposeNativePlayer();
      _playbackLifecycle.markIdle();
      playbackLifecycleState.value = _playbackLifecycle.state;
      _nativePlayerStale = false;
      await diagnostic?.complete('native_player_released');
      if (identical(_diagnosticSession, diagnostic)) {
        _diagnosticSession = null;
      }
      videoPlayerServiceHandler.clear();
    } catch (err, stackTrace) {
      await diagnostic?.checkpoint(
        'native_player_release_error',
        <String, Object?>{'error': err.toString()},
      );
      if (diagnostic != null) {
        await diagnostic.reportFailure(
          DiagnosticFailureKind.nativePlayerRelease,
          err,
          stackTrace,
          completeSession: true,
        );
      } else {
        await LocalDiagnostics.instance.recordFailure(
          DiagnosticFailureKind.nativePlayerRelease,
          err,
          stackTrace,
        );
      }
    } finally {
      operationCompleter.complete();
    }
  }

  Future<void> _disposeNativePlayer() async {
    _retryTimer?.cancel();
    _timerForSeek?.cancel();
    final Player? player = _videoPlayerController;
    _videoPlayerController = null;
    _videoController = null;
    _playbackCommands = null;
    try {
      await removeListeners();
    } catch (err) {
      debugPrint('remove player listeners failed: $err');
    }
    if (player != null) {
      try {
        final NativePlayer nativePlayer = player.platform as NativePlayer;
        await nativePlayer.command(
          buildExternalAudioCommand(null, isWindows: Platform.isWindows),
        );
      } catch (err) {
        debugPrint('clear native audio files failed: $err');
      }
      try {
        await player.dispose();
      } catch (err) {
        debugPrint('dispose native player failed: $err');
      }
    }
    _positionGuard.reset();
    _positionCorrectionInFlight = false;
    _refreshInFlight = false;
    _position.value = Duration.zero;
    _sliderPosition.value = Duration.zero;
    _buffered.value = Duration.zero;
    _duration.value = Duration.zero;
    isBuffering.value = false;
    updatePositionSecond();
    updateSliderPositionSecond();
    updateBufferedSecond();
    updateDurationSecond();
  }

  void _attachPlaybackCommands(Player player) {
    _playbackCommands = PlaybackCommandCoordinator(
      engine: MediaKitPlaybackEngine(player),
      audioSession: audioSessionHandler,
      onControlsVisibilityChanged: (bool visible) {
        controls = visible;
      },
      onFeedback: feedBack,
      restartFromBeginning: () => seekTo(Duration.zero, type: 'slider'),
    );
  }

  Future<void> dispose() async {
    // 每次减1，最后销毁
    // if (type == 'single' && playerCount.value > 1) {
    //   _playerCount.value -= 1;
    //   _heartDuration = 0;
    //   pause();
    //   return;
    // }
    // _playerCount.value = 0;
    await pause();
    WidgetsBinding.instance.removeObserver(this);
    try {
      _timer?.cancel();
      _timerForVolume?.cancel();
      _timerForGettingVolume?.cancel();
      timerForTrackingMouse?.cancel();
      _timerForSeek?.cancel();
      // _position.close();
      _playerEventSubs?.cancel();
      // _sliderPosition.close();
      // _sliderTempPosition.close();
      // _isSliderMoving.close();
      // _duration.close();
      // _buffered.close();
      // _showControls.close();
      // _controlsLock.close();

      // playerStatus.status.close();
      // dataStatus.status.close();
      _dataListenerForVideoFit?.cancel();
      _dataListenerForEnterFullScreen?.cancel();
      _playerListenerForEnterPip?.cancel();

      await forceReleaseNativeResources();
      _instance = null;
    } catch (err) {
      print(err);
    }
  }

  Future refreshVideoMetaInfo() async {
    _vttSubtitles.clear();
    final metadata = await VideoHttp.videoMetaInfo(bvid: _bvid, cid: _cid);
    if (metadata case ApiFailure<List<VideoSubtitleSource>> failure) {
      SmartDialog.showToast('查询视频元信息（字幕、防挡、章节等）错误，${failure.message}');
      return;
    }
    final sources = (metadata as ApiSuccess<List<VideoSubtitleSource>>).data;
    if (sources.isEmpty) {
      return;
    }
    final subtitles = await VideoHttp.vttSubtitles(sources);
    if (subtitles case ApiSuccess<List<Map<String, String>>>(:final data)) {
      _vttSubtitles.value = data;
    } else {
      SmartDialog.showToast(
        (subtitles as ApiFailure<List<Map<String, String>>>).message,
      );
    }
    // if (_vttSubtitles.isEmpty) {
    //   SmartDialog.showToast('字幕均加载失败');
    // }
    return;
  }

  void chooseSubtitle() {
    if (_vttSubtitles.isEmpty) return;

    int findSubtitleWithoutAi() {
      return _vttSubtitles.indexWhere((element) {
        return !element['language']!.startsWith('ai');
      }, 1);
    }

    void setSubtitleFallback(int defaultIndex) {
      int index = findSubtitleWithoutAi();
      setSubtitle(index != -1 ? index : defaultIndex);
    }

    String preference = setting.get(
      SettingBoxKey.subtitlePreference,
      defaultValue: SubtitlePreference.values.first.code,
    );

    if (_vttSubtitlesIndex < 1 || _vttSubtitlesIndex >= _vttSubtitles.length) {
      switch (preference) {
        case 'on':
          setSubtitleFallback(1);
          break;
        case 'withoutAi':
          setSubtitleFallback(0);
          break;
        default:
          setSubtitle(0);
      }
      return;
    }

    if (_vttSubtitles[_vttSubtitlesIndex.value]['language']!.startsWith('ai')) {
      setSubtitleFallback(
        preference == 'withoutAi' ? 0 : _vttSubtitlesIndex.value,
      );
    } else {
      setSubtitle(_vttSubtitlesIndex.value);
    }
  }

  // 设定字幕轨道
  setSubtitle(int index) {
    if (index == 0) {
      _videoPlayerController?.setSubtitleTrack(SubtitleTrack.no());
      _vttSubtitlesIndex.value = 0;
      return;
    }
    Map<String, String> s = _vttSubtitles[index];
    debugPrint(s['text']);
    _videoPlayerController?.setSubtitleTrack(
      SubtitleTrack.data(
        s['text']!,
        title: s['title']!,
        language: s['language']!,
      ),
    );
    _vttSubtitlesIndex.value = index;
  }

  void setContinuePlayInBackground(bool? status) {
    _continuePlayInBackground.value =
        status ?? !_continuePlayInBackground.value;
    setting.put(
      SettingBoxKey.continuePlayInBackground,
      _continuePlayInBackground.value,
    );
  }

  void setOnlyPlayAudio(bool? status) {
    _onlyPlayAudio.value = status ?? !_onlyPlayAudio.value;
    videoPlayerController?.setVideoTrack(
      _onlyPlayAudio.value ? VideoTrack.no() : VideoTrack.auto(),
    );
  }

  void setSubtitleFontSize() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('字幕字号设置'),
          content: StatefulBuilder(
            builder: (context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: subtitleFontSize.value,
                    onChanged: (double value) {
                      setState(() {
                        subtitleFontSize.value = value;
                        subtitleStyle.value = subtitleStyle.value.copyWith(
                          fontSize: subtitleFontSize.value,
                        );
                      });
                    },
                    onChangeEnd: (double value) {
                      videoStorage.put(VideoBoxKey.subtitleFontSize, value);
                    },
                    min: 40.0,
                    max: 120.0,
                    divisions: 80,
                    label: subtitleFontSize.value.round().toString(),
                  ),
                  Text(
                    '当前字号：${subtitleFontSize.value.round()}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void setSubtitleBottomPadding() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('字幕底部间距设置'),
          content: StatefulBuilder(
            builder: (context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: subtitleBottomPadding.value,
                    onChanged: (double value) {
                      setState(() {
                        subtitleBottomPadding.value = value;
                      });
                    },
                    onChangeEnd: (double value) {
                      videoStorage.put(
                        VideoBoxKey.subtitleBottomPadding,
                        value,
                      );
                    },
                    min: 10.0,
                    max: 180.0,
                    divisions: 170,
                    label: subtitleBottomPadding.value.round().toString(),
                  ),
                  Text(
                    '当前底部间距：${subtitleBottomPadding.value.round()}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

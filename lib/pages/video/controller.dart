import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/constants.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video_api.dart';
import 'package:pilipalaz/http/pgc.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/models/common/video_source_type.dart';
import 'package:pilipalaz/models/diagnostics/playback_snapshot.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/models/video/play/quality.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/pages/video/playback_input.dart';
import 'package:pilipalaz/pages/video/video_playback_selection.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/hardware_decode_fallback_guard.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/utils.dart';
import 'package:pilipalaz/utils/video_utils.dart';

import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import '../../../utils/id_utils.dart';
import 'widgets/header_control.dart';

class VideoDetailController extends GetxController
    with GetSingleTickerProviderStateMixin {
  /// 路由传参
  String bvid = Get.parameters['bvid']!;
  RxInt cid = int.parse(Get.parameters['cid']!).obs;
  // 用于小窗返回
  bool resumePlay = Get.parameters['resume']?.toLowerCase() == 'true';
  RxInt danmakuCid = 0.obs;
  late final String heroTag =
      (Get.arguments is Map ? Get.arguments['heroTag'] : null) ??
      Utils.makeHeroTag(int.tryParse(Get.parameters['cid'] ?? '') ?? 0);
  // 视频详情
  Map videoItem = {};
  // 视频类型 默认投稿视频
  late final SearchType videoType =
      (Get.arguments is Map ? Get.arguments['videoType'] : null) ??
      SearchType.video;
  late final VideoSourceType sourceType =
      (Get.arguments is Map ? Get.arguments['sourceType'] : null) ??
      (videoType == SearchType.video
          ? VideoSourceType.archive
          : VideoSourceType.pgc);
  int? epId = int.tryParse(Get.parameters['epId'] ?? '');
  late final bool isOffline =
      (Get.arguments is Map ? Get.arguments['isOffline'] : null) == true;
  DownloadTask? offlineTask;
  File? offlineDanmakuFile;
  File? offlineSubtitleFile;
  PlaybackQueueController? playbackQueueController;

  /// tabs相关配置
  int tabInitialIndex = 0;
  late TabController tabCtr;
  RxList<String> tabs = <String>['简介', '评论'].obs;

  // 请求返回的视频信息
  PlayUrlModel data = PlayUrlModel();
  bool get hasPlayUrlData =>
      data.dash != null || (data.durl != null && data.durl!.isNotEmpty);
  // 请求状态
  RxBool isLoading = false.obs;

  /// 播放器配置 画质 音质 解码格式
  VideoQuality currentVideoQa = VideoQuality.high1080;
  AudioQuality? currentAudioQa;
  VideoDecodeFormats currentDecodeFormats = VideoDecodeFormats.AVC;
  // 是否开始自动播放 存在多p的情况下，第二p需要为true
  RxBool autoPlay = true.obs;
  // 视频资源是否有效
  RxBool isEffective = true.obs;
  // 封面图的展示
  RxBool isShowCover = true.obs;
  RxString playbackError = ''.obs;
  final Rx<PlaybackLoadState> playbackLoadState = PlaybackLoadState.loading.obs;
  // 硬解
  RxBool enableHA = true.obs;
  RxString hwdec = 'auto'.obs;

  /// 本地存储
  Box userInfoCache = GStorage.userInfo;
  Box localCache = GStorage.localCache;
  Box setting = GStorage.setting;

  RxInt oid = 0.obs;
  // 评论id 请求楼中楼评论使用
  // int fRpid = 0;

  // ReplyItemModel? firstFloor;
  // final scaffoldKey = GlobalKey<ScaffoldState>();
  RxString bgCover = ''.obs;
  PlPlayerController? plPlayerController;
  final PlayerResourceOwner playerResourceOwner = PlayerResourceOwner();

  VideoItem firstVideo = VideoItem();
  AudioItem? firstAudio;
  String videoUrl = '';
  String audioUrl = '';
  Duration defaultST = Duration.zero;
  // 亮度
  double? brightness;
  // 默认记录历史记录
  bool enableHeart = true;
  var userInfo;
  bool isFirstTime = true;
  PreferredSizeWidget? headerControl;

  // late bool enableCDN;
  int? cacheVideoQa;
  String cacheDecode = '';
  String cacheSecondDecode = '';
  int cacheAudioQa = 0;
  final HardwareAlternativeRecoveryGuard _hardwareAlternativeRecoveryGuard =
      HardwareAlternativeRecoveryGuard();

  PersistentBottomSheetController? replyReplyBottomSheetCtr;

  @override
  void onInit() async {
    super.onInit();
    final Map argMap = Get.arguments;
    userInfo = userInfoCache.get('userInfoCache');
    var keys = argMap.keys.toList();
    if (keys.isNotEmpty) {
      if (keys.contains('videoItem')) {
        var args = argMap['videoItem'];
        if (args.pic != null && args.pic != '') {
          videoItem['pic'] = args.pic;
        }
      }
      if (keys.contains('pic')) {
        if (argMap['pic'] != null && argMap['pic'] != '') {
          videoItem['pic'] = argMap['pic'];
        }
      }
    }
    offlineTask = Get.arguments is Map
        ? Get.arguments['offlineTask'] as DownloadTask?
        : null;
    if (isOffline) {
      try {
        playbackQueueController = Get.find<PlaybackQueueController>(
          tag: heroTag,
        );
      } catch (_) {
        playbackQueueController = Get.put(
          PlaybackQueueController(heroTag: heroTag),
          tag: heroTag,
        );
      }
      if (DownloadService.isInitialized) {
        final allTasks = DownloadService.instance.getAllTasks();
        final siblings =
            allTasks
                .where(
                  (t) =>
                      t.bvid == bvid &&
                      t.status == DownloadTaskStatus.completed,
                )
                .toList()
              ..sort((a, b) => a.cid.compareTo(b.cid));
        if (siblings.isNotEmpty) {
          playbackQueueController!.onPlayItem = (PlayQueueItem item) async {
            final targetTask = siblings.firstWhereOrNull(
              (t) => t.cid == item.cid,
            );
            if (targetTask != null) {
              return await switchOfflineTask(targetTask);
            }
            return false;
          };
          playbackQueueController!.initFromOfflineTasks(
            tasks: siblings,
            currentCid: cid.value,
          );
        }
      }
    }
    bool defaultShowComment = setting.get(
      SettingBoxKey.defaultShowComment,
      defaultValue: false,
    );
    tabCtr = TabController(
      length: 2,
      vsync: this,
      initialIndex: defaultShowComment ? 1 : 0,
    );
    autoPlay.value =
        resumePlay ||
        setting.get(SettingBoxKey.autoPlayEnable, defaultValue: true);
    if (autoPlay.value) {
      isShowCover.value = false;
      plPlayerController = PlPlayerController.getInstance();
      headerControl = HeaderControl(
        controller: plPlayerController,
        videoDetailCtr: this,
        heroTag: heroTag,
      );
    }
    if (!isOffline && videoItem['pic']?.isEmpty != false) {
      VideoApi.instance.detail(bvid: bvid).then((result) {
        if (result case ApiSuccess(:final data)) {
          videoItem['pic'] = data.pic;
          isShowCover.refresh();
        } else {
          SmartDialog.showToast('视频封面获取失败：${(result as ApiFailure).message}');
        }
      });
    }
    enableHA.value = setting.get(SettingBoxKey.enableHA, defaultValue: true);
    hwdec.value = setting.get(
      SettingBoxKey.hardwareDecoding,
      defaultValue: 'auto',
    ); //Platform.isAndroid ? 'auto-safe' : 'auto');
    if (userInfo == null ||
        localCache.get(LocalCacheKey.historyPause) == true) {
      enableHeart = false;
    }
    danmakuCid.value = cid.value;

    // CDN优化
    // enableCDN = setting.get(SettingBoxKey.enableCDN, defaultValue: true);

    // 预设的画质
    cacheVideoQa = setting.get(
      SettingBoxKey.defaultVideoQa,
      defaultValue: VideoQuality.values.last.code,
    );
    // 预设的解码格式
    cacheDecode = setting.get(
      SettingBoxKey.defaultDecode,
      defaultValue: VideoDecodeFormats.values.last.code,
    );
    cacheSecondDecode = setting.get(
      SettingBoxKey.secondDecode,
      defaultValue: VideoDecodeFormats.values[1].code,
    );
    cacheAudioQa = setting.get(
      SettingBoxKey.defaultAudioQa,
      defaultValue: AudioQuality.hiRes.code,
    );
    if (Get.parameters['bvid'] != null && Get.parameters['bvid']!.isNotEmpty) {
      oid.value = IdUtils.bv2av(Get.parameters['bvid']!);
    } else {
      SmartDialog.showToast('视频信息获取失败，可能为充电视频等特殊情况');
      oid.value = 0;
    }
  }

  // showReplyReplyPanel(BuildContext context) {
  //   // replyReplyBottomSheetCtr =
  //   //     scaffoldKey.currentState?.showBottomSheet((BuildContext context) {
  //   SmartDialog.showAttach(
  //       targetContext: context,
  //       builder: (context) {
  //         return VideoReplyReplyPanel(
  //           oid: oid.value,
  //           rpid: fRpid,
  //           closePanel: () => {
  //             fRpid = 0,
  //           },
  //           firstFloor: firstFloor,
  //           replyType: ReplyType.video,
  //           source: 'videoDetail',
  //         );
  //       });
  //   // replyReplyBottomSheetCtr?.closed.then((value) {
  //   //   fRpid = 0;
  //   // });
  // }

  /// 更新画质、音质
  /// TODO 继续进度播放
  Future<void> updatePlayer({String? preferredCodec}) async {
    if (plPlayerController == null) return;
    final List<VideoItem>? dashVideos = data.dash?.video;
    if (dashVideos == null || dashVideos.isEmpty) {
      SmartDialog.showToast('当前视频不支持切换画质或编码');
      return;
    }

    final List<VideoItem> videoList = dashVideos
        .where((VideoItem item) => item.id == currentVideoQa.code)
        .toList();
    if (videoList.isEmpty) {
      SmartDialog.showToast('当前画质没有可播放的视频源');
      return;
    }

    defaultST = plPlayerController!.position.value;

    /// 根据currentVideoQa和currentDecodeFormats 重新设置videoUrl
    final VideoDecodeFormats defaultDecodeFormats =
        VideoDecodeFormatsCode.fromString(cacheDecode) ??
        VideoDecodeFormats.AVC;
    final VideoDecodeFormats secondDecodeFormats =
        VideoDecodeFormatsCode.fromString(cacheSecondDecode) ??
        VideoDecodeFormats.AV1;
    VideoItem? selectedVideo;
    if (preferredCodec != null) {
      selectedVideo = videoList.firstWhereOrNull(
        (VideoItem item) => item.codecs == preferredCodec,
      );
    }
    if (selectedVideo == null && currentVideoQa != VideoQuality.dolbyVision) {
      for (final VideoDecodeFormats format in <VideoDecodeFormats>[
        currentDecodeFormats,
        defaultDecodeFormats,
        secondDecodeFormats,
      ]) {
        selectedVideo = videoList.firstWhereOrNull(
          (VideoItem item) => format.matches(item.codecs ?? ''),
        );
        if (selectedVideo != null) break;
      }
    }
    firstVideo = selectedVideo ?? videoList.first;
    currentDecodeFormats =
        VideoDecodeFormatsCode.fromString(firstVideo.codecs ?? '') ??
        currentDecodeFormats;

    videoUrl = VideoUtils.getCdnUrl(firstVideo);
    if (videoUrl.isEmpty) {
      SmartDialog.showToast('视频链接为空，请稍后重试');
      return;
    }

    /// 根据currentAudioQa 重新设置audioUrl 与 firstAudio
    final List<AudioItem> dashAudios = <AudioItem>[
      if (data.dash?.flac?.audio != null) data.dash!.flac!.audio!,
      if (data.dash?.dolby?.audio != null) ...data.dash!.dolby!.audio!,
      ...?data.dash?.audio,
    ];
    if (currentAudioQa != null && dashAudios.isNotEmpty) {
      final AudioItem selectedAudio = dashAudios.firstWhere(
        (AudioItem i) => i.id == currentAudioQa!.code,
        orElse: () => dashAudios.first,
      );
      firstAudio = selectedAudio;
      audioUrl = VideoUtils.getCdnUrl(selectedAudio);
    }

    _hardwareAlternativeRecoveryGuard.reset();
    isShowCover.value = false;
    await plPlayerController!.removeListeners();
    plPlayerController!.isBuffering.value = false;
    plPlayerController!.buffered.value = Duration.zero;
    await playerInit();
  }

  Future<void> playerInit({
    String? video,
    String? audio,
    Duration? seekToTime,
    Duration? duration,
    bool autoplay = true,
  }) async {
    /// 设置/恢复 屏幕亮度
    // if (brightness != null) {
    //   ScreenBrightness().setScreenBrightness(brightness!);
    // }
    plPlayerController ??= PlPlayerController.getInstance();
    headerControl ??= HeaderControl(
      controller: plPlayerController,
      videoDetailCtr: this,
      heroTag: heroTag,
    );
    print("resumePlay:${resumePlay},isFirstTime:${isFirstTime}");
    if (!resumePlay) {
      await plPlayerController!.setDataSource(
        DataSource(
          videoSource: video ?? videoUrl,
          audioSource: audio ?? audioUrl,
          type: isOffline ? DataSourceType.file : DataSourceType.network,
          file: isOffline ? File(video ?? videoUrl) : null,
          offlineSubtitleFile: isOffline ? offlineSubtitleFile : null,
          httpHeaders: isOffline
              ? null
              : {
                  'user-agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36',
                  'referer': HttpString.baseUrl,
                },
        ),
        owner: playerResourceOwner,
        // 硬解
        enableHA: enableHA.value,
        hwdec: hwdec.value,
        seekTo: seekToTime ?? defaultST,
        duration: resolvePlaybackDuration(
          explicitDuration: duration,
          fallbackDurationMs: data.timeLength,
        ),
        // 宽>高 水平 否则 垂直
        direction: firstVideo.width != null && firstVideo.height != null
            ? ((firstVideo.width! - firstVideo.height!) > 0
                  ? 'horizontal'
                  : 'vertical')
            : null,
        bvid: bvid,
        cid: cid.value,
        enableHeart: enableHeart,
        autoplay: autoplay,
        onHardwareDecodeFailure: _recoverFromHardwareDecodeFailure,
      );
    } else {
      plPlayerController!.claimNativeResources(playerResourceOwner);
      resumePlay = false;
    }

    /// 开启自动全屏时，在player初始化完成后立即传入headerControl
    plPlayerController!.headerControl = headerControl;
  }

  Future<HardwareDecodeRecoveryDecision> _recoverFromHardwareDecodeFailure(
    HardwareDecodeFailureContext context,
  ) async {
    final List<VideoItem>? videos = data.dash?.video;
    if (videos == null ||
        videos.isEmpty ||
        !_hardwareAlternativeRecoveryGuard.tryBegin()) {
      return HardwareDecodeRecoveryDecision.unavailable;
    }

    final VideoItem? replacement = selectCompatibleFallbackVideo(
      current: firstVideo,
      candidates: videos,
    );
    if (replacement == null) {
      debugPrint(
        'hardware decode source recovery unavailable: '
        'quality=${firstVideo.id}, codec=${firstVideo.codecs}, '
        'size=${firstVideo.width}x${firstVideo.height}',
      );
      return HardwareDecodeRecoveryDecision.unavailable;
    }

    final String replacementUrl = VideoUtils.getCdnUrl(replacement);
    if (replacementUrl.isEmpty) {
      return HardwareDecodeRecoveryDecision.unavailable;
    }

    final VideoItem failedVideo = firstVideo;
    firstVideo = replacement;
    videoUrl = replacementUrl;
    currentVideoQa =
        replacement.quality ??
        (replacement.id == null
            ? null
            : VideoQualityCode.fromCode(replacement.id!)) ??
        currentVideoQa;
    currentDecodeFormats =
        VideoDecodeFormatsCode.fromString(replacement.codecs ?? '') ??
        currentDecodeFormats;
    debugPrint(
      'hardware decode source recovery: '
      '${failedVideo.id}/${failedVideo.codecs}/'
      '${failedVideo.width}x${failedVideo.height} -> '
      '${replacement.id}/${replacement.codecs}/'
      '${replacement.width}x${replacement.height}',
    );

    await playerInit(
      seekToTime: context.position,
      autoplay: context.wasPlaying,
    );
    SmartDialog.showToast(
      '当前编码无法硬解，已切换至 '
      '${currentVideoQa.description} ${describeVideoCodec(replacement.codecs)}',
    );
    return HardwareDecodeRecoveryDecision.sourceReplaced;
  }

  Map<String, dynamic> playbackFailure(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool preserveReady = false,
    Object? code,
  }) {
    playbackError.value = message;
    playbackLoadState.value = transitionPlaybackLoadState(
      current: playbackLoadState.value,
      event: PlaybackLoadEvent.failure,
      preserveReady: preserveReady,
    );
    if (playbackLoadState.value != PlaybackLoadState.ready) {
      isShowCover.value = false;
    }
    if (error != null) {
      unawaited(
        LocalDiagnostics.instance.recordFailure(
          DiagnosticFailureKind.videoPlaybackInitialization,
          error,
          stackTrace,
        ),
      );
    }
    return <String, dynamic>{
      'status': false,
      'msg': message,
      if (code != null) 'code': code,
    };
  }

  void playbackSuccess({required bool showPreviewNotice}) {
    playbackError.value = '';
    playbackLoadState.value = transitionPlaybackLoadState(
      current: playbackLoadState.value,
      event: PlaybackLoadEvent.success,
    );
    if (showPreviewNotice &&
        (data.isPreview || data.acceptDesc?.contains('试看') == true)) {
      SmartDialog.showNotify(
        msg: '当前影视内容仅提供试看，试看结束后可前往官方客户端',
        displayTime: const Duration(seconds: 3),
        notifyType: NotifyType.warning,
      );
    }
  }

  /// 离线多 P 切集（BAC-13: 异步 I/O 先行校验，后原子性提交状态变更）
  Future<bool> switchOfflineTask(DownloadTask newTask) async {
    if (!isOffline) return false;
    try {
      final storage = DownloadStorageManager();
      final videoRel = newTask.videoRelativePath;
      if (videoRel == null) {
        SmartDialog.showToast('离线视频路径不存在');
        return false;
      }
      final videoPath = await storage.absolutePath(videoRel);
      if (!await File(videoPath).exists()) {
        SmartDialog.showToast('离线视频文件不存在');
        return false;
      }

      offlineTask = newTask;
      cid.value = newTask.cid;
      danmakuCid.value = newTask.cid;
      autoPlay.value = true;
      playbackQueueController?.syncCurrent(
        bvid: newTask.bvid,
        cid: newTask.cid,
      );

      final res = await queryVideoUrl();
      return res['status'] == true;
    } catch (e) {
      SmartDialog.showToast('切换分P失败: $e');
      return false;
    }
  }

  // 请求视频资源
  Future<Map<String, dynamic>> queryVideoUrl({
    bool preserveCurrentOnFailure = false,
    bool showPreviewNotice = true,
  }) async {
    _hardwareAlternativeRecoveryGuard.reset();
    playbackError.value = '';
    playbackLoadState.value = transitionPlaybackLoadState(
      current: playbackLoadState.value,
      event: PlaybackLoadEvent.begin,
      preserveReady: preserveCurrentOnFailure,
    );

    Map<String, dynamic> fail(
      String message, {
      Object? error,
      StackTrace? stackTrace,
      Object? code,
    }) => playbackFailure(
      message,
      error: error,
      stackTrace: stackTrace,
      preserveReady: preserveCurrentOnFailure,
      code: code,
    );

    try {
      if (isOffline && offlineTask != null) {
        final storage = DownloadStorageManager();
        final videoRel = offlineTask!.videoRelativePath;
        final audioRel = offlineTask!.audioRelativePath;
        if (videoRel == null) {
          return fail('离线视频路径不存在');
        }
        final videoPath = await storage.absolutePath(videoRel);
        final videoFile = File(videoPath);
        if (!await videoFile.exists()) {
          return fail('离线视频文件不存在');
        }

        videoUrl = videoPath;
        if (audioRel != null) {
          final audioPath = await storage.absolutePath(audioRel);
          final audioFile = File(audioPath);
          audioUrl = (await audioFile.exists()) ? audioPath : '';
        } else {
          audioUrl = '';
        }

        offlineDanmakuFile = null;
        final danmakuRel = offlineTask!.danmakuRelativePath;
        if (danmakuRel != null) {
          final danmakuPath = await storage.absolutePath(danmakuRel);
          final dFile = File(danmakuPath);
          if (await dFile.exists()) {
            offlineDanmakuFile = dFile;
          }
        }

        offlineSubtitleFile = null;
        final subRel =
            offlineTask!.subtitlesRelativePath ??
            storage.pathsForTask(offlineTask!).subtitlesRelativePath;
        final subPath = await storage.absolutePath(subRel);
        final sFile = File(subPath);
        if (await sFile.exists()) {
          offlineSubtitleFile = sFile;
        }

        firstVideo = VideoItem(
          id: offlineTask!.videoQuality,
          codecs: offlineTask!.videoCodec,
        );
        firstAudio = AudioItem(id: offlineTask!.audioQuality);
        currentAudioQa = AudioQualityCode.fromCode(offlineTask!.audioQuality);
        data = PlayUrlModel(
          timeLength: offlineTask!.duration * 1000,
          quality: offlineTask!.videoQuality,
          videoCodecid: 7,
        );
        currentVideoQa =
            VideoQualityCode.fromCode(offlineTask!.videoQuality) ??
            VideoQuality.high1080;
        currentDecodeFormats =
            VideoDecodeFormatsCode.fromString(offlineTask!.videoCodec) ??
            VideoDecodeFormats.AVC;
        defaultST = Duration.zero;

        await playerInit(
          duration: Duration(seconds: offlineTask!.duration),
          autoplay: autoPlay.value,
        );
        playbackSuccess(showPreviewNotice: false);
        return {'status': true};
      }

      if (sourceType.isPgc && epId == null) {
        return fail('缺少影视剧集 ep_id，无法加载播放地址');
      }
      final ApiResult<PlayUrlModel> result = sourceType.isPgc
          ? await PgcApi.instance.playUrl(epId: epId!, cid: cid.value)
          : await VideoApi.instance.playUrl(cid: cid.value, bvid: bvid);
      debugPrint('QUERY_VIDEO_URL: result=$result');
      if (result case ApiSuccess<PlayUrlModel>(data: final playData)) {
        data = playData;
        if (data.isDrm) {
          return fail(PgcPlaybackRestriction.messageFor(isDrm: true));
        }
        if (sourceType.isPgc &&
            data.dash == null &&
            data.durl?.isNotEmpty != true) {
          return fail(
            PgcPlaybackRestriction.messageFor(
              errorCode: data.errorCode,
              isDrm: data.isDrm,
              message: data.message,
            ),
          );
        }
        if (data.dash == null && data.durl != null) {
          final durl = data.durl;
          if (durl == null ||
              durl.isEmpty ||
              durl.first.url?.isNotEmpty != true) {
            return fail('视频资源不完整，请稍后重试');
          }
          videoUrl = durl.first.url!;
          audioUrl = '';
          firstAudio = null;
          currentAudioQa = null;
          defaultST = Duration.zero;
          // 实际为FLV/MP4格式，但已被淘汰，这里仅做兜底处理
          firstVideo = VideoItem(
            id: data.quality!,
            baseUrl: videoUrl,
            codecs: 'avc1',
            quality: VideoQualityCode.fromCode(data.quality!)!,
          );
          currentDecodeFormats = VideoDecodeFormatsCode.fromString('avc1')!;
          currentVideoQa = VideoQualityCode.fromCode(data.quality!)!;
          if (autoPlay.value) {
            isShowCover.value = false;
          }
          await playerInit(
            duration: data.playableDuration,
            autoplay: autoPlay.value,
          );
          playbackSuccess(showPreviewNotice: showPreviewNotice);
          return <String, dynamic>{'status': true, 'data': data};
        }
        if (data.dash == null) {
          return fail('视频资源不存在');
        }
        final List<VideoItem> allVideosList =
            data.dash!.video ?? const <VideoItem>[];
        if (allVideosList.isEmpty) {
          return fail('视频资源不存在');
        }
        final int? resVideoQa = selectPreferredVideoQualityCode(
          preferredCode: cacheVideoQa,
          availableCodes: allVideosList
              .map((VideoItem video) => video.id ?? video.quality?.code)
              .whereType<int>(),
        );
        final VideoQuality? selectedQuality = resVideoQa == null
            ? null
            : VideoQualityCode.fromCode(resVideoQa);
        if (resVideoQa == null || selectedQuality == null) {
          return fail('视频画质信息不完整');
        }
        currentVideoQa = selectedQuality;

        /// 取出符合当前画质的videoList
        final List<VideoItem> videosList = allVideosList
            .where(
              (VideoItem video) =>
                  (video.id ?? video.quality?.code) == resVideoQa,
            )
            .toList();

        /// 优先顺序 设置中指定解码格式 -> 当前可选的首个解码格式
        final List<FormatItem> supportFormats =
            data.supportFormats ?? const <FormatItem>[];
        // 根据画质选编码格式
        final FormatItem? selectedFormat = supportFormats.firstWhereOrNull(
          (FormatItem format) => format.quality == resVideoQa,
        );
        final List<String> supportDecodeFormats =
            selectedFormat?.codecs?.whereType<String>().toList() ??
            videosList
                .map((VideoItem video) => video.codecs)
                .whereType<String>()
                .toList();
        if (videosList.isEmpty || supportDecodeFormats.isEmpty) {
          return fail('视频编码信息不完整');
        }
        final VideoDecodeFormats preferredDecode =
            VideoDecodeFormatsCode.fromString(cacheDecode) ??
            VideoDecodeFormats.AVC;
        final VideoDecodeFormats secondDecode =
            VideoDecodeFormatsCode.fromString(cacheSecondDecode) ??
            VideoDecodeFormats.AV1;
        firstVideo =
            videosList.firstWhereOrNull(
              (VideoItem video) => preferredDecode.matches(video.codecs ?? ''),
            ) ??
            videosList.firstWhereOrNull(
              (VideoItem video) => secondDecode.matches(video.codecs ?? ''),
            ) ??
            videosList.first;
        currentDecodeFormats =
            VideoDecodeFormatsCode.fromString(firstVideo.codecs ?? '') ??
            preferredDecode;
        // List<Video> selectedVideos = videosList.where(
        //       (e) => e.codecs!.startsWith(currentDecodeFormats.code),
        // ).toList();

        // videoUrl = enableCDN
        //     ? VideoUtils.getCdnUrl(firstVideo)
        //     : (firstVideo.backupUrl ?? firstVideo.baseUrl!);
        videoUrl = VideoUtils.getCdnUrl(firstVideo);
        if (videoUrl.isEmpty) {
          return fail('视频链接为空，请稍后重试');
        }

        /// 优先顺序 设置中指定质量 -> 当前可选的最高质量
        final List<AudioItem> audiosList = data.dash!.audio ?? <AudioItem>[];
        if (data.dash!.dolby?.audio != null &&
            data.dash!.dolby!.audio!.isNotEmpty) {
          // 杜比
          audiosList.insert(0, data.dash!.dolby!.audio!.first);
        }

        if (data.dash!.flac?.audio != null) {
          // 无损
          audiosList.insert(0, data.dash!.flac!.audio!);
        }

        if (audiosList.isNotEmpty) {
          final List<int> numbers = audiosList.map((map) => map.id!).toList();
          int closestNumber = Utils.findClosestNumber(cacheAudioQa, numbers);
          if (!numbers.contains(cacheAudioQa) &&
              numbers.any((e) => e > cacheAudioQa)) {
            closestNumber = 30280;
          }
          firstAudio = audiosList.firstWhere(
            (e) => e.id == closestNumber,
            orElse: () => audiosList.first,
          );
          // audioUrl = enableCDN
          //     ? VideoUtils.getCdnUrl(firstAudio)
          //     : (firstAudio.backupUrl ?? firstAudio.baseUrl!);
          audioUrl = VideoUtils.getCdnUrl(firstAudio!);
          if (firstAudio?.id != null) {
            currentAudioQa = AudioQualityCode.fromCode(firstAudio!.id!);
          }
        } else {
          firstAudio = null;
          audioUrl = '';
          currentAudioQa = null;
        }
        //
        defaultST = normalizeHistoryPosition(
          lastPlayTimeMs: data.lastPlayTime,
          durationMs: data.timeLength,
        );
        if (autoPlay.value) {
          isShowCover.value = false;
        }
        await playerInit(autoplay: autoPlay.value);
        playbackSuccess(showPreviewNotice: showPreviewNotice);
      } else {
        final failure = result as ApiFailure<PlayUrlModel>;
        final String resultMessage = failure.message;
        final String message = sourceType.isPgc
            ? PgcPlaybackRestriction.messageFor(
                errorCode: failure.apiCode,
                message: resultMessage,
              )
            : failure.apiCode == -404
            ? '视频不存在或已被删除'
            : failure.apiCode == 87008
            ? '当前视频可能是专属视频，可能需包月充电观看($resultMessage)'
            : (resultMessage.isEmpty ? '视频加载失败，请重试' : resultMessage);
        return fail(message, code: failure.apiCode);
      }
      return <String, dynamic>{'status': true, 'data': data};
    } catch (error, stackTrace) {
      return fail('视频加载失败，请重试', error: error, stackTrace: stackTrace);
    }
  }

  /// 生成当前播放状态的诊断快照
  PlaybackSnapshot generatePlaybackSnapshot() {
    final IPlayerEngine? engine = plPlayerController?.engine;

    // 1. 内核与渲染管线
    String engineName;
    String rendererType;
    String hwdecStr;
    String audioOutput;

    if (engine is Media3PlayerEngine) {
      engineName = 'Media3 (ExoPlayer)';
      rendererType = 'Flutter Texture (SurfaceTexture)';
      hwdecStr = enableHA.value ? 'MediaCodec (硬解优先/软解回退)' : '软件解码';
      audioOutput = 'AudioTrack';
    } else if (engine is MpvPlayerEngine) {
      engineName = 'MPV (media_kit)';
      rendererType = 'Flutter Texture (VideoController)';
      hwdecStr = enableHA.value ? '硬件加速 (${hwdec.value})' : '软件解码 (已禁用)';
      final bool openSles = setting.get(
        SettingBoxKey.useOpenSLES,
        defaultValue: false,
      );
      audioOutput = Platform.isAndroid
          ? (openSles ? 'OpenSL ES' : 'AudioTrack (AAudio)')
          : '系统默认输出';
    } else if (plPlayerController?.videoPlayerController != null) {
      engineName = 'MPV (Legacy Fallback)';
      rendererType = 'Flutter Texture';
      hwdecStr = enableHA.value ? '开启 (${hwdec.value})' : '关闭';
      audioOutput = '系统默认输出';
    } else {
      engineName = '未就绪 / 空闲';
      rendererType = '无';
      hwdecStr = '未知';
      audioOutput = '未知';
    }

    // 2. 视频流规格
    String videoQuality = currentVideoQa.description;

    final VideoItem video = firstVideo;
    String videoCodec = '未知';
    final String rawCodec = video.codecs ?? '';
    final VideoDecodeFormats? format = VideoDecodeFormatsCode.fromString(
      rawCodec,
    );
    videoCodec = format != null
        ? '${format.description} ($rawCodec)'
        : (rawCodec.isNotEmpty ? rawCodec : '未知');

    String resolution = '未知';
    final VideoDimension? dim = plPlayerController?.currentDimension;
    if (dim != null && dim.hasSize) {
      resolution = '${dim.width}x${dim.height}';
    } else if (video.width != null && video.height != null) {
      resolution = '${video.width}x${video.height} (流规格)';
    }

    String frameRate = '未知';
    if (video.frameRate != null && video.frameRate!.isNotEmpty) {
      frameRate = '${video.frameRate} fps';
    }

    String videoBitrate = '未知';
    if (video.bandWidth != null && video.bandWidth! > 0) {
      videoBitrate = '${(video.bandWidth! / 1000).toStringAsFixed(1)} kbps';
    }

    // 3. 音频流规格
    final AudioItem? audio = firstAudio;
    final int? audioId = audio?.id;
    String audioQuality = '无独立音频';
    if (currentAudioQa != null) {
      audioQuality = currentAudioQa!.description;
    } else if (audioId != null) {
      audioQuality = AudioQualityCode.fromCode(audioId)?.description ?? '未知';
    } else if (data.dash == null && data.durl != null) {
      audioQuality = '内嵌音频 (单流)';
    }

    String audioCodec = '未知';
    final String rawAudioCodec = audio?.codecs ?? '';
    if (rawAudioCodec.isNotEmpty) {
      audioCodec = rawAudioCodec;
    } else if (audio?.baseUrl != null && audio!.baseUrl!.isNotEmpty) {
      audioCodec = 'AAC / MP4A';
    } else if (isOffline && audioId != null) {
      audioCodec = switch (audioId) {
        30250 => 'E-AC-3 (杜比全景声)',
        30251 => 'FLAC (Hi-Res无损)',
        _ => 'AAC / MP4A',
      };
    } else if (data.dash == null && data.durl != null) {
      audioCodec = '容器封装 (AAC/MP3)';
    }

    String audioBitrate = '未知';
    final int? audioBandwidth = audio?.bandWidth;
    if (audioBandwidth != null && audioBandwidth > 0) {
      audioBitrate = '${(audioBandwidth / 1000).toStringAsFixed(1)} kbps';
    } else if (audioId != null) {
      audioBitrate = switch (audioId) {
        30280 => '~192.0 kbps (标称)',
        30232 => '~132.0 kbps (标称)',
        30216 => '~64.0 kbps (标称)',
        30250 => '~320.0 kbps (杜比)',
        30251 => '无损压缩',
        _ => '未知',
      };
    }

    // 4. 播放与缓冲健康度
    final Duration pos = plPlayerController?.position.value ?? Duration.zero;
    final Duration dur = plPlayerController?.duration.value ?? Duration.zero;
    final Duration buf = plPlayerController?.buffered.value ?? Duration.zero;
    final double speed = plPlayerController?.playbackSpeed ?? 1.0;

    String stateStr = '未就绪';
    if (plPlayerController != null) {
      if (plPlayerController!.isPlaying) {
        stateStr = '播放中';
      } else if (plPlayerController!.playerStatus.status.value ==
          PlayerStatus.paused) {
        stateStr = '已暂停';
      } else if (plPlayerController!.playerStatus.status.value ==
          PlayerStatus.completed) {
        stateStr = '已完成';
      } else {
        stateStr = '缓冲 / 就绪';
      }
    }

    // 5. 网络与标识
    final String currentBvid = bvid;
    final int currentCid = cid.value;

    String cdnHost = '未知';
    if (isOffline) {
      cdnHost = '本地离线存储';
    } else {
      try {
        if (videoUrl.isNotEmpty) {
          final Uri? uri = Uri.tryParse(videoUrl);
          cdnHost = uri?.host.isNotEmpty == true ? uri!.host : '未知';
        }
      } on FormatException catch (_) {}
    }

    final String srcTypeStr = isOffline
        ? '离线缓存 (${sourceType.isPgc ? '番剧' : '投稿'})'
        : (sourceType.isPgc ? '番剧/影视 (PGC)' : '投稿视频 (UGC)');

    return PlaybackSnapshot(
      engineName: engineName,
      rendererType: rendererType,
      hwdec: hwdecStr,
      audioOutput: audioOutput,
      videoQuality: videoQuality,
      videoCodec: videoCodec,
      resolution: resolution,
      frameRate: frameRate,
      videoBitrate: videoBitrate,
      audioQuality: audioQuality,
      audioCodec: audioCodec,
      audioBitrate: audioBitrate,
      position: pos,
      duration: dur,
      bufferedPosition: buf,
      playbackSpeed: speed,
      playbackState: stateStr,
      bvid: currentBvid,
      cid: currentCid,
      cdnHost: cdnHost,
      sourceType: srcTypeStr,
    );
  }

  // mob端全屏状态关闭二级回复
  hiddenReplyReplyPanel() {
    replyReplyBottomSheetCtr != null
        ? replyReplyBottomSheetCtr!.close()
        : print('replyReplyBottomSheetCtr is null');
  }
}

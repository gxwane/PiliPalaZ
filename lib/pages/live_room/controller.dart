import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/constants.dart';
import 'package:pilipalaz/http/live.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import '../../http/login.dart';
import '../../models/live/room_info_h5.dart';
import '../../services/live/live_danmaku_client.dart';
import '../../services/live/live_message.dart';
import '../../utils/danmaku.dart';
import '../../utils/storage.dart';
import '../../utils/video_utils.dart';

class LiveRoomController extends GetxController {
  String cover = '';
  int roomId = 0;
  dynamic liveItem;
  String heroTag = '';
  double volume = 0.0;
  // 静音状态
  final RxBool volumeOff = false.obs;
  final RxBool isLive = false.obs;
  final RxBool hasStream = false.obs;
  final RxInt popularity = 0.obs;
  LiveDanmakuClient? danmakuClient;
  StreamSubscription<LiveDanmakuItem>? _danmakuSub;
  StreamSubscription<int>? _popularitySub;
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed || isClosed;

  RoomInfoModel? currentRoomInfo;
  CodecItem? _currentCodecItem;
  final RxInt currentQn = 10000.obs;
  final RxString currentQnDesc = '原画'.obs;
  final RxInt currentLineIndex = 0.obs;
  final RxString currentCodec = 'avc'.obs;
  final RxList<GQnDesc> availableQualities = <GQnDesc>[].obs;
  final RxList<String> availableLines = <String>[].obs;
  final RxList<String> availableCodecs = <String>[].obs;
  final RxBool isSwitchingStream = false.obs;

  PlPlayerController plPlayerController = PlPlayerController.getInstance(
    videoType: 'live',
  );
  final PlayerResourceOwner playerResourceOwner = PlayerResourceOwner();
  final Rx<RoomInfoH5Model> roomInfoH5 = RoomInfoH5Model().obs;

  @override
  void onInit() {
    super.onInit();
    final paramRoomId =
        Get.parameters['roomid'] ??
        Get.parameters['roomId'] ??
        Get.parameters['room_id'];
    if (paramRoomId != null && paramRoomId != '0') {
      roomId = int.tryParse(paramRoomId) ?? 0;
    }
    if (Get.arguments != null) {
      if (Get.arguments is Map) {
        liveItem = Get.arguments['liveItem'];
        heroTag = Get.arguments['heroTag']?.toString() ?? '';
        if (roomId == 0) {
          final argRoomId = Get.arguments['roomId'] ?? Get.arguments['roomid'];
          if (argRoomId != null) {
            roomId = int.tryParse(argRoomId.toString()) ?? 0;
          } else if (heroTag.isNotEmpty) {
            final parsedFromTag = int.tryParse(
              heroTag.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            if (parsedFromTag != null && parsedFromTag > 0) {
              roomId = parsedFromTag;
            }
          }
        }
      }
      if (liveItem != null) {
        if (roomId == 0) {
          try {
            roomId = (liveItem.roomId ?? liveItem.roomid ?? 0) as int;
          } catch (_) {}
        }
        if (liveItem.pic != null && liveItem.pic != '') {
          cover = liveItem.pic;
        } else if (liveItem.cover != null && liveItem.cover != '') {
          cover = liveItem.cover;
        }
      }
    }
  }

  Future<void> playerInit(String source) async {
    if (isDisposed) return;
    await plPlayerController.setDataSource(
      DataSource(
        videoSource: source,
        audioSource: null,
        type: DataSourceType.network,
        httpHeaders: {
          'user-agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
          'referer': HttpString.baseUrl,
        },
      ),
      owner: playerResourceOwner,
      enableHA: true,
      autoplay: true,
    );
  }

  FormatItem? _extractFormat(List<Streams> streams) {
    if (streams.isEmpty) return null;
    final stream = streams.firstWhere(
      (s) => s.protocolName?.toLowerCase() == 'http_stream',
      orElse: () => streams.first,
    );
    final formats = stream.format ?? <FormatItem>[];
    if (formats.isEmpty) return null;
    return formats.firstWhere(
      (f) => f.formatName?.toLowerCase() == 'flv',
      orElse: () => formats.first,
    );
  }

  void _selectCodecAndLine(
    List<CodecItem> codecs,
    String? targetCodec,
    int? targetLine,
  ) {
    final codecNames = codecs
        .map((c) => c.codecName?.toLowerCase() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    availableCodecs.assignAll(codecNames);

    final preferredCodec =
        targetCodec?.toLowerCase() ?? currentCodec.value.toLowerCase();
    _currentCodecItem = codecs.firstWhere(
      (c) => c.codecName?.toLowerCase() == preferredCodec,
      orElse: () => codecs.first,
    );
    currentCodec.value = _currentCodecItem?.codecName?.toLowerCase() ?? 'avc';

    final urlInfoList = _currentCodecItem?.urlInfo ?? <UrlInfoItem>[];
    availableLines.assignAll(
      List.generate(urlInfoList.length, (i) => '线路 ${i + 1}'),
    );
    final maxLine = urlInfoList.isEmpty ? 0 : urlInfoList.length - 1;
    currentLineIndex.value = (targetLine ?? currentLineIndex.value).clamp(
      0,
      maxLine,
    );
  }

  void _resolveQualityDesc(List<GQnDesc> gQnDescList, int? targetQn) {
    final qn = _currentCodecItem?.currentQn ?? targetQn ?? 10000;
    currentQn.value = qn;
    final matchDesc = gQnDescList.firstWhereOrNull((q) => q.qn == qn)?.desc;
    currentQnDesc.value = matchDesc ?? _fallbackQnDesc(qn);
  }

  void _updateStreamMetadata(
    RoomInfoModel data, {
    int? targetQn,
    int? targetLine,
    String? targetCodec,
  }) {
    currentRoomInfo = data;
    final playurl = data.playurlInfo?.playurl;
    final format = _extractFormat(playurl?.stream ?? <Streams>[]);
    final codecs = format?.codec ?? <CodecItem>[];
    if (codecs.isEmpty) {
      _currentCodecItem = null;
      availableLines.clear();
      availableCodecs.clear();
      availableQualities.clear();
      return;
    }
    _selectCodecAndLine(codecs, targetCodec, targetLine);
    final rawQualities = playurl?.gQnDesc ?? <GQnDesc>[];
    final filtered = VideoUtils.filterAndSortQualities(
      allQualities: rawQualities,
      acceptQn: _currentCodecItem?.acceptQn,
    );
    availableQualities.assignAll(filtered);
    _resolveQualityDesc(filtered, targetQn);
  }

  static String _fallbackQnDesc(int qn) {
    if (qn >= 10000) return '原画';
    if (qn >= 400) return '蓝光';
    if (qn >= 250) return '超清';
    if (qn >= 150) return '高清';
    return '流畅';
  }

  Future<bool> _applyLiveStream({required String successToast}) async {
    if (_currentCodecItem == null) return false;
    final videoUrl = VideoUtils.getLiveCdnUrl(
      _currentCodecItem,
      lineIndex: currentLineIndex.value,
    );
    if (videoUrl.isEmpty) return false;
    await playerInit(videoUrl);
    SmartDialog.showToast(successToast);
    return true;
  }

  Future<ApiResult<RoomInfoModel>> queryLiveInfo({
    int? qn,
    int? lineIndex,
    String? codec,
  }) async {
    if (isDisposed) {
      return const ApiFailure(
        kind: ApiFailureKind.cancelled,
        message: 'Controller disposed',
      );
    }
    final int preferredQn =
        qn ??
        GStorage.setting.get(SettingBoxKey.defaultLiveQa, defaultValue: 10000);
    final res = await LiveHttp.liveRoomInfo(roomId: roomId, qn: preferredQn);
    if (isDisposed) return res;

    if (res case ApiSuccess<RoomInfoModel>(:final data)) {
      final status = data.liveStatus ?? 0;
      isLive.value = status == 1;

      _updateStreamMetadata(
        data,
        targetQn: preferredQn,
        targetLine: lineIndex,
        targetCodec: codec,
      );

      if (_currentCodecItem != null) {
        final videoUrl = VideoUtils.getLiveCdnUrl(
          _currentCodecItem,
          lineIndex: currentLineIndex.value,
        );
        if (videoUrl.isNotEmpty) {
          hasStream.value = true;
          if (!isClosed) {
            await playerInit(videoUrl);
          }
          return res;
        }
      }
      hasStream.value = false;
    } else {
      isLive.value = false;
      hasStream.value = false;
    }
    return res;
  }

  Future<bool> changeQuality(int targetQn) async {
    if (isDisposed || isSwitchingStream.value) return false;
    if (targetQn == currentQn.value && hasStream.value) return true;

    isSwitchingStream.value = true;
    try {
      final res = await LiveHttp.liveRoomInfo(roomId: roomId, qn: targetQn);
      if (isDisposed) return false;
      if (res case ApiSuccess<RoomInfoModel>(:final data)) {
        _updateStreamMetadata(
          data,
          targetQn: targetQn,
          targetLine: currentLineIndex.value,
          targetCodec: currentCodec.value,
        );
        final success = await _applyLiveStream(
          successToast: '已切换至：${currentQnDesc.value}',
        );
        if (success) {
          GStorage.setting.put(SettingBoxKey.defaultLiveQa, targetQn);
          return true;
        }
      }
      SmartDialog.showToast('切换画质失败，请重试');
      return false;
    } catch (_) {
      SmartDialog.showToast('切换画质失败');
      return false;
    } finally {
      if (!isDisposed) {
        isSwitchingStream.value = false;
      }
    }
  }

  Future<bool> changeCdnLine(int targetIndex) async {
    if (isDisposed || isSwitchingStream.value || _currentCodecItem == null) {
      return false;
    }
    if (targetIndex == currentLineIndex.value) return true;
    final urlInfoList = _currentCodecItem?.urlInfo ?? <UrlInfoItem>[];
    if (targetIndex < 0 || targetIndex >= urlInfoList.length) return false;

    isSwitchingStream.value = true;
    try {
      currentLineIndex.value = targetIndex;
      final success = await _applyLiveStream(
        successToast: '已切换至：线路 ${targetIndex + 1}',
      );
      return success;
    } catch (_) {
      SmartDialog.showToast('切换线路失败');
      return false;
    } finally {
      if (!isDisposed) {
        isSwitchingStream.value = false;
      }
    }
  }

  int _resolveTargetCodecQn(List<CodecItem> codecs, String targetCodec) {
    final item = codecs.firstWhere(
      (c) => (c.codecName ?? '').toLowerCase() == targetCodec.toLowerCase(),
      orElse: () => codecs.first,
    );
    return VideoUtils.resolveSupportedQn(
      acceptQn: item.acceptQn,
      currentQn: currentQn.value,
    );
  }

  Future<bool> _switchCodecWithNetwork({
    required String targetCodec,
    required int supportedQn,
  }) async {
    final res = await LiveHttp.liveRoomInfo(roomId: roomId, qn: supportedQn);
    if (isDisposed) return false;
    if (res case ApiSuccess<RoomInfoModel>(:final data)) {
      _updateStreamMetadata(
        data,
        targetQn: supportedQn,
        targetLine: currentLineIndex.value,
        targetCodec: targetCodec,
      );
      final ok = await _applyLiveStream(
        successToast: '已切换编码：${targetCodec.toUpperCase()}',
      );
      if (ok) GStorage.setting.put(SettingBoxKey.defaultLiveQa, supportedQn);
      return ok;
    }
    return false;
  }

  Future<bool> changeCodec(String targetCodec) async {
    if (isDisposed || isSwitchingStream.value || currentRoomInfo == null) {
      return false;
    }
    if (targetCodec.toLowerCase() == currentCodec.value.toLowerCase()) {
      return true;
    }

    isSwitchingStream.value = true;
    try {
      final playurl = currentRoomInfo?.playurlInfo?.playurl;
      final format = _extractFormat(playurl?.stream ?? <Streams>[]);
      final codecs = format?.codec ?? <CodecItem>[];
      final targetQn = _resolveTargetCodecQn(codecs, targetCodec);
      if (targetQn != currentQn.value) {
        final ok = await _switchCodecWithNetwork(
          targetCodec: targetCodec,
          supportedQn: targetQn,
        );
        if (!ok) SmartDialog.showToast('切换编码失败');
        return ok;
      }
      _updateStreamMetadata(
        currentRoomInfo!,
        targetQn: currentQn.value,
        targetLine: currentLineIndex.value,
        targetCodec: targetCodec,
      );
      return await _applyLiveStream(
        successToast: '已切换编码：${targetCodec.toUpperCase()}',
      );
    } catch (_) {
      SmartDialog.showToast('切换编码失败');
      return false;
    } finally {
      if (!isDisposed) {
        isSwitchingStream.value = false;
      }
    }
  }

  void setVolume(double value) {
    if (value == 0) {
      volumeOff.value = false;
    } else {
      volume = value;
      volumeOff.value = true;
    }
  }

  Future<ApiResult<RoomInfoH5Model>> queryLiveInfoH5() async {
    if (isDisposed) {
      return const ApiFailure(
        kind: ApiFailureKind.cancelled,
        message: 'Controller disposed',
      );
    }
    final res = await LiveHttp.liveRoomInfoH5(roomId: roomId);
    if (isDisposed) return res;
    if (res case ApiSuccess<RoomInfoH5Model>(:final data)) {
      roomInfoH5.value = data;
      final status = data.roomInfo?.liveStatus;
      if (status != null) {
        isLive.value = status == 1;
      }
      final realRoomId = data.roomInfo?.roomId ?? roomId;
      if (realRoomId > 0 && danmakuClient == null) {
        unawaited(initDanmakuClient(realRoomId));
      }
    }
    return res;
  }

  Future<void> initDanmakuClient(int targetRoomId) async {
    if (isDisposed || targetRoomId <= 0) return;
    debugPrint('[LiveDanmaku] initDanmakuClient for roomId=$targetRoomId');

    _danmakuSub?.cancel();
    _danmakuSub = null;
    _popularitySub?.cancel();
    _popularitySub = null;
    danmakuClient?.dispose();

    final dynamic userInfo = GStorage.userInfo.get('userInfoCache');
    final int uid = userInfo?.mid ?? 0;
    final client = LiveDanmakuClient(
      roomId: targetRoomId,
      uid: uid,
      buvid: LoginHttp.buvid,
    );
    danmakuClient = client;

    _danmakuSub = client.onDanmaku.listen((LiveDanmakuItem item) {
      if (isDisposed) return;
      debugPrint(
        '[LiveDanmaku] onDanmaku: "${item.text}", isOpen=${plPlayerController.isOpenDanmu.value}, hasCtr=${plPlayerController.danmakuController != null}',
      );
      if (!plPlayerController.isOpenDanmu.value) return;

      final danmakuCtr = plPlayerController.danmakuController;
      if (danmakuCtr == null) return;

      if (plPlayerController.blockTypes.contains(item.mode)) return;

      danmakuCtr.addDanmaku(
        DanmakuContentItem(
          item.text,
          color: item.color,
          type: DmUtils.getPosition(item.mode),
        ),
      );
    });

    _popularitySub = client.onPopularity.listen((pop) {
      if (!isDisposed) {
        popularity.value = pop;
      }
    });

    final confRes = await LiveHttp.liveDanmakuConf(roomId: targetRoomId);
    debugPrint('[LiveDanmaku] confRes: ${confRes.runtimeType}');
    if (isDisposed || danmakuClient != client) {
      client.dispose();
      return;
    }

    if (confRes case ApiSuccess(:final data)) {
      await client.connect(data);
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    _danmakuSub?.cancel();
    _danmakuSub = null;
    _popularitySub?.cancel();
    _popularitySub = null;
    danmakuClient?.dispose();
    danmakuClient = null;
    unawaited(plPlayerController.releaseNativeResources(playerResourceOwner));
    super.onClose();
  }
}

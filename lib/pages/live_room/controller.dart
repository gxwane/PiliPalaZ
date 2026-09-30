import 'dart:async';
import 'package:get/get.dart';
import 'package:pilipalaz/http/constants.dart';
import 'package:pilipalaz/http/live.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import '../../models/live/room_info_h5.dart';
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
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed || isClosed;

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

  Future<ApiResult<RoomInfoModel>> queryLiveInfo() async {
    if (isDisposed) {
      return const ApiFailure(
        kind: ApiFailureKind.cancelled,
        message: 'Controller disposed',
      );
    }
    final res = await LiveHttp.liveRoomInfo(roomId: roomId, qn: 10000);
    if (isDisposed) return res;

    if (res case ApiSuccess<RoomInfoModel>(:final data)) {
      final status = data.liveStatus ?? 0;
      isLive.value = status == 1;

      final streams = data.playurlInfo?.playurl?.stream;
      if (streams != null && streams.isNotEmpty) {
        final formats = streams.first.format;
        if (formats != null && formats.isNotEmpty) {
          final codecs = formats.first.codec;
          if (codecs != null && codecs.isNotEmpty) {
            final item = codecs.first;
            final videoUrl = VideoUtils.getCdnUrl(item);
            if (videoUrl.isNotEmpty) {
              hasStream.value = true;
              if (!isClosed) {
                await playerInit(videoUrl);
              }
              return res;
            }
          }
        }
      }
      hasStream.value = false;
    } else {
      isLive.value = false;
      hasStream.value = false;
    }
    return res;
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
    }
    return res;
  }

  @override
  void onClose() {
    _isDisposed = true;
    unawaited(plPlayerController.releaseNativeResources(playerResourceOwner));
    super.onClose();
  }
}

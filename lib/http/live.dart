import 'package:dio/dio.dart';

import '../models/live/area.dart';
import '../models/live/danmaku_conf.dart';
import '../models/live/item.dart';
import '../models/live/room_info.dart';
import '../models/live/room_info_h5.dart';
import '../utils/storage.dart';
import 'api.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class LiveHttp {
  static Future<ApiResult<List<LiveItemModel>>> liveList({
    int? vmid,
    int? pn,
    int? ps,
    String? orderType,
  }) {
    return HttpRuntime.instance.client.getJson<List<LiveItemModel>>(
      Api.liveList,
      endpoint: 'live.list',
      queryParameters: <String, dynamic>{
        'page': pn,
        'page_size': ps ?? 30,
        'platform': 'web',
      },
      decode: (json) => BiliApiDecoder.data<List<LiveItemModel>>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final items = data['recommend_room_list'] ?? data['list'] ?? const [];
          return BiliApiDecoder.list(items, field: 'data.list')
              .map(
                (item) => LiveItemModel.fromJson(
                  BiliApiDecoder.object(item, field: 'data.list[]'),
                ),
              )
              .toList(growable: false);
        },
      ),
    );
  }

  static Future<ApiResult<RoomInfoModel>> liveRoomInfo({
    required int roomId,
    int? qn,
    CancelToken? cancelToken,
  }) {
    return HttpRuntime.instance.client.getJson<RoomInfoModel>(
      Api.liveRoomInfo,
      endpoint: 'live.roomPlayInfo',
      cancelToken: cancelToken,
      queryParameters: <String, dynamic>{
        'room_id': roomId,
        'protocol': '0, 1',
        'format': '0, 1, 2',
        'codec': '0, 1',
        'qn': qn,
        'platform': 'web',
        'ptype': 8,
        'dolby': 5,
        'panorama': 1,
      },
      decode: (json) => BiliApiDecoder.data<RoomInfoModel>(
        json,
        decode: (value) =>
            RoomInfoModel.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }

  static Future<ApiResult<RoomInfoH5Model>> liveRoomInfoH5({
    required int roomId,
    CancelToken? cancelToken,
  }) {
    return HttpRuntime.instance.client.getJson<RoomInfoH5Model>(
      Api.liveRoomInfoH5,
      endpoint: 'live.roomInfo',
      cancelToken: cancelToken,
      queryParameters: <String, dynamic>{'room_id': roomId},
      decode: (json) => BiliApiDecoder.data<RoomInfoH5Model>(
        json,
        decode: (value) => RoomInfoH5Model.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<LiveDanmakuConfModel>> liveDanmakuConf({
    required int roomId,
  }) {
    return HttpRuntime.instance.client.getJson<LiveDanmakuConfModel>(
      Api.liveDanmakuConf,
      endpoint: 'live.danmuConf',
      queryParameters: <String, dynamic>{
        'room_id': roomId,
        'platform': 'pc',
        'player': 'web',
      },
      decode: (json) => BiliApiDecoder.data<LiveDanmakuConfModel>(
        json,
        decode: (value) => LiveDanmakuConfModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<void>> sendDanmaku({
    required int roomId,
    required String msg,
    int color = 16777215,
    int fontSize = 25,
    int mode = 1,
  }) async {
    final csrf = await HttpRuntime.instance.getCsrf();
    final rnd = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final data = <String, dynamic>{
      'bubble': 0,
      'msg': msg,
      'color': color,
      'mode': mode,
      'fontsize': fontSize,
      'rnd': rnd,
      'roomid': roomId,
      'csrf': csrf,
      'csrf_token': csrf,
    };
    return HttpRuntime.instance.client.postJson<void>(
      Api.sendLiveDanmaku,
      endpoint: 'live.sendDanmaku',
      data: data,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<List<LiveItemModel>>> followingLiveList({
    int page = 1,
    int pageSize = 30,
    CancelToken? cancelToken,
  }) {
    dynamic userInfo;
    try {
      userInfo = GStorage.userInfo.get('userInfoCache');
    } catch (_) {
      userInfo = null;
    }
    if (userInfo == null) {
      return Future.value(const ApiSuccess<List<LiveItemModel>>([]));
    }
    return HttpRuntime.instance.client.getJson<List<LiveItemModel>>(
      Api.followingLiveList,
      endpoint: 'live.followingList',
      cancelToken: cancelToken,
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'ignoreRecord': 1,
        'hit_ab': true,
      },
      decode: (json) => BiliApiDecoder.data<List<LiveItemModel>>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final items = data['list'] ?? const [];
          return BiliApiDecoder.list(items, field: 'data.list')
              .map(
                (item) => LiveItemModel.fromJson(
                  BiliApiDecoder.object(item, field: 'data.list[]'),
                ),
              )
              .where((item) => (item.roomId ?? 0) > 0 && item.isLive)
              .toList(growable: false);
        },
      ),
    );
  }

  static Future<ApiResult<List<LiveAreaItemModel>>> liveAreaList({
    CancelToken? cancelToken,
  }) {
    return HttpRuntime.instance.client.getJson<List<LiveAreaItemModel>>(
      Api.liveAreaList,
      endpoint: 'live.areaList',
      cancelToken: cancelToken,
      decode: (json) => BiliApiDecoder.data<List<LiveAreaItemModel>>(
        json,
        decode: (value) {
          final list = BiliApiDecoder.list(value, field: 'data');
          final areas = <LiveAreaItemModel>[
            const LiveAreaItemModel(id: 0, name: '推荐'),
          ];
          for (final item in list) {
            final obj = BiliApiDecoder.object(item, field: 'data[]');
            final area = LiveAreaItemModel.fromJson(obj);
            if (area.id > 0 && area.name.isNotEmpty) {
              areas.add(area);
            }
          }
          return areas;
        },
      ),
    );
  }

  static Future<ApiResult<List<LiveItemModel>>> areaLiveList({
    required int parentAreaId,
    int? areaId,
    int? page,
    int? pageSize,
    String? sortType,
    CancelToken? cancelToken,
  }) {
    return HttpRuntime.instance.client.getJson<List<LiveItemModel>>(
      Api.liveAreaItemList,
      endpoint: 'live.areaItemList',
      cancelToken: cancelToken,
      queryParameters: <String, dynamic>{
        'parent_area_id': parentAreaId,
        if (areaId != null && areaId > 0) 'area_id': areaId,
        if (sortType != null && sortType.isNotEmpty) 'sort_type': sortType,
        'page': page ?? 1,
        'page_size': pageSize ?? 30,
        'platform': 'web',
      },
      decode: (json) => BiliApiDecoder.data<List<LiveItemModel>>(
        json,
        decode: (value) {
          final dynamic items = (value is List)
              ? value
              : (value is Map ? (value['list'] ?? const []) : const []);
          return BiliApiDecoder.list(items, field: 'data')
              .map(
                (item) => LiveItemModel.fromJson(
                  BiliApiDecoder.object(item, field: 'data[]'),
                ),
              )
              .toList(growable: false);
        },
      ),
    );
  }
}

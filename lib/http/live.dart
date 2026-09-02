import '../models/live/item.dart';
import '../models/live/room_info.dart';
import '../models/live/room_info_h5.dart';
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
  }) {
    return HttpRuntime.instance.client.getJson<RoomInfoModel>(
      Api.liveRoomInfo,
      endpoint: 'live.roomPlayInfo',
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
  }) {
    return HttpRuntime.instance.client.getJson<RoomInfoH5Model>(
      Api.liveRoomInfoH5,
      endpoint: 'live.roomInfo',
      queryParameters: <String, dynamic>{'room_id': roomId},
      decode: (json) => BiliApiDecoder.data<RoomInfoH5Model>(
        json,
        decode: (value) => RoomInfoH5Model.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }
}

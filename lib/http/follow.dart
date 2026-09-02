import '../models/follow/result.dart';
import 'api.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class FollowHttp {
  static Future<ApiResult<FollowDataModel>> followings({
    int? vmid,
    int? pn,
    int? ps,
    String? orderType,
  }) {
    return HttpRuntime.instance.client.getJson<FollowDataModel>(
      Api.followings,
      endpoint: 'follow.list',
      queryParameters: <String, dynamic>{
        'vmid': vmid,
        'pn': pn,
        'ps': ps,
        'order': 'desc',
        'order_type': orderType,
      }..removeWhere((_, value) => value == null),
      decode: (json) => BiliApiDecoder.data<FollowDataModel>(
        json,
        decode: (value) => FollowDataModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }
}

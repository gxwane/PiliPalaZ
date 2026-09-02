import '../models/fans/result.dart';
import 'api.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class FanHttp {
  static Future<ApiResult<FansDataModel>> fans({
    int? vmid,
    int? pn,
    int? ps,
    String? orderType,
  }) {
    return HttpRuntime.instance.client.getJson<FansDataModel>(
      Api.fans,
      endpoint: 'fan.list',
      queryParameters: <String, dynamic>{
        'vmid': vmid,
        'pn': pn,
        'ps': ps,
        'order': 'desc',
        'order_type': orderType,
      }..removeWhere((_, value) => value == null),
      decode: (json) => BiliApiDecoder.data<FansDataModel>(
        json,
        decode: (value) =>
            FansDataModel.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }
}

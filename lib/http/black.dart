import '../models/user/black.dart';
import 'api.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class BlackHttp {
  static Future<ApiResult<BlackListDataModel>> blackList({
    required int pn,
    int? ps,
  }) async {
    return HttpRuntime.instance.client.getJson<BlackListDataModel>(
      Api.blackLst,
      endpoint: 'black.list',
      queryParameters: <String, dynamic>{
        'pn': pn,
        'ps': ps ?? 50,
        're_version': 0,
        'jsonp': 'jsonp',
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      decode: (json) => BiliApiDecoder.data<BlackListDataModel>(
        json,
        decode: (value) => BlackListDataModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<void>> removeBlack({required int fid}) async {
    return HttpRuntime.instance.client.postJson<void>(
      Api.removeBlack,
      endpoint: 'black.remove',
      queryParameters: <String, dynamic>{
        'act': 6,
        'csrf': await HttpRuntime.instance.getCsrf(),
        'fid': fid,
        'jsonp': 'jsonp',
      },
      decode: (json) => BiliApiDecoder.success(json),
    );
  }
}

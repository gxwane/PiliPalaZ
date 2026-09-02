import '../models/user/danmaku_block.dart';
import 'api.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class DanmakuFilterHttp {
  static Future<ApiResult<DanmakuBlockDataModel>> danmakuFilter() {
    return HttpRuntime.instance.client.getJson<DanmakuBlockDataModel>(
      Api.danmakuFilter,
      endpoint: 'danmakuFilter.list',
      decode: (json) => BiliApiDecoder.data<DanmakuBlockDataModel>(
        json,
        decode: (value) => DanmakuBlockDataModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<void>> danmakuFilterDel({required int ids}) async {
    return HttpRuntime.instance.client.postJson<void>(
      Api.danmakuFilterDel,
      endpoint: 'danmakuFilter.delete',
      queryParameters: <String, dynamic>{
        'ids': ids,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      decode: (json) => BiliApiDecoder.success(json),
    );
  }

  static Future<ApiResult<Rule>> danmakuFilterAdd({
    required String filter,
    required int type,
  }) async {
    return HttpRuntime.instance.client.postJson<Rule>(
      Api.danmakuFilterAdd,
      endpoint: 'danmakuFilter.add',
      queryParameters: <String, dynamic>{
        'type': type,
        'filter': filter,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      decode: (json) => BiliApiDecoder.data<Rule>(
        json,
        decode: (value) =>
            Rule.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }
}

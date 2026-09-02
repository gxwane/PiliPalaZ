import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class CommonHttp {
  static Future<ApiResult<List<JsonObject>>> unReadDynamic() {
    return HttpRuntime.instance.client.getJson<List<JsonObject>>(
      Api.getUnreadDynamic,
      endpoint: 'dynamic.unread',
      queryParameters: const <String, dynamic>{
        'alltype_offset': 0,
        'video_offset': '',
        'article_offset': 0,
      },
      decode: (json) => BiliApiDecoder.data<List<JsonObject>>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          return BiliApiDecoder.list(
                data['dyn_basic_infos'],
                field: 'data.dyn_basic_infos',
              )
              .map(
                (item) => BiliApiDecoder.object(
                  item,
                  field: 'data.dyn_basic_infos[]',
                ),
              )
              .toList(growable: false);
        },
      ),
    );
  }
}

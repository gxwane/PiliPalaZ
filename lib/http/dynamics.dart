import '../models/dynamics/result.dart';
import '../models/dynamics/up.dart';
import '../utils/wbi_sign.dart';
import 'api.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class DynamicsHttp {
  static Future<ApiResult<DynamicsDataModel>> followDynamic({
    String? type,
    String? offset,
    int? mid,
  }) async {
    final data = <String, dynamic>{
      'type': type ?? 'all',
      'timezone_offset': '-480',
      'offset': offset,
      'features': 'itemOpusStyle',
    };
    if (mid != -1) {
      data['host_mid'] = mid;
      data.remove('timezone_offset');
    }
    if (type == 'pgc') {
      data.remove('offset');
    }

    late final Map<String, dynamic> parameters;
    if (type == 'pgc') {
      parameters = data;
    } else {
      final signed = await WbiSign().sign(data);
      if (signed case ApiFailure<Map<String, dynamic>> failure) {
        return failure.cast<DynamicsDataModel>();
      }
      parameters = (signed as ApiSuccess<Map<String, dynamic>>).data;
    }

    final result = await HttpRuntime.instance.client.getJson<DynamicsDataModel>(
      Api.followDynamic,
      endpoint: 'dynamic.feed',
      queryParameters: parameters,
      decode: (json) => BiliApiDecoder.data<DynamicsDataModel>(
        json,
        decode: (value) => DynamicsDataModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
    if (result case ApiFailure<DynamicsDataModel>(
      apiCode: 4101132,
    ) when type == 'pgc') {
      return const ApiFailure<DynamicsDataModel>(
        kind: ApiFailureKind.apiRejected,
        message: '当前账号无法访问番剧动态，可能被平台限制',
        endpoint: 'dynamic.feed',
        apiCode: 4101132,
      );
    }
    return result;
  }

  static Future<ApiResult<FollowUpModel>> followUp() {
    return HttpRuntime.instance.client.getJson<FollowUpModel>(
      Api.followUp,
      endpoint: 'dynamic.followUp',
      decode: (json) => BiliApiDecoder.data<FollowUpModel>(
        json,
        decode: (value) =>
            FollowUpModel.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }

  static Future<ApiResult<void>> likeDynamic({
    required String? dynamicId,
    required int? up,
  }) async {
    return HttpRuntime.instance.client.postJson<void>(
      Api.likeDynamic,
      endpoint: 'dynamic.like',
      queryParameters: <String, dynamic>{
        'dynamic_id': dynamicId,
        'up': up,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      decode: (json) => BiliApiDecoder.success(json),
    );
  }

  static Future<ApiResult<DynamicItemModel>> dynamicDetail({String? id}) {
    return HttpRuntime.instance.client.getJson<DynamicItemModel>(
      Api.dynamicDetail,
      endpoint: 'dynamic.detail',
      queryParameters: <String, dynamic>{
        'timezone_offset': -480,
        'id': id,
        'features': 'itemOpusStyle',
      },
      decode: (json) => BiliApiDecoder.data<DynamicItemModel>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          return DynamicItemModel.fromJson(
            BiliApiDecoder.object(data['item'], field: 'data.item'),
          );
        },
      ),
    );
  }
}

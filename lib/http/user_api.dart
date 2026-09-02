import '../models/user/stat.dart';
import '../utils/storage.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

final class UserApi {
  UserApi({ApiClient? client})
    : _client = client ?? HttpRuntime.instance.client;

  static UserApi? _instance;

  static UserApi get instance => _instance ??= UserApi();

  final ApiClient _client;

  Future<ApiResult<UserStat>> stat({required int mid}) {
    return _client.getJson<UserStat>(
      Api.userStat,
      endpoint: 'user.stat',
      queryParameters: <String, dynamic>{
        'access_key': GStorage.localCache.get(
          LocalCacheKey.accessKey,
          defaultValue: <String, dynamic>{},
        )['value'],
        'vmid': mid,
      },
      decode: (json) => BiliApiDecoder.data<UserStat>(
        json,
        decode: (value) =>
            UserStat.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }
}

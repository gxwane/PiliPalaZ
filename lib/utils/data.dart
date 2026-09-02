import 'package:hive/hive.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';

import 'storage.dart';

class Data {
  static Future init() async {
    await historyStatus();
  }

  static Future historyStatus() async {
    Box localCache = GStorage.localCache;
    Box userInfoCache = GStorage.userInfo;
    if (userInfoCache.get('userInfoCache') == null) {
      return;
    }
    var res = await UserHttp.historyStatus();
    if (res case ApiSuccess<bool>(:final data)) {
      localCache.put(LocalCacheKey.historyPause, data);
    }
  }
}

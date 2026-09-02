import '../models/model_hot_video_item.dart';
import '../models/user/fav_detail.dart';
import '../models/user/fav_folder.dart';
import '../models/user/history.dart';
import '../models/user/info.dart';
import '../models/user/stat.dart';
import '../models/user/sub_detail.dart';
import '../models/user/sub_folder.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

final class WatchLaterData {
  const WatchLaterData({required this.items, required this.count});

  final List<HotVideoItemModel> items;
  final int count;
}

class UserHttp {
  static Future<ApiResult<UserInfoData>> userInfo() {
    return _getData<UserInfoData>(
      Api.userInfo,
      'user.info',
      UserInfoData.fromJson,
    );
  }

  static Future<ApiResult<UserStat>> userStatOwner() {
    return _getData<UserStat>(
      Api.userStatOwner,
      'user.statOwner',
      UserStat.fromJson,
    );
  }

  static Future<ApiResult<FavFolderData>> userfavFolder({
    required int pn,
    required int ps,
    required int mid,
  }) {
    return _getData<FavFolderData>(
      Api.userFavFolder,
      'favorite.folders',
      FavFolderData.fromJson,
      queryParameters: <String, dynamic>{'pn': pn, 'ps': ps, 'up_mid': mid},
    );
  }

  static Future<ApiResult<FavDetailData>> userFavFolderDetail({
    required int mediaId,
    required int pn,
    required int ps,
    String keyword = '',
    String order = 'mtime',
    int type = 0,
  }) {
    return _getData<FavDetailData>(
      Api.userFavFolderDetail,
      'favorite.detail',
      FavDetailData.fromJson,
      queryParameters: <String, dynamic>{
        'media_id': mediaId,
        'pn': pn,
        'ps': ps,
        'keyword': keyword,
        'order': order,
        'type': type,
        'tid': 0,
        'platform': 'web',
      },
    );
  }

  static Future<ApiResult<WatchLaterData>> seeYouLater() {
    return HttpRuntime.instance.client.getJson<WatchLaterData>(
      Api.seeYouLater,
      endpoint: 'watchLater.list',
      decode: (json) => BiliApiDecoder.data<WatchLaterData>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final count = BiliApiDecoder.integer(
            data['count'],
            field: 'data.count',
          );
          final items = count == 0
              ? <HotVideoItemModel>[]
              : BiliApiDecoder.list(data['list'], field: 'data.list')
                    .map(
                      (item) => HotVideoItemModel.fromJson(
                        BiliApiDecoder.object(item, field: 'data.list[]'),
                      ),
                    )
                    .toList(growable: false);
          return WatchLaterData(items: items, count: count);
        },
      ),
    );
  }

  static Future<ApiResult<HistoryData>> historyList(int? max, int? viewAt) {
    return _getData<HistoryData>(
      Api.historyList,
      'history.list',
      HistoryData.fromJson,
      queryParameters: <String, dynamic>{
        'type': 'all',
        'ps': 20,
        'max': max ?? 0,
        'view_at': viewAt ?? 0,
      },
    );
  }

  static Future<ApiResult<void>> pauseHistory(bool paused) async {
    return _postSuccess(Api.pauseHistory, 'history.pause', <String, dynamic>{
      'switch': paused,
      'jsonp': 'jsonp',
      'csrf': await HttpRuntime.instance.getCsrf(),
    });
  }

  static Future<ApiResult<bool>> historyStatus() {
    return HttpRuntime.instance.client.getJson<bool>(
      Api.historyStatus,
      endpoint: 'history.status',
      decode: (json) => BiliApiDecoder.data<bool>(
        json,
        decode: (value) {
          if (value is bool) {
            return value;
          }
          throw const MalformedApiResponseException('data 字段不是布尔值');
        },
      ),
    );
  }

  static Future<ApiResult<void>> clearHistory() async {
    return _postSuccess(Api.clearHistory, 'history.clear', <String, dynamic>{
      'jsonp': 'jsonp',
      'csrf': await HttpRuntime.instance.getCsrf(),
    });
  }

  static Future<ApiResult<void>> toViewLater({String? bvid, int? aid}) async {
    return _postSuccess(Api.toViewLater, 'watchLater.add', <String, dynamic>{
      'csrf': await HttpRuntime.instance.getCsrf(),
      if (bvid != null) 'bvid': bvid,
      if (bvid == null && aid != null) 'aid': aid,
    });
  }

  static Future<ApiResult<void>> toViewDel({int? aid}) async {
    return _postSuccess(Api.toViewDel, 'watchLater.remove', <String, dynamic>{
      'jsonp': 'jsonp',
      'csrf': await HttpRuntime.instance.getCsrf(),
      aid != null ? 'aid' : 'viewed': aid ?? true,
    });
  }

  static Future<ApiResult<void>> toViewClear() async {
    return _postSuccess(Api.toViewClear, 'watchLater.clear', <String, dynamic>{
      'jsonp': 'jsonp',
      'csrf': await HttpRuntime.instance.getCsrf(),
    });
  }

  static Future<ApiResult<void>> delHistory(String kid) async {
    return _postSuccess(Api.delHistory, 'history.delete', <String, dynamic>{
      'kid': kid,
      'jsonp': 'jsonp',
      'csrf': await HttpRuntime.instance.getCsrf(),
    });
  }

  static Future<ApiResult<HistoryData>> searchHistory({
    required int pn,
    required String keyword,
  }) {
    return _getData<HistoryData>(
      Api.searchHistory,
      'history.search',
      HistoryData.fromJson,
      queryParameters: <String, dynamic>{
        'pn': pn,
        'keyword': keyword,
        'business': 'all',
      },
    );
  }

  static Future<ApiResult<SubFolderModelData>> userSubFolder({
    required int mid,
    required int pn,
    required int ps,
  }) {
    return _getData<SubFolderModelData>(
      Api.userSubFolder,
      'subscription.folders',
      SubFolderModelData.fromJson,
      queryParameters: <String, dynamic>{
        'up_mid': mid,
        'ps': ps,
        'pn': pn,
        'platform': 'web',
      },
    );
  }

  static Future<ApiResult<SubDetailModelData>> favSeasonList({
    required int id,
    required int pn,
    required int ps,
  }) {
    return _getData<SubDetailModelData>(
      Api.favSeasonList,
      'subscription.seasonDetail',
      SubDetailModelData.fromJson,
      queryParameters: <String, dynamic>{'season_id': id, 'ps': ps, 'pn': pn},
    );
  }

  static Future<ApiResult<SubDetailModelData>> favResourceList({
    required int id,
    required int pn,
    required int ps,
  }) {
    return _getData<SubDetailModelData>(
      Api.favResourceList,
      'subscription.resourceDetail',
      SubDetailModelData.fromJson,
      queryParameters: <String, dynamic>{'media_id': id, 'ps': ps, 'pn': pn},
    );
  }

  static Future<ApiResult<void>> cancelSub({
    required int id,
    required int type,
  }) async {
    final season = type != 11;
    return _postSuccess(
      season ? Api.unfavSeason : Api.unfavFolder,
      season
          ? 'subscription.unfavoriteSeason'
          : 'subscription.unfavoriteFolder',
      <String, dynamic>{
        if (season) 'platform': 'web',
        season ? 'season_id' : 'media_id': id,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
    );
  }

  static Future<ApiResult<T>> _getData<T>(
    String url,
    String endpoint,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) {
    return HttpRuntime.instance.client.getJson<T>(
      url,
      endpoint: endpoint,
      queryParameters: queryParameters,
      decode: (json) => BiliApiDecoder.data<T>(
        json,
        decode: (value) =>
            fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }

  static Future<ApiResult<void>> _postSuccess(
    String url,
    String endpoint,
    Map<String, dynamic> queryParameters,
  ) {
    return HttpRuntime.instance.client.postJson<void>(
      url,
      endpoint: endpoint,
      queryParameters: queryParameters,
      decode: (json) => BiliApiDecoder.success(json),
    );
  }
}

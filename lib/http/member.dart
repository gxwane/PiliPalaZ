import 'package:dio/dio.dart';

import '../common/constants.dart';
import '../models/dynamics/result.dart';
import '../models/follow/result.dart';
import '../models/member/archive.dart';
import '../models/member/coin.dart';
import '../models/member/info.dart';
import '../models/member/seasons.dart';
import '../models/member/tags.dart';
import '../utils/storage.dart';
import '../utils/utils.dart';
import '../utils/wbi_sign.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

abstract final class MemberHttp {
  static ApiClient get _client => HttpRuntime.instance.client;

  static Future<ApiResult<MemberInfoModel>> memberInfo({int? mid}) async {
    final accessKey =
        GStorage.localCache.get(
              LocalCacheKey.accessKey,
              defaultValue: <String, Object?>{},
            )['value']
            as String?;
    final parameters = <String, String>{
      if (accessKey?.isNotEmpty == true) 'access_key': accessKey!,
      'appkey': Constants.appKey,
      'build': '1462100',
      'c_locale': 'zh_CN',
      'channel': 'yingyongbao',
      'mobi_app': 'android_hd',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statistics,
      'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'vmid': mid.toString(),
    };
    parameters['sign'] = Utils.appSign(
      parameters,
      Constants.appKey,
      Constants.appSec,
    );
    final currentMid = GStorage.userInfo.get('userInfoCache')?.mid;
    return _client.getJson<MemberInfoModel>(
      Api.memberInfo,
      queryParameters: parameters,
      options: Options(
        headers: <String, Object?>{
          'env': 'prod',
          'app-key': 'android_hd',
          'x-bili-mid': currentMid,
          'bili-http-engine': 'cronet',
          'user-agent': Constants.userAgent,
        },
      ),
      endpoint: 'member.info',
      decode: (json) => _data<MemberInfoModel>(
        json,
        decode: (value) => MemberInfoModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<MemberArchiveDataModel>> memberArchive({
    int? mid,
    int ps = 40,
    int tid = 0,
    int? pn,
    String? keyword,
    String order = 'pubdate',
    bool orderAvoided = true,
  }) async {
    final dmImage = Utils.base64EncodeRandomString(16, 64);
    final dmCover = Utils.base64EncodeRandomString(32, 128);
    return _getSigned<MemberArchiveDataModel>(
      Api.memberArchive,
      endpoint: 'member.archive',
      parameters: <String, dynamic>{
        'mid': mid,
        'ps': ps,
        'tid': tid,
        'pn': pn,
        'keyword': keyword ?? '',
        'order': order,
        'platform': 'web',
        'web_location': 1550101,
        'order_avoided': orderAvoided,
        'dm_img_list': '[]',
        'dm_img_str': dmImage.substring(0, dmImage.length - 2),
        'dm_cover_img_str': dmCover.substring(0, dmCover.length - 2),
        'dm_img_inter': '{"ds":[],"wh":[0,0,0],"of":[0,0,0]}',
      },
      decode: (value) => MemberArchiveDataModel.fromJson(
        BiliApiDecoder.object(value, field: 'data'),
      ),
    );
  }

  static Future<ApiResult<DynamicsDataModel>> memberDynamic({
    String? offset,
    int? mid,
  }) {
    return _client.getJson<DynamicsDataModel>(
      Api.memberDynamic,
      queryParameters: <String, dynamic>{
        'offset': offset ?? '',
        'host_mid': mid,
        'timezone_offset': '-480',
        'features': 'itemOpusStyle',
      },
      endpoint: 'member.dynamic',
      decode: (json) => _data<DynamicsDataModel>(
        json,
        decode: (value) => DynamicsDataModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<List<MemberTagItemModel>>> followUpTags() {
    return _client.getJson<List<MemberTagItemModel>>(
      Api.followUpTag,
      endpoint: 'member.followTags',
      decode: (json) => _data<List<MemberTagItemModel>>(
        json,
        decode: (value) =>
            BiliApiDecoder.list(value, field: 'data').map((item) {
              return MemberTagItemModel.fromJson(
                BiliApiDecoder.object(item, field: 'data[]'),
              );
            }).toList(),
      ),
    );
  }

  static Future<ApiResult<void>> addUsers(int? fids, String? tagids) async {
    return _client.postJson<void>(
      Api.addUsers,
      queryParameters: <String, dynamic>{
        'fids': fids,
        'tagids': tagids ?? '0',
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      data: const <String, Object?>{'cross_domain': true},
      endpoint: 'member.setFollowTags',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<List<FollowItemModel>>> followUpGroup(
    int? mid,
    int? tagid,
    int? pn,
    int? ps,
  ) {
    return _client.getJson<List<FollowItemModel>>(
      Api.followUpGroup,
      queryParameters: <String, dynamic>{
        'mid': mid,
        'tagid': tagid,
        'pn': pn,
        'ps': ps,
      },
      endpoint: 'member.followGroup',
      decode: (json) => _data<List<FollowItemModel>>(
        json,
        decode: (value) =>
            BiliApiDecoder.list(value, field: 'data').map((item) {
              return FollowItemModel.fromJson(
                BiliApiDecoder.object(item, field: 'data[]'),
              );
            }).toList(),
      ),
    );
  }

  static Future<ApiResult<MemberSeasonsAndSeriesDataModel>>
  getMemberSeasonsAndSeries(int? mid, int? pn, int? ps) {
    return _getSigned<MemberSeasonsAndSeriesDataModel>(
      Api.getMemberSeasonsAndSeriesApi,
      endpoint: 'member.seasonsAndSeries',
      parameters: <String, dynamic>{
        'mid': mid,
        'page_num': pn,
        'page_size': ps,
        'web_location': '333.999',
      },
      decode: (value) {
        final data = BiliApiDecoder.object(value, field: 'data');
        return MemberSeasonsAndSeriesDataModel.fromJson(
          BiliApiDecoder.object(data['items_lists'], field: 'data.items_lists'),
        );
      },
    );
  }

  static Future<ApiResult<List<MemberCoinsDataModel>>> getRecentCoinVideo({
    required int mid,
  }) {
    return _getSigned<List<MemberCoinsDataModel>>(
      Api.getRecentCoinVideoApi,
      endpoint: 'member.recentCoins',
      parameters: <String, dynamic>{
        'vmid': mid,
        'gaia_source': 'main_web',
        'web_location': 333.999,
      },
      decode: (value) => BiliApiDecoder.list(value, field: 'data').map((item) {
        return MemberCoinsDataModel.fromJson(
          BiliApiDecoder.object(item, field: 'data[]'),
        );
      }).toList(),
    );
  }

  static Future<ApiResult<MemberSeasonsList>> getSeasonDetail({
    required int mid,
    required int seasonId,
    bool sortReverse = false,
    required int pn,
    required int ps,
  }) {
    return _client.getJson<MemberSeasonsList>(
      Api.getSeasonDetailApi,
      queryParameters: <String, dynamic>{
        'mid': mid,
        'season_id': seasonId,
        'sort_reverse': sortReverse,
        'page_num': pn,
        'page_size': ps,
      },
      endpoint: 'member.seasonDetail',
      decode: (json) => _data<MemberSeasonsList>(
        json,
        decode: (value) => MemberSeasonsList.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<MemberSeriesList>> getSeriesDetail({
    required int mid,
    required int seriesId,
    bool sortReverse = false,
    required int pn,
    required int ps,
  }) {
    final currentMid = GStorage.userInfo.get('userInfoCache')?.mid;
    return _client.getJson<MemberSeriesList>(
      Api.getSeriesDetailApi,
      queryParameters: <String, dynamic>{
        'mid': mid,
        'series_id': seriesId,
        'sort': sortReverse ? 'desc' : 'asc',
        'pn': pn,
        'ps': ps,
        if (currentMid != null) 'current_mid': currentMid,
      },
      endpoint: 'member.seriesDetail',
      decode: (json) => _data<MemberSeriesList>(
        json,
        decode: (value) => MemberSeriesList.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<FollowDataModel>> getfollowSearch({
    required int mid,
    required int ps,
    required int pn,
    required String name,
  }) {
    return _getSigned<FollowDataModel>(
      Api.followSearch,
      endpoint: 'member.followSearch',
      parameters: <String, dynamic>{
        'vmid': mid,
        'pn': pn,
        'ps': ps,
        'order': 'desc',
        'order_type': 'attention',
        'gaia_source': 'main_web',
        'name': name,
        'web_location': 333.999,
      },
      decode: (value) =>
          FollowDataModel.fromJson(BiliApiDecoder.object(value, field: 'data')),
    );
  }

  static Future<ApiResult<T>> _getSigned<T>(
    String url, {
    required String endpoint,
    required Map<String, dynamic> parameters,
    required T Function(Object? value) decode,
  }) async {
    final signed = await WbiSign().sign(parameters);
    if (signed case ApiFailure<Map<String, dynamic>> failure) {
      return failure.cast<T>();
    }
    return _client.getJson<T>(
      url,
      queryParameters: (signed as ApiSuccess<Map<String, dynamic>>).data,
      endpoint: endpoint,
      decode: (json) => _data<T>(json, decode: decode),
    );
  }

  static T _data<T>(
    JsonObject json, {
    required T Function(Object? value) decode,
  }) {
    try {
      return BiliApiDecoder.data<T>(json, decode: decode);
    } on ApiRejectedException catch (error) {
      if (error.code == -352) {
        throw const ApiRejectedException(code: -352, message: '风控校验失败，请检查登录状态');
      }
      rethrow;
    }
  }
}

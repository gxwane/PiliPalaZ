import '../models/bangumi/info.dart';
import '../models/bangumi/list.dart';
import '../models/common/pgc_type.dart';
import '../models/video/play/url.dart';
import '../pages/mine/controller.dart';
import '../utils/storage.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

final class PgcInfoBundle {
  const PgcInfoBundle({required this.detail, this.followStatusFailure});

  final BangumiInfoModel detail;
  final ApiFailure<UserStatus>? followStatusFailure;
}

final class PgcApi {
  PgcApi({ApiClient? client}) : _client = client ?? HttpRuntime.instance.client;

  static PgcApi? _instance;

  static PgcApi get instance => _instance ??= PgcApi();

  final ApiClient _client;

  Future<ApiResult<BangumiListDataModel>> catalog({
    required PgcCatalogType type,
    required PgcCatalogOrder order,
    required int page,
  }) {
    return _client.getJson<BangumiListDataModel>(
      Api.pgcCatalog,
      endpoint: 'pgc.catalog',
      queryParameters: <String, dynamic>{
        'st': 1,
        'order': order.apiValue,
        'season_version': -1,
        'spoken_language_type': -1,
        'area': -1,
        'is_finish': -1,
        'copyright': -1,
        'season_status': -1,
        'season_month': -1,
        'year': -1,
        'style_id': -1,
        'sort': 0,
        'page': page,
        'season_type': type.apiValue,
        'pagesize': 20,
        'type': 1,
      },
      decode: (json) => BiliApiDecoder.data<BangumiListDataModel>(
        json,
        decode: (value) => BangumiListDataModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  Future<ApiResult<BangumiListDataModel>> follow({
    required int mid,
    required PgcFollowGroup group,
  }) {
    return _client.getJson<BangumiListDataModel>(
      Api.pgcFollow,
      endpoint: 'pgc.follow',
      queryParameters: <String, dynamic>{
        'type': group.apiValue,
        'follow_status': 0,
        'pn': 1,
        'ps': 15,
        'vmid': mid,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
      decode: (json) => BiliApiDecoder.data<BangumiListDataModel>(
        json,
        decode: (value) => BangumiListDataModel.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  Future<ApiResult<BangumiInfoModel>> info({int? seasonId, int? epId}) {
    if (seasonId == null && epId == null) {
      return Future<ApiResult<BangumiInfoModel>>.value(
        const ApiFailure<BangumiInfoModel>(
          kind: ApiFailureKind.apiRejected,
          message: '缺少影视剧集信息',
          endpoint: 'pgc.info',
        ),
      );
    }
    return _client.getJson<BangumiInfoModel>(
      Api.bangumiInfo,
      endpoint: 'pgc.info',
      queryParameters: <String, dynamic>{
        if (seasonId != null) 'season_id': seasonId,
        if (epId != null) 'ep_id': epId,
      },
      decode: (json) => BiliApiDecoder.result<BangumiInfoModel>(
        json,
        decode: (value) => BangumiInfoModel.fromJson(
          BiliApiDecoder.object(value, field: 'result'),
        ),
      ),
    );
  }

  Future<ApiResult<UserStatus>> followStatus({required int seasonId}) {
    if (GStorage.userInfo.get('userInfoCache') == null ||
        MineController.anonymity) {
      return Future<ApiResult<UserStatus>>.value(
        const ApiFailure<UserStatus>(
          kind: ApiFailureKind.apiRejected,
          message: '账号追剧状态暂不可用',
          endpoint: 'pgc.followStatus',
        ),
      );
    }
    return _client.getJson<UserStatus>(
      Api.pgcFollowStatus,
      endpoint: 'pgc.followStatus',
      queryParameters: <String, dynamic>{'season_id': seasonId},
      decode: (json) => BiliApiDecoder.result<UserStatus>(
        json,
        decode: (value) =>
            UserStatus.fromJson(BiliApiDecoder.object(value, field: 'result')),
      ),
    );
  }

  Future<ApiResult<PgcInfoBundle>> infoWithFollowStatus({
    int? seasonId,
    int? epId,
  }) async {
    final shouldResolve =
        GStorage.userInfo.get('userInfoCache') != null &&
        !MineController.anonymity;
    final pendingStatus = shouldResolve && seasonId != null
        ? followStatus(seasonId: seasonId)
        : null;
    final infoResult = await info(seasonId: seasonId, epId: epId);
    if (infoResult case final ApiFailure<BangumiInfoModel> failure) {
      return failure.cast<PgcInfoBundle>();
    }

    final infoSuccess = infoResult as ApiSuccess<BangumiInfoModel>;
    final detail = infoSuccess.data;
    if (!shouldResolve) {
      return ApiSuccess<PgcInfoBundle>(
        PgcInfoBundle(detail: detail),
        statusCode: infoSuccess.statusCode,
      );
    }

    final resolvedSeasonId = detail.seasonId ?? seasonId;
    if (resolvedSeasonId == null) {
      return ApiSuccess<PgcInfoBundle>(
        PgcInfoBundle(
          detail: detail,
          followStatusFailure: const ApiFailure<UserStatus>(
            kind: ApiFailureKind.malformedResponse,
            message: '缺少影视季度信息',
            endpoint: 'pgc.followStatus',
          ),
        ),
        statusCode: infoSuccess.statusCode,
      );
    }

    final statusResult =
        await (pendingStatus ?? followStatus(seasonId: resolvedSeasonId));
    ApiFailure<UserStatus>? statusFailure;
    if (statusResult case ApiSuccess<UserStatus>(:final data)) {
      detail.applyFollowStatus(data);
    } else {
      statusFailure = statusResult as ApiFailure<UserStatus>;
    }
    return ApiSuccess<PgcInfoBundle>(
      PgcInfoBundle(detail: detail, followStatusFailure: statusFailure),
      statusCode: infoSuccess.statusCode,
    );
  }

  Future<ApiResult<PlayUrlModel>> playUrl({
    required int epId,
    int? cid,
    int? qn,
  }) {
    final data = <String, dynamic>{
      'ep_id': epId,
      if (cid != null) 'cid': cid,
      'qn': qn ?? 80,
      'fnval': 4048,
      'fourk': 1,
    };
    if ((GStorage.userInfo.get('userInfoCache') == null ||
            MineController.anonymity) &&
        GStorage.setting.get(SettingBoxKey.p1080, defaultValue: true)) {
      data['try_look'] = 1;
    }
    return _client.getJson<PlayUrlModel>(
      Api.bangumiVideoUrl,
      endpoint: 'pgc.playUrl',
      queryParameters: data,
      decode: (json) => BiliApiDecoder.result<PlayUrlModel>(
        json,
        decode: (value) => PlayUrlModel.fromJson(
          BiliApiDecoder.object(value, field: 'result'),
        ),
      ),
    );
  }
}

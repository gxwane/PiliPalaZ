import 'package:hive/hive.dart';

import '../models/bangumi/info.dart';
import '../models/bangumi/list.dart';
import '../models/common/pgc_type.dart';
import '../models/video/play/url.dart';
import '../pages/mine/controller.dart';
import '../utils/storage.dart';
import 'index.dart';

class PgcHttp {
  static Box setting = GStorage.setting;
  static Box userInfoCache = GStorage.userInfo;

  static Future<Map<String, dynamic>> catalog({
    required PgcCatalogType type,
    required PgcCatalogOrder order,
    required int page,
  }) async {
    try {
      final dynamic res = await Request().get(
        Api.pgcCatalog,
        data: <String, dynamic>{
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
      );
      if (res.data['code'] == 0) {
        return <String, dynamic>{
          'status': true,
          'data': BangumiListDataModel.fromJson(res.data['data']),
        };
      }
      return _failure(res.data);
    } catch (error) {
      return _failure(<String, dynamic>{'message': error.toString()});
    }
  }

  static Future<Map<String, dynamic>> follow({
    required int mid,
    required PgcFollowGroup group,
  }) async {
    try {
      final dynamic res = await Request().get(
        Api.pgcFollow,
        data: <String, dynamic>{
          'type': group.apiValue,
          'follow_status': 0,
          'pn': 1,
          'ps': 15,
          'vmid': mid,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (res.data['code'] == 0) {
        return <String, dynamic>{
          'status': true,
          'data': BangumiListDataModel.fromJson(res.data['data']),
        };
      }
      return _failure(res.data);
    } catch (error) {
      return _failure(<String, dynamic>{'message': error.toString()});
    }
  }

  static Future<Map<String, dynamic>> info({int? seasonId, int? epId}) async {
    if (seasonId == null && epId == null) {
      return _failure(<String, dynamic>{'message': '缺少影视剧集信息'});
    }
    try {
      final dynamic res = await Request().get(
        Api.bangumiInfo,
        data: <String, dynamic>{
          if (seasonId != null) 'season_id': seasonId,
          if (epId != null) 'ep_id': epId,
        },
      );
      if (res.data['code'] == 0) {
        return <String, dynamic>{
          'status': true,
          'data': BangumiInfoModel.fromJson(res.data['result']),
        };
      }
      return _failure(res.data);
    } catch (error) {
      return _failure(<String, dynamic>{'message': error.toString()});
    }
  }

  static Future<Map<String, dynamic>> followStatus({
    required int seasonId,
  }) async {
    if (userInfoCache.get('userInfoCache') == null ||
        MineController.anonymity) {
      return _failure(<String, dynamic>{'message': '账号追剧状态暂不可用'});
    }
    try {
      final dynamic res = await Request().get(
        Api.pgcFollowStatus,
        data: <String, dynamic>{'season_id': seasonId},
      );
      final dynamic rawStatus = res.data['result'];
      if (res.data['code'] == 0 && rawStatus is Map) {
        return <String, dynamic>{
          'status': true,
          'data': UserStatus.fromJson(Map<String, dynamic>.from(rawStatus)),
        };
      }
      return _failure(res.data);
    } catch (error) {
      return _failure(<String, dynamic>{'message': error.toString()});
    }
  }

  static Future<Map<String, dynamic>> infoWithFollowStatus({
    int? seasonId,
    int? epId,
  }) async {
    final bool shouldResolve =
        userInfoCache.get('userInfoCache') != null && !MineController.anonymity;
    final Future<Map<String, dynamic>>? statusFuture =
        shouldResolve && seasonId != null
        ? followStatus(seasonId: seasonId)
        : null;
    final Map<String, dynamic> infoResult = await info(
      seasonId: seasonId,
      epId: epId,
    );
    if (infoResult['status'] != true || !shouldResolve) return infoResult;

    final BangumiInfoModel detail = infoResult['data'] as BangumiInfoModel;
    final int? resolvedSeasonId = detail.seasonId ?? seasonId;
    if (resolvedSeasonId == null) {
      infoResult['followStatusError'] = '缺少影视季度信息';
      return infoResult;
    }
    final Map<String, dynamic> statusResult =
        await (statusFuture ?? followStatus(seasonId: resolvedSeasonId));
    if (statusResult['status'] == true) {
      detail.applyFollowStatus(statusResult['data'] as UserStatus);
    } else {
      infoResult['followStatusError'] =
          statusResult['msg']?.toString() ?? '追剧状态同步失败';
    }
    return infoResult;
  }

  static Future<Map<String, dynamic>> playUrl({
    required int epId,
    int? cid,
    int? qn,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'ep_id': epId,
      if (cid != null) 'cid': cid,
      'qn': qn ?? 80,
      'fnval': 4048,
      'fourk': 1,
    };
    if ((userInfoCache.get('userInfoCache') == null ||
            MineController.anonymity) &&
        setting.get(SettingBoxKey.p1080, defaultValue: true)) {
      data['try_look'] = 1;
    }

    try {
      final dynamic res = await Request().get(Api.bangumiVideoUrl, data: data);
      if (res.data['code'] == 0 && res.data['result'] != null) {
        return <String, dynamic>{
          'status': true,
          'data': PlayUrlModel.fromJson(res.data['result']),
        };
      }
      return <String, dynamic>{..._failure(res.data), 'code': res.data['code']};
    } catch (error) {
      return _failure(<String, dynamic>{'message': error.toString()});
    }
  }

  static Map<String, dynamic> _failure(Map data) => <String, dynamic>{
    'status': false,
    'data': <dynamic>[],
    'msg': data['message']?.toString() ?? '请求失败',
  };
}

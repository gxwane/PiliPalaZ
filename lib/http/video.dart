import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../common/constants.dart';
import '../models/common/reply_type.dart';
import '../models/home/rcmd/result.dart';
import '../models/model_hot_video_item.dart';
import '../models/model_rec_video_item.dart';
import '../models/rcmd_video_item.dart';
import '../models/user/fav_folder.dart';
import '../models/video/ai.dart';
import '../models/video_detail_res.dart';
import '../utils/id_utils.dart';
import '../utils/recommend_filter.dart';
import '../utils/storage.dart';
import '../utils/utils.dart';
import '../utils/wbi_sign.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';
import 'login.dart';
import 'video_api.dart';

final class VideoCoinState {
  const VideoCoinState(this.multiply);

  final int multiply;
}

final class VideoFavoriteState {
  const VideoFavoriteState(this.favoured);

  final bool favoured;
}

final class VideoTripleState {
  const VideoTripleState({
    required this.liked,
    required this.coined,
    required this.favoured,
  });

  final bool liked;
  final bool coined;
  final bool favoured;
}

final class VideoActionData {
  const VideoActionData({this.toast});

  final String? toast;
}

final class VideoFollowState {
  const VideoFollowState(this.attribute);

  final int attribute;
}

final class VideoOnlineTotal {
  const VideoOnlineTotal(this.total);

  final String total;
}

final class VideoReplyCreation {
  const VideoReplyCreation({required this.reply, required this.successToast});

  final JsonObject reply;
  final String successToast;
}

final class BangumiFollowAction {
  const BangumiFollowAction(this.toast);

  final String toast;
}

final class VideoSubtitleSource {
  const VideoSubtitleSource({
    required this.url,
    required this.language,
    required this.title,
  });

  final String url;
  final String language;
  final String title;
}

abstract final class VideoHttp {
  static final Box<dynamic> localCache = GStorage.localCache;
  static final Box<dynamic> onlineCache = GStorage.onlineCache;
  static final Box<dynamic> setting = GStorage.setting;
  static final bool enableRcmdDynamic =
      setting.get(SettingBoxKey.enableRcmdDynamic, defaultValue: true) as bool;

  static ApiClient get _client => HttpRuntime.instance.client;

  static Future<ApiResult<List<RcmdVideoItem>>> rcmdVideoList({
    required int ps,
    required int freshIdx,
  }) {
    return _client.getJson<List<RcmdVideoItem>>(
      Api.recommendListWeb,
      queryParameters: <String, dynamic>{
        'version': 1,
        'feed_version': 'V8',
        'homepage_ver': 1,
        'ps': ps,
        'fresh_idx': freshIdx,
        'brush': freshIdx,
        'fresh_type': 4,
      },
      endpoint: 'video.recommend.web',
      decode: (json) => BiliApiDecoder.data<List<RcmdVideoItem>>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final items = BiliApiDecoder.list(data['item'], field: 'data.item');
          final blackMids = _blackMids();
          final videos = <RcmdVideoItem>[];
          for (final value in items) {
            final item = BiliApiDecoder.object(value, field: 'data.item[]');
            final owner = item['owner'];
            final ownerMid = owner is Map ? owner['mid'] : null;
            if (item['goto'] != 'av' ||
                ownerMid is! num ||
                blackMids.contains(ownerMid.toInt())) {
              continue;
            }
            final video = RecVideoItemModel.fromJson(item);
            if (!RecommendFilter.filter(video)) {
              videos.add(video);
            }
          }
          return videos;
        },
      ),
    );
  }

  static Future<ApiResult<List<RcmdVideoItem>>> rcmdVideoListApp({
    bool loginStatus = true,
    required int freshIdx,
  }) {
    final parameters = <String, String>{
      'access_key': loginStatus ? (_accessKey ?? '') : '',
      'appkey': Constants.appKey,
      'build': '2001100',
      'c_locale': 'zh_CN',
      'channel': 'yingyongbao',
      'column': '4',
      'device': 'pad',
      'device_name': 'vivo',
      'device_type': '0',
      'disable_rcmd': '0',
      'flush': '5',
      'fnval': '976',
      'fnver': '0',
      'force_host': '2',
      'fourk': '1',
      'guidance': '0',
      'https_url_req': '0',
      'idx': freshIdx.toString(),
      'mobi_app': 'android_hd',
      'network': 'wifi',
      'platform': 'android',
      'player_net': '1',
      'pull': freshIdx == 0 ? 'true' : 'false',
      'qn': '32',
      'recsys_mode': '0',
      's_locale': 'zh_CN',
      'splash_id': '',
      'statistics': Constants.statistics,
      'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'voice_balance': '0',
    };
    parameters['sign'] = Utils.appSign(
      parameters,
      Constants.appKey,
      Constants.appSec,
    );
    return _client.getJson<List<RcmdVideoItem>>(
      Api.recommendListApp,
      queryParameters: parameters,
      options: Options(
        headers: <String, Object?>{
          'Host': 'app.bilibili.com',
          'buvid': LoginHttp.buvid,
          'fp_local':
              '1111111111111111111111111111111111111111111111111111111111111111',
          'fp_remote':
              '1111111111111111111111111111111111111111111111111111111111111111',
          'session_id': '11111111',
          'env': 'prod',
          'app-key': 'android_hd',
          'User-Agent': Constants.userAgent,
          'x-bili-trace-id': Constants.traceId,
          'x-bili-aurora-eid': '',
          'x-bili-aurora-zone': '',
          'bili-http-engine': 'cronet',
        },
      ),
      endpoint: 'video.recommend.app',
      decode: (json) => BiliApiDecoder.data<List<RcmdVideoItem>>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final items = BiliApiDecoder.list(data['items'], field: 'data.items');
          final blackMids = _blackMids();
          final videos = <RcmdVideoItem>[];
          for (final value in items) {
            final item = BiliApiDecoder.object(value, field: 'data.items[]');
            final arguments = item['args'];
            final ownerMid = arguments is Map ? arguments['up_id'] : null;
            final cardGoto = item['card_goto'];
            if (cardGoto == 'ad_av' ||
                cardGoto == 'ad_web_s' ||
                item['ad_info'] != null ||
                (!enableRcmdDynamic && cardGoto == 'picture') ||
                ownerMid is! num ||
                blackMids.contains(ownerMid.toInt())) {
              continue;
            }
            final video = RecVideoItemAppModel.fromJson(item);
            if (!RecommendFilter.filter(video)) {
              videos.add(video);
            }
          }
          return videos;
        },
      ),
    );
  }

  static Future<ApiResult<List<HotVideoItemModel>>> hotVideoList({
    required int pn,
    required int ps,
  }) {
    return _videoList(
      Api.hotList,
      endpoint: 'video.hot',
      parameters: <String, dynamic>{'pn': pn, 'ps': ps},
      listField: 'list',
    );
  }

  static Future<ApiResult<VideoDetailData>> videoIntro({required String bvid}) {
    return VideoApi.instance.detail(bvid: bvid);
  }

  static Future<ApiResult<List<HotVideoItemModel>>> relatedVideoList({
    required String bvid,
  }) {
    if (RecommendFilter.disableRelatedVideos) {
      return Future.value(const ApiSuccess<List<HotVideoItemModel>>([]));
    }
    return _client.getJson<List<HotVideoItemModel>>(
      Api.relatedList,
      queryParameters: <String, dynamic>{'bvid': bvid},
      endpoint: 'video.related',
      decode: (json) => BiliApiDecoder.data<List<HotVideoItemModel>>(
        json,
        decode: (value) {
          final videos = <HotVideoItemModel>[];
          for (final raw in BiliApiDecoder.list(value, field: 'data')) {
            final item = HotVideoItemModel.fromJson(
              BiliApiDecoder.object(raw, field: 'data[]'),
            );
            if (!RecommendFilter.filter(item, relatedVideos: true)) {
              videos.add(item);
            }
          }
          return videos;
        },
      ),
    );
  }

  static Future<ApiResult<int>> hasLikeVideo({required String bvid}) {
    return _client.getJson<int>(
      Api.hasLikeVideo,
      queryParameters: <String, dynamic>{'bvid': bvid},
      endpoint: 'video.likeState',
      decode: (json) => BiliApiDecoder.data<int>(
        json,
        decode: (value) => BiliApiDecoder.integer(value, field: 'data'),
      ),
    );
  }

  static Future<ApiResult<VideoCoinState>> hasCoinVideo({
    required String bvid,
  }) {
    return _client.getJson<VideoCoinState>(
      Api.hasCoinVideo,
      queryParameters: <String, dynamic>{'bvid': bvid},
      endpoint: 'video.coinState',
      decode: (json) => BiliApiDecoder.data<VideoCoinState>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          return VideoCoinState(
            BiliApiDecoder.integer(data['multiply'], field: 'data.multiply'),
          );
        },
      ),
    );
  }

  static Future<ApiResult<void>> coinVideo({
    required String bvid,
    required int multiply,
  }) {
    return _client.postJson<void>(
      Api.coinVideo,
      queryParameters: <String, dynamic>{
        'aid': IdUtils.bv2av(bvid),
        'multiply': multiply,
        'select_like': 0,
        'access_key': _accessKey,
      },
      endpoint: 'video.coin',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<VideoFavoriteState>> hasFavVideo({required int aid}) {
    return _client.getJson<VideoFavoriteState>(
      Api.hasFavVideo,
      queryParameters: <String, dynamic>{'aid': aid},
      endpoint: 'video.favoriteState',
      decode: (json) => BiliApiDecoder.data<VideoFavoriteState>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          return VideoFavoriteState(data['favoured'] == true);
        },
      ),
    );
  }

  static Future<ApiResult<VideoTripleState>> oneThree({required String bvid}) {
    return _client.postJson<VideoTripleState>(
      Api.oneThree,
      queryParameters: <String, dynamic>{
        'aid': IdUtils.bv2av(bvid),
        'access_key': _accessKey,
      },
      endpoint: 'video.triple',
      decode: (json) => BiliApiDecoder.data<VideoTripleState>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          return VideoTripleState(
            liked: data['like'] == true,
            coined: data['coin'] == true,
            favoured: data['fav'] == true,
          );
        },
      ),
    );
  }

  static Future<ApiResult<VideoActionData>> likeVideo({
    required String bvid,
    required bool type,
  }) {
    return _client.postJson<VideoActionData>(
      Api.likeVideo,
      queryParameters: <String, dynamic>{
        'aid': IdUtils.bv2av(bvid),
        'like': type ? 0 : 1,
        'access_key': _accessKey,
      },
      endpoint: 'video.like',
      decode: (json) => BiliApiDecoder.data<VideoActionData>(
        json,
        decode: (value) {
          final data = value is Map
              ? value.map((key, value) => MapEntry(key.toString(), value))
              : const <String, dynamic>{};
          return VideoActionData(toast: data['toast'] as String?);
        },
      ),
    );
  }

  static Future<ApiResult<void>> dislikeVideo({
    required String bvid,
    required bool type,
  }) {
    final accessKey = _accessKey;
    if (accessKey == null || accessKey.isEmpty) {
      return Future.value(_missingAccessKey('video.dislike'));
    }
    return _client.postJson<void>(
      Api.dislikeVideo,
      queryParameters: <String, dynamic>{
        'aid': IdUtils.bv2av(bvid),
        'dislike': type ? 0 : 1,
        'access_key': accessKey,
      },
      endpoint: 'video.dislike',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<void>> feedDislike({
    required String goto,
    required int id,
    int? reasonId,
    int? feedbackId,
  }) {
    assert((reasonId != null) ^ (feedbackId != null));
    return _feedDislikeRequest(
      Api.feedDislike,
      endpoint: 'video.feedDislike',
      goto: goto,
      id: id,
      reasonId: reasonId,
      feedbackId: feedbackId,
    );
  }

  static Future<ApiResult<void>> feedDislikeCancel({
    required String goto,
    required int id,
    int? reasonId,
    int? feedbackId,
  }) {
    return _feedDislikeRequest(
      Api.feedDislikeCancel,
      endpoint: 'video.feedDislikeCancel',
      goto: goto,
      id: id,
      reasonId: reasonId,
      feedbackId: feedbackId,
    );
  }

  static Future<ApiResult<void>> favVideo({
    required int aid,
    String? addIds,
    String? delIds,
  }) async {
    return _client.postJson<void>(
      Api.favVideo,
      queryParameters: <String, dynamic>{
        'rid': aid,
        'type': 2,
        'add_media_ids': addIds ?? '',
        'del_media_ids': delIds ?? '',
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      endpoint: 'video.favorite',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<FavFolderData>> videoInFolder({
    required int mid,
    required int rid,
  }) {
    return _client.getJson<FavFolderData>(
      Api.videoInFolder,
      queryParameters: <String, dynamic>{'up_mid': mid, 'rid': rid},
      endpoint: 'video.favoriteFolders',
      decode: (json) => BiliApiDecoder.data<FavFolderData>(
        json,
        decode: (value) =>
            FavFolderData.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }

  static Future<ApiResult<VideoReplyCreation>> replyAdd({
    required ReplyType type,
    required int oid,
    required String message,
    int? root,
    int? parent,
  }) async {
    if (message.isEmpty) {
      return const ApiFailure<VideoReplyCreation>(
        kind: ApiFailureKind.apiRejected,
        message: '请输入评论内容',
        endpoint: 'video.replyAdd',
      );
    }
    return _client.postJson<VideoReplyCreation>(
      Api.replyAdd,
      queryParameters: <String, dynamic>{
        'type': type.index,
        'oid': oid,
        'root': root == null || root == 0 ? '' : root,
        'parent': parent == null || parent == 0 ? '' : parent,
        'message': message,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      endpoint: 'video.replyAdd',
      decode: (json) => BiliApiDecoder.data<VideoReplyCreation>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          return VideoReplyCreation(
            reply: BiliApiDecoder.object(data['reply'], field: 'data.reply'),
            successToast: data['success_toast'] as String? ?? '评论成功',
          );
        },
      ),
    );
  }

  static Future<ApiResult<void>> replyDel({
    required int type,
    required int oid,
    required int rpid,
  }) async {
    return _client.postJson<void>(
      Api.replyDel,
      queryParameters: <String, dynamic>{
        'type': type,
        'oid': oid,
        'rpid': rpid,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      endpoint: 'video.replyDelete',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<VideoFollowState>> hasFollow({required int mid}) {
    return _client.getJson<VideoFollowState>(
      Api.hasFollow,
      queryParameters: <String, dynamic>{'fid': mid},
      endpoint: 'video.followState',
      decode: (json) => BiliApiDecoder.data<VideoFollowState>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          return VideoFollowState(
            BiliApiDecoder.integer(data['attribute'], field: 'data.attribute'),
          );
        },
      ),
    );
  }

  static Future<ApiResult<void>> relationMod({
    required int mid,
    required int act,
    required int reSrc,
  }) async {
    const pcUserAgent =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';
    return _client.postJson<void>(
      Api.relationMod,
      data: <String, dynamic>{
        'fid': mid,
        'act': act,
        're_src': reSrc,
        'gaia_source': 'web_main',
        'spmid': '333.999.0.0',
        'extend_content': <String, Object?>{
          'entity': 'user',
          'entity_id': mid,
          'fp': pcUserAgent,
        },
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: <String, Object?>{
          'origin': 'https://space.bilibili.com',
          'referer': 'https://space.bilibili.com/$mid/dynamic',
          'user-agent': pcUserAgent,
        },
      ),
      endpoint: 'video.relationModify',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<void>> heartBeat({
    required String bvid,
    required int cid,
    required int progress,
  }) async {
    return _client.postJson<void>(
      Api.heartBeat,
      queryParameters: <String, dynamic>{
        'bvid': bvid,
        'cid': cid,
        'played_time': progress,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      endpoint: 'video.heartbeat',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<BangumiFollowAction>> bangumiAdd({int? seasonId}) {
    return _bangumiFollow(Api.bangumiAdd, seasonId, 'video.bangumiFollow');
  }

  static Future<ApiResult<BangumiFollowAction>> bangumiDel({int? seasonId}) {
    return _bangumiFollow(Api.bangumiDel, seasonId, 'video.bangumiUnfollow');
  }

  static Future<ApiResult<VideoOnlineTotal>> onlineTotal({
    int? aid,
    String? bvid,
    int? cid,
  }) {
    return _client.getJson<VideoOnlineTotal>(
      Api.onlineTotal,
      queryParameters: <String, dynamic>{'aid': aid, 'bvid': bvid, 'cid': cid},
      endpoint: 'video.onlineTotal',
      decode: (json) => BiliApiDecoder.data<VideoOnlineTotal>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final total = data['total'];
          if (total is! String && total is! num) {
            throw const MalformedApiResponseException('data.total 字段格式不正确');
          }
          return VideoOnlineTotal(total.toString());
        },
      ),
    );
  }

  static Future<ApiResult<AiConclusionModel>> aiConclusion({
    String? bvid,
    int? cid,
    int? upMid,
  }) async {
    final signed = await WbiSign().sign(<String, dynamic>{
      'bvid': bvid,
      'cid': cid,
      'up_mid': upMid,
    });
    if (signed case ApiFailure<Map<String, dynamic>> failure) {
      return failure.cast<AiConclusionModel>();
    }
    return _client.getJson<AiConclusionModel>(
      Api.aiConclusion,
      queryParameters: (signed as ApiSuccess<Map<String, dynamic>>).data,
      endpoint: 'video.aiConclusion',
      decode: (json) => BiliApiDecoder.data<AiConclusionModel>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final code = data['code'];
          if (code is! num) {
            throw const MalformedApiResponseException('data.code 字段不是整数');
          }
          if (code.toInt() != 0) {
            throw ApiRejectedException(
              code: code.toInt(),
              message: data['message'] as String? ?? '当前视频暂无 AI 总结',
            );
          }
          return AiConclusionModel.fromJson(data);
        },
      ),
    );
  }

  static Future<ApiResult<List<VideoSubtitleSource>>> videoMetaInfo({
    String? aid,
    String? bvid,
    required int cid,
  }) {
    assert(aid != null || bvid != null);
    return _client.getJson<List<VideoSubtitleSource>>(
      Api.videoMetaInfo,
      queryParameters: <String, dynamic>{
        if (aid != null) 'aid': aid,
        if (bvid != null) 'bvid': bvid,
        'cid': cid,
      },
      endpoint: 'video.metadata',
      decode: (json) => BiliApiDecoder.data<List<VideoSubtitleSource>>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final subtitle = BiliApiDecoder.object(
            data['subtitle'],
            field: 'data.subtitle',
          );
          return BiliApiDecoder.list(
            subtitle['subtitles'],
            field: 'data.subtitle.subtitles',
          ).map((value) {
            final item = BiliApiDecoder.object(
              value,
              field: 'data.subtitle.subtitles[]',
            );
            final rawUrl = item['subtitle_url'];
            if (rawUrl is! String || rawUrl.isEmpty) {
              throw const MalformedApiResponseException('字幕地址格式不正确');
            }
            return VideoSubtitleSource(
              url: rawUrl.startsWith('//') ? 'https:$rawUrl' : rawUrl,
              language: item['lan'] as String? ?? '',
              title: item['lan_doc'] as String? ?? '',
            );
          }).toList();
        },
      ),
    );
  }

  static Future<ApiResult<List<Map<String, String>>>> vttSubtitles(
    List<VideoSubtitleSource> subtitles,
  ) async {
    if (subtitles.isEmpty) {
      return const ApiSuccess<List<Map<String, String>>>([]);
    }
    final tracks = <Map<String, String>>[];
    ApiFailure<JsonObject>? lastFailure;
    for (final subtitle in subtitles) {
      final response = await _client.getJson<JsonObject>(
        subtitle.url,
        endpoint: 'video.subtitle',
        decode: (json) => json,
      );
      if (response case ApiFailure<JsonObject> failure) {
        lastFailure = failure;
        continue;
      }
      try {
        final body = BiliApiDecoder.list(
          (response as ApiSuccess<JsonObject>).data['body'],
          field: 'body',
        );
        final text = StringBuffer('WEBVTT\n\n');
        for (final rawCue in body) {
          final cue = BiliApiDecoder.object(rawCue, field: 'body[]');
          final start = cue['from'];
          final end = cue['to'];
          final content = cue['content'];
          if (start is! num || end is! num || content is! String) {
            throw const MalformedApiResponseException('字幕条目格式不正确');
          }
          text
            ..writeln(cue['sid'] ?? 0)
            ..writeln(
              '${_subtitleTimecode(start)} --> ${_subtitleTimecode(end)}',
            )
            ..writeln(content.trim())
            ..writeln();
        }
        tracks.add(<String, String>{
          'language': subtitle.language,
          'title': subtitle.title,
          'text': text.toString(),
        });
      } catch (_) {
        lastFailure = const ApiFailure<JsonObject>(
          kind: ApiFailureKind.decoding,
          message: '字幕数据无法解析',
          endpoint: 'video.subtitle',
        );
      }
    }
    if (tracks.isEmpty && lastFailure != null) {
      return lastFailure.cast<List<Map<String, String>>>();
    }
    if (tracks.isNotEmpty) {
      tracks.insert(0, const <String, String>{
        'language': '',
        'title': '关闭字幕',
        'text': '',
      });
    }
    return ApiSuccess<List<Map<String, String>>>(tracks);
  }

  static Future<ApiResult<List<HotVideoItemModel>>> getRankVideoList(int rid) {
    return _videoList(
      Api.getRankApi,
      endpoint: 'video.rank',
      parameters: <String, dynamic>{'rid': rid, 'type': 'all'},
      listField: 'list',
    );
  }

  static Future<ApiResult<List<HotVideoItemModel>>> getRegionVideoList(
    int tid,
    int pn,
    int ps,
  ) {
    return _videoList(
      Api.getRegionApi,
      endpoint: 'video.region',
      parameters: <String, dynamic>{'rid': tid, 'pn': pn, 'ps': ps},
      listField: 'archives',
    );
  }

  static Future<ApiResult<void>> _feedDislikeRequest(
    String url, {
    required String endpoint,
    required String goto,
    required int id,
    int? reasonId,
    int? feedbackId,
  }) {
    final accessKey = _accessKey;
    if (accessKey == null || accessKey.isEmpty) {
      return Future.value(_missingAccessKey(endpoint));
    }
    return _client.getJson<void>(
      url,
      queryParameters: <String, dynamic>{
        'goto': goto,
        'id': id,
        if (reasonId != null) 'reason_id': reasonId,
        if (feedbackId != null) 'feedback_id': feedbackId,
        'build': 1,
        'mobi_app': 'android',
        'access_key': accessKey,
        'appkey': Constants.appKey,
      },
      endpoint: endpoint,
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<BangumiFollowAction>> _bangumiFollow(
    String url,
    int? seasonId,
    String endpoint,
  ) async {
    return _client.postJson<BangumiFollowAction>(
      url,
      queryParameters: <String, dynamic>{
        'season_id': seasonId,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      endpoint: endpoint,
      decode: (json) => BiliApiDecoder.result<BangumiFollowAction>(
        json,
        decode: (value) {
          final result = BiliApiDecoder.object(value, field: 'result');
          return BangumiFollowAction(result['toast'] as String? ?? '操作成功');
        },
      ),
    );
  }

  static Future<ApiResult<List<HotVideoItemModel>>> _videoList(
    String url, {
    required String endpoint,
    required Map<String, dynamic> parameters,
    required String listField,
  }) {
    return _client.getJson<List<HotVideoItemModel>>(
      url,
      queryParameters: parameters,
      endpoint: endpoint,
      decode: (json) => BiliApiDecoder.data<List<HotVideoItemModel>>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final values = BiliApiDecoder.list(
            data[listField],
            field: 'data.$listField',
          );
          final blackMids = _blackMids();
          final videos = <HotVideoItemModel>[];
          for (final value in values) {
            final item = BiliApiDecoder.object(
              value,
              field: 'data.$listField[]',
            );
            final owner = item['owner'];
            final mid = owner is Map ? owner['mid'] : null;
            if (mid is! num || blackMids.contains(mid.toInt())) {
              continue;
            }
            videos.add(HotVideoItemModel.fromJson(item));
          }
          return videos;
        },
      ),
    );
  }

  static List<int> _blackMids() {
    final cached = onlineCache.get(
      OnlineCacheKey.blackMidsList,
      defaultValue: <int>[-1],
    );
    if (cached is! Iterable) {
      return <int>[-1];
    }
    return cached.whereType<num>().map((value) => value.toInt()).toList();
  }

  static String? get _accessKey {
    final cached = localCache.get(
      LocalCacheKey.accessKey,
      defaultValue: const <String, Object?>{},
    );
    if (cached is Map && cached['value'] is String) {
      return cached['value'] as String;
    }
    return null;
  }

  static ApiFailure<void> _missingAccessKey(String endpoint) {
    return ApiFailure<void>(
      kind: ApiFailureKind.apiRejected,
      message: '请退出账号后重新登录',
      endpoint: endpoint,
    );
  }

  static String _subtitleTimecode(num seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final wholeSeconds = (seconds % 60).floor();
    final milliseconds = ((seconds * 1000) % 1000).floor();
    final minuteAndSecond =
        '${minutes.toString().padLeft(2, '0')}:'
        '${wholeSeconds.toString().padLeft(2, '0')}.'
        '${milliseconds.toString().padLeft(3, '0')}';
    return hours == 0
        ? minuteAndSecond
        : '${hours.toString().padLeft(2, '0')}:$minuteAndSecond';
  }
}

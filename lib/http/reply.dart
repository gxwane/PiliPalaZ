import 'dart:io';

import 'package:dio/dio.dart';

import '../models/video/reply/data.dart';
import '../models/video/reply/emote.dart';
import '../utils/storage.dart';
import 'api.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

class ReplyHttp {
  static Options? get _anonymousOptions =>
      GStorage.userInfo.get('userInfoCache') == null
      ? Options(
          headers: <String, Object?>{
            HttpHeaders.cookieHeader: 'buvid3= ; b_nut= ; sid= ',
          },
        )
      : null;

  static Future<ApiResult<ReplyData>> replyList({
    required int oid,
    required String nextOffset,
    required int type,
    int sort = 1,
  }) {
    return HttpRuntime.instance.client.getJson<ReplyData>(
      Api.replyList,
      endpoint: 'reply.list',
      queryParameters: <String, dynamic>{
        'oid': oid,
        'type': type,
        'pagination_str': '{"offset":"${nextOffset.replaceAll('"', '\\"')}"}',
        'mode': sort + 2,
      },
      options: _anonymousOptions,
      decode: (json) => BiliApiDecoder.data<ReplyData>(
        json,
        decode: (value) =>
            ReplyData.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }

  static Future<ApiResult<ReplyReplyData>> replyReplyList({
    required int oid,
    required String root,
    required int pageNum,
    required int type,
    int sort = 1,
  }) async {
    return HttpRuntime.instance.client.getJson<ReplyReplyData>(
      Api.replyReplyList,
      endpoint: 'reply.replies',
      queryParameters: <String, dynamic>{
        'oid': oid,
        'root': root,
        'pn': pageNum,
        'type': type,
        'sort': sort,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      options: _anonymousOptions,
      decode: (json) => BiliApiDecoder.data<ReplyReplyData>(
        json,
        decode: (value) => ReplyReplyData.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }

  static Future<ApiResult<void>> likeReply({
    required int type,
    required int oid,
    required int rpid,
    required int action,
  }) async {
    return HttpRuntime.instance.client.postJson<void>(
      Api.likeReply,
      endpoint: 'reply.like',
      queryParameters: <String, dynamic>{
        'type': type,
        'oid': oid,
        'rpid': rpid,
        'action': action,
        'csrf': await HttpRuntime.instance.getCsrf(),
      },
      decode: (json) => BiliApiDecoder.success(json),
    );
  }

  static Future<ApiResult<EmoteModelData>> getEmoteList({String? business}) {
    return HttpRuntime.instance.client.getJson<EmoteModelData>(
      Api.myEmote,
      endpoint: 'reply.emotes',
      queryParameters: <String, dynamic>{
        'business': business ?? 'reply',
        'web_location': '333.1245',
      },
      decode: (json) => BiliApiDecoder.data<EmoteModelData>(
        json,
        decode: (value) => EmoteModelData.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }
}

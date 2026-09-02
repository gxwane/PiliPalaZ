import 'dart:math';

import 'package:dio/dio.dart';

import '../models/msg/account.dart';
import '../models/msg/msgfeed_at_me.dart';
import '../models/msg/msgfeed_like_me.dart';
import '../models/msg/msgfeed_reply_me.dart';
import '../models/msg/msgfeed_sys_msg.dart';
import '../models/msg/msgfeed_unread.dart';
import '../models/msg/session.dart';
import '../utils/wbi_sign.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

abstract final class MsgHttp {
  static ApiClient get _client => HttpRuntime.instance.client;

  static Future<ApiResult<MsgFeedReplyMe>> msgFeedReplyMe({
    int cursor = -1,
    int cursorTime = -1,
  }) {
    return _getData<MsgFeedReplyMe>(
      Api.msgFeedReply,
      endpoint: 'message.replyFeed',
      parameters: <String, dynamic>{
        'id': cursor == -1 ? null : cursor,
        'reply_time': cursorTime == -1 ? null : cursorTime,
      },
      decode: MsgFeedReplyMe.fromJson,
    );
  }

  static Future<ApiResult<MsgFeedAtMe>> msgFeedAtMe({
    int cursor = -1,
    int cursorTime = -1,
  }) {
    return _getData<MsgFeedAtMe>(
      Api.msgFeedAt,
      endpoint: 'message.atFeed',
      parameters: <String, dynamic>{
        'id': cursor == -1 ? null : cursor,
        'at_time': cursorTime == -1 ? null : cursorTime,
      },
      decode: MsgFeedAtMe.fromJson,
    );
  }

  static Future<ApiResult<MsgFeedLikeMe>> msgFeedLikeMe({
    int cursor = -1,
    int cursorTime = -1,
  }) {
    return _getData<MsgFeedLikeMe>(
      Api.msgFeedLike,
      endpoint: 'message.likeFeed',
      parameters: <String, dynamic>{
        'id': cursor == -1 ? null : cursor,
        'like_time': cursorTime == -1 ? null : cursorTime,
      },
      decode: MsgFeedLikeMe.fromJson,
    );
  }

  static Future<ApiResult<MsgFeedSysMsg>> msgFeedSysUserNotify() async {
    return _getData<MsgFeedSysMsg>(
      Api.msgSysUserNotify,
      endpoint: 'message.systemUserFeed',
      parameters: <String, dynamic>{
        'csrf': await HttpRuntime.instance.getCsrf(),
        'page_size': 20,
      },
      decode: MsgFeedSysMsg.fromJson,
    );
  }

  static Future<ApiResult<MsgFeedSysMsg>> msgFeedSysUnifiedNotify() async {
    return _getData<MsgFeedSysMsg>(
      Api.msgSysUnifiedNotify,
      endpoint: 'message.systemUnifiedFeed',
      parameters: <String, dynamic>{
        'csrf': await HttpRuntime.instance.getCsrf(),
        'page_size': 10,
      },
      decode: MsgFeedSysMsg.fromJson,
    );
  }

  static Future<ApiResult<void>> msgSysUpdateCursor(int cursor) async {
    return _client.getJson<void>(
      Api.msgSysUpdateCursor,
      queryParameters: <String, dynamic>{
        'csrf': await HttpRuntime.instance.getCsrf(),
        'cursor': cursor,
      },
      endpoint: 'message.updateSystemCursor',
      decode: BiliApiDecoder.success,
    );
  }

  static Future<ApiResult<MsgFeedUnread>> msgFeedUnread() {
    return _getData<MsgFeedUnread>(
      Api.msgFeedUnread,
      endpoint: 'message.unread',
      decode: MsgFeedUnread.fromJson,
    );
  }

  static Future<ApiResult<SessionDataModel>> sessionList({int? endTs}) {
    return _getSigned<SessionDataModel>(
      Api.sessionList,
      endpoint: 'message.sessions',
      parameters: <String, dynamic>{
        'session_type': 1,
        'group_fold': 1,
        'unfollow_fold': 0,
        'sort_rule': 2,
        'build': 0,
        'mobi_app': 'web',
        if (endTs != null) 'end_ts': endTs,
      },
      decode: SessionDataModel.fromJson,
    );
  }

  static Future<ApiResult<List<AccountListModel>>> accountList(String uids) {
    return _client.getJson<List<AccountListModel>>(
      Api.sessionAccountList,
      queryParameters: <String, dynamic>{
        'uids': uids,
        'build': 0,
        'mobi_app': 'web',
      },
      endpoint: 'message.accounts',
      decode: (json) => BiliApiDecoder.data<List<AccountListModel>>(
        json,
        decode: (value) =>
            BiliApiDecoder.list(value, field: 'data').map((item) {
              return AccountListModel.fromJson(
                BiliApiDecoder.object(item, field: 'data[]'),
              );
            }).toList(),
      ),
    );
  }

  static Future<ApiResult<SessionMsgDataModel>> sessionMsg({int? talkerId}) {
    return _getSigned<SessionMsgDataModel>(
      Api.sessionMsg,
      endpoint: 'message.sessionDetail',
      parameters: <String, dynamic>{
        'talker_id': talkerId,
        'session_type': 1,
        'size': 20,
        'sender_device_id': 1,
        'build': 0,
        'mobi_app': 'web',
      },
      decode: SessionMsgDataModel.fromJson,
    );
  }

  static Future<ApiResult<void>> ackSessionMsg({
    int? talkerId,
    int? ackSeqno,
  }) async {
    final csrf = await HttpRuntime.instance.getCsrf();
    return _getSigned<void>(
      Api.ackSessionMsg,
      endpoint: 'message.ackSession',
      parameters: <String, dynamic>{
        'talker_id': talkerId,
        'session_type': 1,
        'ack_seqno': ackSeqno,
        'build': 0,
        'mobi_app': 'web',
        'csrf_token': csrf,
        'csrf': csrf,
      },
      decode: (_) {},
    );
  }

  static Future<ApiResult<void>> sendMsg({
    int? senderUid,
    int? receiverId,
    int? receiverType,
    int? msgType,
    Object? content,
  }) async {
    final csrf = await HttpRuntime.instance.getCsrf();
    final body = <String, dynamic>{
      'msg[sender_uid]': senderUid,
      'msg[receiver_id]': receiverId,
      'msg[receiver_type]': receiverType ?? 1,
      'msg[msg_type]': msgType ?? 1,
      'msg[msg_status]': 0,
      'msg[dev_id]': getDevId(),
      'msg[timestamp]': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'msg[new_face_version]': 1,
      'msg[content]': content,
      'from_firework': 0,
      'build': 0,
      'mobi_app': 'web',
      'csrf_token': csrf,
      'csrf': csrf,
    };
    final signed = await WbiSign().sign(body);
    if (signed case ApiFailure<Map<String, dynamic>> failure) {
      return failure.cast<void>();
    }
    final parameters = (signed as ApiSuccess<Map<String, dynamic>>).data;
    return _client.postJson<void>(
      Api.sendMsg,
      queryParameters: <String, dynamic>{
        'w_sender_uid': parameters['msg[sender_uid]'],
        'w_receiver_id': parameters['msg[receiver_id]'],
        'w_dev_id': parameters['msg[dev_id]'],
        'w_rid': parameters['w_rid'],
        'wts': parameters['wts'],
      },
      data: FormData.fromMap(body),
      endpoint: 'message.send',
      decode: BiliApiDecoder.success,
    );
  }

  static String getDevId() {
    const characters = <String>[
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
    ];
    final result = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.split('');
    final random = Random();
    for (var index = 0; index < result.length; index++) {
      if (result[index] == '-' || result[index] == '4') {
        continue;
      }
      final value = random.nextInt(16);
      result[index] = characters[result[index] == 'x' ? value : 3 & value | 8];
    }
    return result.join();
  }

  static Future<ApiResult<T>> _getData<T>(
    String url, {
    required String endpoint,
    Map<String, dynamic>? parameters,
    required T Function(Map<String, dynamic> value) decode,
  }) {
    return _client.getJson<T>(
      url,
      queryParameters: parameters,
      endpoint: endpoint,
      decode: (json) => BiliApiDecoder.data<T>(
        json,
        decode: (value) => decode(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }

  static Future<ApiResult<T>> _getSigned<T>(
    String url, {
    required String endpoint,
    required Map<String, dynamic> parameters,
    required T Function(Map<String, dynamic> value) decode,
  }) async {
    final signed = await WbiSign().sign(parameters);
    if (signed case ApiFailure<Map<String, dynamic>> failure) {
      return failure.cast<T>();
    }
    return _getData<T>(
      url,
      endpoint: endpoint,
      parameters: (signed as ApiSuccess<Map<String, dynamic>>).data,
      decode: decode,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/msg.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/msg/account.dart';
import 'package:pilipalaz/models/msg/session.dart';

import '../../models/msg/msgfeed_unread.dart';
import '../../utils/storage.dart';

class WhisperController extends GetxController {
  RxList<SessionList> sessionList = <SessionList>[].obs;
  RxList<AccountListModel> accountList = <AccountListModel>[].obs;
  bool isLoading = false;
  Rx<MsgFeedUnread> msgFeedUnread = MsgFeedUnread().obs;
  RxList msgFeedTop = [
    {
      "name": "回复我的",
      "icon": Icons.message_outlined,
      "route": "/replyMe",
      "enabled": true,
      "value": 0,
    },
    {
      "name": "@我",
      "icon": Icons.alternate_email_outlined,
      "route": "/atMe",
      "enabled": true,
      "value": 0,
    },
    {
      "name": "收到的赞",
      "icon": Icons.favorite_border_outlined,
      "route": "/likeMe",
      "enabled": true,
      "value": 0,
    },
    {
      "name": "系统通知",
      "icon": Icons.notifications_none_outlined,
      "route": "/sysMsg",
      "enabled": true,
      "value": 0,
    },
  ].obs;

  Future queryMsgFeedUnread() async {
    var res = await MsgHttp.msgFeedUnread();
    if (res case ApiSuccess<MsgFeedUnread>(:final data)) {
      msgFeedUnread.value = data;
      msgFeedTop[0]["value"] = msgFeedUnread.value.reply;
      msgFeedTop[1]["value"] = msgFeedUnread.value.at;
      msgFeedTop[2]["value"] = msgFeedUnread.value.like;
      msgFeedTop[3]["value"] = msgFeedUnread.value.sys_msg;
      if (GStorage.setting.get(
        SettingBoxKey.disableLikeMsg,
        defaultValue: false,
      )) {
        msgFeedTop[2]["value"] = -1;
        msgFeedTop[2]["enabled"] = false;
      }
      // 触发更新
      msgFeedTop.refresh();
    } else {
      SmartDialog.showToast((res as ApiFailure<MsgFeedUnread>).message);
    }
  }

  Future<ApiResult<SessionDataModel>?> querySessionList(String? type) async {
    if (isLoading) return null;
    isLoading = true;
    try {
      var res = await MsgHttp.sessionList(
        endTs: type == 'onLoad' && sessionList.isNotEmpty
            ? sessionList.last.sessionTs
            : null,
      );
      if (res case ApiSuccess<SessionDataModel>(:final data)) {
        final sessions = data.sessionList ?? <SessionList>[];
        if (sessions.isNotEmpty) {
          await queryAccountList(sessions);
          // 将 accountList 转换为 Map 结构
          Map<int, dynamic> accountMap = {};
          for (var j in accountList) {
            accountMap[j.mid!] = j;
          }

          // 遍历 sessionList，通过 mid 查找并赋值 accountInfo
          for (final i in sessions) {
            var accountInfo = accountMap[i.talkerId];
            if (accountInfo != null) {
              i.accountInfo = accountInfo;
            }
            if (i.talkerId == 844424930131966) {
              i.accountInfo = AccountListModel(
                name: 'UP主小助手',
                face:
                    'https://message.biliimg.com/bfs/im/489a63efadfb202366c2f88853d2217b5ddc7a13.png',
              );
            }
          }
          if (type == 'onLoad') {
            sessionList.addAll(sessions);
          } else {
            sessionList.value = sessions;
          }
        }
      } else {
        SmartDialog.showToast((res as ApiFailure<SessionDataModel>).message);
      }
      return res;
    } finally {
      isLoading = false;
    }
  }

  Future<ApiResult<List<AccountListModel>>> queryAccountList(
    List<SessionList> sessions,
  ) async {
    final midsList = sessions.map((item) => item.talkerId!).toList();
    var res = await MsgHttp.accountList(midsList.join(','));
    if (res case ApiSuccess<List<AccountListModel>>(:final data)) {
      accountList.value = data;
    }
    return res;
  }

  Future onLoad() async {
    return querySessionList('onLoad');
  }

  Future onRefresh() async {
    return querySessionList('onRefresh');
  }
}

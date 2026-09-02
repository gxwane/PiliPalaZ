import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/msg.dart';
import 'package:pilipalaz/http/api_result.dart';

import '../../../models/msg/msgfeed_sys_msg.dart';

class SysMsgController extends GetxController {
  RxList<SystemNotifyList> msgFeedSysMsgList = <SystemNotifyList>[].obs;
  bool isLoading = false;
  int cursor = -1;
  int cursorTime = -1;
  bool isEnd = false;

  Future queryMsgFeedSysMsg() async {
    if (isLoading) return;
    isLoading = true;
    var resUserNotify = await MsgHttp.msgFeedSysUserNotify();
    var resUnifiedNotify = await MsgHttp.msgFeedSysUnifiedNotify();
    isLoading = false;
    List<SystemNotifyList> systemNotifyList = [];
    if (resUserNotify case ApiSuccess<MsgFeedSysMsg>(:final data)) {
      if (data.systemNotifyList != null) {
        systemNotifyList.addAll(data.systemNotifyList!);
      }
    }
    if (resUnifiedNotify case ApiSuccess<MsgFeedSysMsg>(:final data)) {
      if (data.systemNotifyList != null) {
        systemNotifyList.addAll(data.systemNotifyList!);
      }
    }
    if (systemNotifyList.isNotEmpty) {
      systemNotifyList.sort((a, b) => b.cursor!.compareTo(a.cursor!));
      msgFeedSysMsgList.assignAll(systemNotifyList);
      msgSysUpdateCursor(msgFeedSysMsgList.first.cursor!);
    } else {
      final userMessage = resUserNotify is ApiFailure<MsgFeedSysMsg>
          ? resUserNotify.message
          : '无系统消息';
      final unifiedMessage = resUnifiedNotify is ApiFailure<MsgFeedSysMsg>
          ? resUnifiedNotify.message
          : '无统一通知';
      SmartDialog.showToast(
        'UserNotify: $userMessage UnifiedNotify: $unifiedMessage',
      );
    }
  }

  Future msgSysUpdateCursor(int cursor) async {
    var res = await MsgHttp.msgSysUpdateCursor(cursor);
    if (res is ApiSuccess<void>) {
      SmartDialog.showToast('已读成功');
      return true;
    } else {
      SmartDialog.showToast((res as ApiFailure<void>).message);
      return false;
    }
  }

  Future onLoad() async {
    if (isEnd) return;
    queryMsgFeedSysMsg();
  }

  Future onRefresh() async {
    cursor = -1;
    cursorTime = -1;
    queryMsgFeedSysMsg();
  }
}

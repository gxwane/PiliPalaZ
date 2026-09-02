import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/msg.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/msg/msgfeed_at_me.dart';

class AtMeController extends GetxController {
  RxList<AtMeItems> msgFeedAtMeList = <AtMeItems>[].obs;
  bool isLoading = false;
  int cursor = -1;
  int cursorTime = -1;
  bool isEnd = false;

  Future queryMsgFeedAtMe() async {
    if (isLoading) return;
    isLoading = true;
    var res = await MsgHttp.msgFeedAtMe(cursor: cursor, cursorTime: cursorTime);
    isLoading = false;
    if (res case ApiSuccess<MsgFeedAtMe>(:final data)) {
      isEnd = data.cursor?.isEnd ?? false;
      if (cursor == -1) {
        msgFeedAtMeList.assignAll(data.items!);
      } else {
        msgFeedAtMeList.addAll(data.items!);
      }
      cursor = data.cursor?.id ?? -1;
      cursorTime = data.cursor?.time ?? -1;
    } else {
      SmartDialog.showToast((res as ApiFailure<MsgFeedAtMe>).message);
    }
  }

  Future onLoad() async {
    if (isEnd) return;
    queryMsgFeedAtMe();
  }

  Future onRefresh() async {
    cursor = -1;
    cursorTime = -1;
    queryMsgFeedAtMe();
  }
}

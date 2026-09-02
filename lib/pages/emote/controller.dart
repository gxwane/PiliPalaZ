import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../http/reply.dart';
import '../../http/api_result.dart';
import '../../models/video/reply/emote.dart';

class EmotePanelController extends GetxController
    with GetTickerProviderStateMixin {
  late List<Packages> emotePackage;
  late TabController tabController;

  Future<ApiResult<EmoteModelData>> getEmote() async {
    var res = await ReplyHttp.getEmoteList(business: 'reply');
    if (res case ApiSuccess<EmoteModelData>(:final data)) {
      emotePackage = data.packages ?? <Packages>[];
      tabController = TabController(length: emotePackage.length, vsync: this);
    }
    return res;
  }
}

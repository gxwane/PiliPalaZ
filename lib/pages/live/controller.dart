import 'package:pilipalaz/utils/extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/live.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/utils/storage.dart';

class LiveController extends GetxController {
  final ScrollController scrollController = ScrollController();
  int count = 12;
  int _currentPage = 1;
  RxInt crossAxisCount = 2.obs;
  RxList<LiveItemModel> liveList = <LiveItemModel>[].obs;
  bool flag = false;
  List<OverlayEntry?> popupDialog = <OverlayEntry?>[];
  Box setting = GStorage.setting;

  // 获取推荐
  Future<ApiResult<List<LiveItemModel>>> queryLiveList(type) async {
    // if (type == 'init') {
    //   _currentPage = 1;
    // }
    var res = await LiveHttp.liveList(
      pn: _currentPage,
    );
    if (res case ApiSuccess<List<LiveItemModel>>(:final data)) {
      if (type == 'init') {
        liveList.value = data;
      } else if (type == 'onLoad') {
        liveList.addAll(data);
      }
      _currentPage += 1;
    }
    return res;
  }

  // 下拉刷新
  Future onRefresh() async {
    await queryLiveList('init');
  }

  // 上拉加载
  Future onLoad() async {
    await queryLiveList('onLoad');
  }

  // 返回顶部并刷新
  void animateToTop() {
    scrollController.animToTop();
  }
}

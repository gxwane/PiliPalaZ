import 'package:pilipalaz/utils/extension.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/model_hot_video_item.dart';

class HotController extends GetxController {
  final ScrollController scrollController = ScrollController();
  final int _count = 20;
  int _currentPage = 1;
  RxList<HotVideoItemModel> videoList = <HotVideoItemModel>[].obs;
  bool isLoadingMore = false;
  bool flag = false;

  // 获取推荐
  Future<ApiResult<List<HotVideoItemModel>>> queryHotFeed(String type) async {
    if (type != 'onLoad') {
      _currentPage = 1;
    }
    var res = await VideoHttp.hotVideoList(pn: _currentPage, ps: _count);
    if (res case ApiSuccess<List<HotVideoItemModel>>(:final data)) {
      if (type == 'init') {
        videoList.value = data;
      } else if (type == 'onRefresh') {
        // videoList.insertAll(0, res['data']);
        videoList.value = data;
      } else if (type == 'onLoad') {
        videoList.addAll(data);
      }
      _currentPage += 1;
      if (_currentPage == 2) queryHotFeed('onLoad');
    }
    isLoadingMore = false;
    return res;
  }

  // 下拉刷新
  Future onRefresh() async {
    await queryHotFeed('onRefresh');
  }

  // 上拉加载
  Future onLoad() async {
    await queryHotFeed('onLoad');
  }

  // 返回顶部
  void animateToTop() {
    scrollController.animToTop();
  }
}

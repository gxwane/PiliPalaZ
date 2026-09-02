import 'package:pilipalaz/utils/extension.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/model_hot_video_item.dart';

class ZoneController extends GetxController {
  final ScrollController scrollController = ScrollController();
  RxList<HotVideoItemModel> videoList = <HotVideoItemModel>[].obs;
  bool isLoadingMore = false;
  bool flag = false;
  int? rid;
  int? tid;

  // 获取推荐
  Future<ApiResult<List<HotVideoItemModel>>> queryRankFeed(
    String type,
    int? rid,
    int? tid,
  ) async {
    this.rid = rid;
    this.tid = tid;
    late ApiResult<List<HotVideoItemModel>> res;
    if (rid != null) {
      res = await VideoHttp.getRankVideoList(rid);
    } else {
      res = await VideoHttp.getRegionVideoList(tid!, 1, 50);
    }
    if (res case ApiSuccess<List<HotVideoItemModel>>(:final data)) {
      if (type == 'init') {
        videoList.value = data;
      } else if (type == 'onRefresh') {
        videoList.clear();
        videoList.addAll(data);
      } else if (type == 'onLoad') {
        videoList.clear();
        videoList.addAll(data);
      }
    }
    isLoadingMore = false;
    return res;
  }

  // 下拉刷新
  Future onRefresh() async {
    queryRankFeed('onRefresh', rid, tid);
  }

  // 上拉加载
  Future onLoad() async {
    queryRankFeed('onLoad', rid, tid);
  }

  // 返回顶部并刷新
  void animateToTop() {
    scrollController.animToTop();
  }
}

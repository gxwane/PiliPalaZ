import 'package:pilipalaz/utils/extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/search.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/utils/id_utils.dart';
import 'package:pilipalaz/utils/utils.dart';

class SearchPanelController extends GetxController {
  SearchPanelController({this.keyword, this.searchType});
  ScrollController scrollController = ScrollController();
  String? keyword;
  SearchType? searchType;
  RxInt page = 1.obs;
  RxList resultList = [].obs;
  // 结果排序方式 搜索类型为视频、专栏及相簿时
  RxString order = ''.obs;
  // 视频时长筛选 仅用于搜索视频
  RxInt duration = 0.obs;

  Future<ApiResult<SearchPageData>> onSearch({type = 'init'}) async {
    var result = await SearchHttp.searchByType(
        searchType: searchType!,
        keyword: keyword!,
        page: page.value,
        order: searchType!.type != 'video' ? null : order.value,
        duration: searchType!.type != 'video' ? null : duration.value);
    if (result case ApiSuccess<SearchPageData>(:final data)) {
      if (type == 'onRefresh') {
        resultList.value = data.items;
      } else {
        resultList.addAll(data.items);
      }
      page.value++;
      onPushDetail(keyword, resultList);
    }
    return result;
  }

  Future onRefresh() async {
    page.value = 1;
    await onSearch(type: 'onRefresh');
  }

  // 返回顶部并刷新
  void animateToTop() {
    scrollController.animToTop();
  }

  void onPushDetail(keyword, resultList) async {
    // 匹配输入内容，如果是AV、BV号且有结果 直接跳转详情页
    Map matchRes = IdUtils.matchAvorBv(input: keyword);
    List matchKeys = matchRes.keys.toList();
    String? bvid;
    try {
      bvid = resultList.first.bvid;
    } catch (_) {
      bvid = null;
    }
    // keyword 可能输入纯数字
    int? aid;
    try {
      aid = resultList.first.aid;
    } catch (_) {
      aid = null;
    }
    if (matchKeys.isNotEmpty && searchType == SearchType.video ||
        aid.toString() == keyword) {
      String heroTag = Utils.makeHeroTag(bvid);
      final cidResult = await SearchHttp.ab2c(aid: aid, bvid: bvid);
      if (cidResult is! ApiSuccess<int>) {
        return;
      }
      final cid = cidResult.data;
      if (matchKeys.isNotEmpty &&
              matchKeys.first == 'BV' &&
              matchRes[matchKeys.first] == bvid ||
          matchKeys.isNotEmpty &&
              matchKeys.first == 'AV' &&
              matchRes[matchKeys.first] == aid ||
          aid.toString() == keyword) {
        Get.toNamed(
          '/video?bvid=$bvid&cid=$cid',
          arguments: {'videoItem': resultList.first, 'heroTag': heroTag},
        );
      }
    }
  }
}

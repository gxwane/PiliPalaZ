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
  int get currentPage => _currentPage;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  RxInt crossAxisCount = 2.obs;
  RxList<LiveItemModel> liveList = <LiveItemModel>[].obs;
  bool flag = false;
  List<OverlayEntry?> popupDialog = <OverlayEntry?>[];
  Box setting = GStorage.setting;

  // 获取推荐
  Future<ApiResult<List<LiveItemModel>>> queryLiveList(String type) async {
    if (_isLoading) {
      return const ApiFailure(
        kind: ApiFailureKind.unknown,
        message: 'Loading in progress',
      );
    }
    _isLoading = true;
    try {
      if (type == 'init') {
        _currentPage = 1;
      }
      final res = await LiveHttp.liveList(pn: _currentPage);
      if (res case ApiSuccess<List<LiveItemModel>>(:final data)) {
        if (type == 'init') {
          liveList.value = data;
        } else if (type == 'onLoad') {
          liveList.addAll(data);
        }
        _currentPage += 1;
      }
      return res;
    } finally {
      _isLoading = false;
    }
  }

  // 下拉刷新
  Future<void> onRefresh() async {
    await queryLiveList('init');
  }

  // 上拉加载
  Future<void> onLoad() async {
    await queryLiveList('onLoad');
  }

  // 返回顶部并刷新
  void animateToTop() {
    scrollController.animToTop();
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/live.dart';
import 'package:pilipalaz/models/live/area.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/utils/extension.dart';
import 'package:pilipalaz/utils/storage.dart';

class LiveController extends GetxController {
  final ScrollController scrollController = ScrollController();
  int count = 12;
  int _currentPage = 1;
  int get currentPage => _currentPage;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  RxInt crossAxisCount = 2.obs;
  final RxList<LiveItemModel> liveList = <LiveItemModel>[].obs;
  final RxList<LiveItemModel> followingList = <LiveItemModel>[].obs;
  final RxBool isFollowingLoading = false.obs;

  final RxList<LiveAreaItemModel> areaList = <LiveAreaItemModel>[].obs;
  final RxInt selectedAreaId = 0.obs;
  final RxBool isAreaSwitching = false.obs;

  CancelToken? _feedCancelToken;
  CancelToken? _areaCancelToken;
  int _feedGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    areaList.assignAll(LiveAreaItemModel.defaultAreas);
    unawaited(fetchAreaList());
    unawaited(fetchFollowingList());
  }

  Future<void> fetchFollowingList() async {
    dynamic userInfo;
    try {
      userInfo = GStorage.userInfo.get('userInfoCache');
    } catch (_) {
      userInfo = null;
    }
    if (userInfo == null) {
      followingList.clear();
      return;
    }
    isFollowingLoading.value = true;
    try {
      final res = await LiveHttp.followingLiveList();
      if (res case ApiSuccess<List<LiveItemModel>>(:final data)) {
        followingList.assignAll(data);
      }
    } catch (_) {
      // 关注流静默容灾，不影响主列表
    } finally {
      isFollowingLoading.value = false;
    }
  }

  Future<void> fetchAreaList() async {
    _areaCancelToken?.cancel('area_list_refresh');
    _areaCancelToken = CancelToken();
    try {
      final res = await LiveHttp.liveAreaList(cancelToken: _areaCancelToken);
      if (res case ApiSuccess<List<LiveAreaItemModel>>(:final data)) {
        if (data.isNotEmpty) {
          areaList.assignAll(data);
        }
      }
    } catch (_) {}
  }

  Future<void> switchArea(int areaId) async {
    if (selectedAreaId.value == areaId && !isAreaSwitching.value) return;
    selectedAreaId.value = areaId;
    _feedCancelToken?.cancel('area_switched');
    _feedCancelToken = CancelToken();
    final gen = ++_feedGeneration;

    _currentPage = 1;
    isAreaSwitching.value = true;
    liveList.clear();
    try {
      await _fetchFeedByArea(gen, type: 'init');
    } finally {
      if (gen == _feedGeneration) {
        isAreaSwitching.value = false;
      }
    }
  }

  Future<ApiResult<List<LiveItemModel>>> queryLiveList(String type) async {
    if (_isLoading) {
      return const ApiFailure(
        kind: ApiFailureKind.unknown,
        message: 'Loading in progress',
      );
    }
    _isLoading = true;
    if (type == 'init') {
      _currentPage = 1;
    }
    final gen = _feedGeneration;
    try {
      return await _fetchFeedByArea(gen, type: type);
    } finally {
      _isLoading = false;
    }
  }

  Future<ApiResult<List<LiveItemModel>>> _fetchFeedByArea(
    int gen, {
    required String type,
  }) async {
    final areaId = selectedAreaId.value;
    final res = (areaId > 0)
        ? await LiveHttp.areaLiveList(
            parentAreaId: areaId,
            page: _currentPage,
            cancelToken: _feedCancelToken,
          )
        : await LiveHttp.liveList(pn: _currentPage);

    if (gen != _feedGeneration) {
      return const ApiFailure(
        kind: ApiFailureKind.cancelled,
        message: 'Area switched away',
      );
    }

    if (res case ApiSuccess<List<LiveItemModel>>(:final data)) {
      if (type == 'init') {
        liveList.assignAll(data);
      } else if (type == 'onLoad') {
        liveList.addAll(data);
      }
      _currentPage += 1;
    }
    return res;
  }

  Future<void> onRefresh() async {
    await Future.wait([fetchFollowingList(), queryLiveList('init')]);
  }

  Future<void> onLoad() async {
    await queryLiveList('onLoad');
  }

  void animateToTop() {
    scrollController.animToTop();
  }

  @override
  void onClose() {
    _feedCancelToken?.cancel('controller_closed');
    _feedCancelToken = null;
    _areaCancelToken?.cancel('controller_closed');
    _areaCancelToken = null;
    scrollController.dispose();
    super.onClose();
  }
}

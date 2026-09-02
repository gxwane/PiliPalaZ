import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/user/history.dart';

class HistorySearchController extends GetxController {
  final ScrollController scrollController = ScrollController();
  Rx<TextEditingController> controller = TextEditingController().obs;
  final FocusNode searchFocusNode = FocusNode();
  RxString searchKeyWord = ''.obs;
  String hintText = '搜索';
  RxString loadingStatus = 'init'.obs;
  RxString loadingText = '加载中...'.obs;
  late int mid;
  RxString uname = ''.obs;
  int pn = 1;
  int count = 0;
  RxList<HisListItem> historyList = <HisListItem>[].obs;
  RxBool enableMultiple = false.obs;

  // 清空搜索
  void onClear() {
    if (searchKeyWord.value.isNotEmpty && controller.value.text != '') {
      controller.value.clear();
      searchKeyWord.value = '';
    } else {
      Get.back();
    }
  }

  void onChange(value) {
    searchKeyWord.value = value;
  }

  //  提交搜索内容
  void submit() {
    loadingStatus.value = 'loading';
    loadingText.value = '加载中...';
    pn = 1;
    searchHistories();
  }

  // 搜索视频
  Future searchHistories({type = 'init'}) async {
    if (type == 'onLoad' && loadingText.value == '没有更多了') {
      return;
    }
    var res = await UserHttp.searchHistory(
      pn: pn,
      keyword: controller.value.text,
    );
    if (res case ApiSuccess<HistoryData>(:final data)) {
      if (type == 'init' && pn == 1) {
        historyList.value = data.list ?? <HisListItem>[];
      } else {
        historyList.addAll(data.list ?? <HisListItem>[]);
      }
      historyList.refresh();
      // count = res['data'].page['total'];
      // if (historyList.length == count) {
      if (data.hasMore != true){
        loadingText.value = '没有更多了';
      }
    }
    loadingStatus.value = 'finish';
    // return res;
  }

  onLoad() {
    pn += 1;
    searchHistories(type: 'onLoad');
  }

  Future delHistory(kid, business) async {
    String resKid = 'archive_$kid';
    if (business == 'live') {
      resKid = 'live_$kid';
    } else if (business.contains('article')) {
      resKid = 'article_$kid';
    }

    var res = await UserHttp.delHistory(resKid);
    if (res is ApiSuccess<void>) {
      historyList.removeWhere((e) => e.kid == kid);
      SmartDialog.showToast('已删除');
    } else {
      SmartDialog.showToast((res as ApiFailure<void>).message);
    }
    loadingStatus.value = 'finish';
  }
}

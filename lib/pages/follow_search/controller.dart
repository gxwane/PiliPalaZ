import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/member.dart';
import 'package:pilipalaz/http/api_result.dart';

import '../../models/follow/result.dart';

class FollowSearchController extends GetxController {
  Rx<TextEditingController> controller = TextEditingController().obs;
  final FocusNode searchFocusNode = FocusNode();
  RxString searchKeyWord = ''.obs;
  String hintText = '搜索';
  RxString loadingStatus = 'init'.obs;
  late int mid = 1;
  RxString uname = ''.obs;
  int ps = 20;
  int pn = 1;
  RxList<FollowItemModel> followList = <FollowItemModel>[].obs;
  RxInt total = 0.obs;

  @override
  void onInit() {
    super.onInit();
    mid = int.parse(Get.parameters['mid']!);
  }

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
    searchFollow();
  }

  Future<ApiResult<FollowDataModel>> searchFollow({type = 'init'}) async {
    if (controller.value.text == '') {
      followList.clear();
      total.value = 0;
      return ApiSuccess<FollowDataModel>(
        FollowDataModel(total: 0, list: <FollowItemModel>[]),
      );
    }
    if (type == 'init') {
      pn = 1;
    }
    var res = await MemberHttp.getfollowSearch(
      mid: mid,
      ps: ps,
      pn: pn,
      name: controller.value.text,
    );
    if (res case ApiSuccess<FollowDataModel>(:final data)) {
      if (type == 'init') {
        followList.value = data.list ?? <FollowItemModel>[];
      } else {
        followList.addAll(data.list ?? <FollowItemModel>[]);
      }
      total.value = data.total ?? 0;
      pn += 1;
    }
    return res;
  }

  void onLoad() {
    searchFollow(type: 'onLoad');
  }
}

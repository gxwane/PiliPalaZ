import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/member.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/member/seasons.dart';

class MemberSeasonController extends GetxController {
  final ScrollController scrollController = ScrollController();
  late int mid;
  late int seasonId;
  int pn = 1;
  int ps = 30;
  int count = 0;
  Rx<SeasonMeta> meta = SeasonMeta(name: "Ta的合集", total: 0).obs;
  RxList<MemberArchiveItem> seasonsList = <MemberArchiveItem>[].obs;
  late Map page;

  @override
  void onInit() {
    super.onInit();
    mid = int.parse(Get.parameters['mid']!);
    seasonId = int.parse(Get.parameters['seasonId']!);
  }

  // 获取合集详情
  Future<ApiResult<MemberSeasonsList>> getSeasonDetail(type) async {
    if (type == 'onRefresh') {
      pn = 1;
    }
    var res = await MemberHttp.getSeasonDetail(
      mid: mid,
      seasonId: seasonId,
      pn: pn,
      ps: ps,
      sortReverse: false,
    );
    if (res case ApiSuccess<MemberSeasonsList>(:final data)) {
      seasonsList.addAll(data.archives ?? <MemberArchiveItem>[]);
      page = data.page ?? <String, dynamic>{};
      pn += 1;
      if (data.meta != null) {
        meta.value = data.meta!;
      }
    }
    return res;
  }

  // 上拉加载
  Future onLoad() async {
    getSeasonDetail('onLoad');
  }

  Future onRefresh() async {
    getSeasonDetail('onRefresh');
  }
}

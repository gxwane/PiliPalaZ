import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/fan.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/fans/result.dart';
import 'package:pilipalaz/utils/storage.dart';

class FansController extends GetxController {
  Box userInfoCache = GStorage.userInfo;
  int pn = 1;
  int ps = 20;
  int total = 0;
  RxList<FansItemModel> fansList = <FansItemModel>[].obs;
  late int? mid;
  late String? name;
  var userInfo;
  RxString loadingText = '加载中...'.obs;
  RxBool isOwner = false.obs;

  @override
  void onInit() {
    super.onInit();
    userInfo = userInfoCache.get('userInfoCache');
    mid = Get.parameters['mid'] != null
        ? int.parse(Get.parameters['mid']!)
        : userInfo?.mid;
    isOwner.value = mid == userInfo?.mid;
    name = Get.parameters['name'] ?? userInfo?.uname;
  }

  Future<ApiResult<FansDataModel>> queryFans(type) async {
    if (type == 'init' || type == 'refresh') {
      pn = 1;
      loadingText.value == '加载中...';
    }
    if (loadingText.value == '没有更多了') {
      return ApiSuccess<FansDataModel>(
        FansDataModel(total: total, list: fansList.toList()),
      );
    }
    var res = await FanHttp.fans(
      vmid: mid,
      pn: pn,
      ps: ps,
      orderType: 'attention',
    );
    if (res case ApiSuccess<FansDataModel>(:final data)) {
      final list = data.list ?? <FansItemModel>[];
      if (type == 'init') {
        fansList.value = list;
        total = data.total ?? 0;
      } else if (type == 'onLoad') {
        fansList.addAll(list);
      }
      print('fansList: ${fansList.length}, total: $total');
      if ((pn == 1 && total < ps) || list.isEmpty) {
        loadingText.value = '没有更多了';
      }
      pn += 1;
      if (total > ps && pn == 2) {
        queryFans('onLoad');
      }
    } else {
      SmartDialog.showToast((res as ApiFailure<FansDataModel>).message);
    }
    return res;
  }
}

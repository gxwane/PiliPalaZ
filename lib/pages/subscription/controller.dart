import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/user/info.dart';
import 'package:pilipalaz/utils/storage.dart';

import '../../models/user/sub_folder.dart';

class SubController extends GetxController {
  final ScrollController scrollController = ScrollController();
  Rx<SubFolderModelData> subFolderData = SubFolderModelData().obs;
  Box userInfoCache = GStorage.userInfo;
  UserInfoData? userInfo;
  int currentPage = 1;
  int pageSize = 20;
  RxBool hasMore = true.obs;

  Future<ApiResult<SubFolderModelData>> querySubFolder({type = 'init'}) async {
    userInfo = userInfoCache.get('userInfoCache');
    if (userInfo == null) {
      return const ApiFailure<SubFolderModelData>(
        kind: ApiFailureKind.apiRejected,
        message: '账号未登录',
        endpoint: 'subscription.folders',
      );
    }
    var res = await UserHttp.userSubFolder(
      pn: currentPage,
      ps: pageSize,
      mid: userInfo!.mid!,
    );
    if (res case ApiSuccess<SubFolderModelData>(:final data)) {
      if (type == 'init') {
        subFolderData.value = data;
      } else {
        if (data.list?.isNotEmpty == true) {
          subFolderData.value.list!.addAll(data.list!);
          subFolderData.update((val) {});
        }
      }
      currentPage++;
    } else {
      SmartDialog.showToast((res as ApiFailure<SubFolderModelData>).message);
    }
    return res;
  }

  Future onLoad() async {
    querySubFolder(type: 'onload');
  }

  // 取消订阅
  Future<void> cancelSub(SubFolderItemData subFolderItem) async {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('确定取消订阅吗？'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              var res = await UserHttp.cancelSub(
                  id: subFolderItem.id!, type: subFolderItem.type!);
              if (res is ApiSuccess<void>) {
                subFolderData.value.list!.remove(subFolderItem);
                subFolderData.update((val) {});
                SmartDialog.showToast('取消订阅成功');
              } else {
                SmartDialog.showToast((res as ApiFailure<void>).message);
              }
              Get.back();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

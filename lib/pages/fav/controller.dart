import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/user/fav_folder.dart';
import 'package:pilipalaz/models/user/info.dart';
import 'package:pilipalaz/utils/storage.dart';

class FavController extends GetxController {
  final ScrollController scrollController = ScrollController();
  Rx<FavFolderData> favFolderData = FavFolderData().obs;
  Box userInfoCache = GStorage.userInfo;
  UserInfoData? userInfo;
  int currentPage = 1;
  int pageSize = 10;
  RxBool hasMore = true.obs;

  Future<ApiResult<FavFolderData>?> queryFavFolder({type = 'init'}) async {
    userInfo = userInfoCache.get('userInfoCache');
    if (userInfo == null) {
      return const ApiFailure<FavFolderData>(
        kind: ApiFailureKind.apiRejected,
        message: '账号未登录',
        endpoint: 'favorite.folders',
      );
    }
    if (!hasMore.value) {
      return null;
    }
    var res = await UserHttp.userfavFolder(
      pn: currentPage,
      ps: pageSize,
      mid: userInfo!.mid!,
    );
    if (res case ApiSuccess<FavFolderData>(:final data)) {
      if (type == 'init') {
        favFolderData.value = data;
      } else {
        if (data.list?.isNotEmpty == true) {
          favFolderData.value.list!.addAll(data.list!);
          favFolderData.update((val) {});
        }
      }
      hasMore.value = data.hasMore ?? false;
      currentPage++;
      if (hasMore.value && type == 'init') {
        queryFavFolder(type: 'onload');
      }
    } else {
      SmartDialog.showToast((res as ApiFailure<FavFolderData>).message);
    }
    return res;
  }

  Future onLoad() async {
    queryFavFolder(type: 'onload');
  }
}

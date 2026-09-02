import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/models/user/fav_detail.dart';
import 'package:pilipalaz/models/user/fav_folder.dart';

class FavDetailController extends GetxController {
  FavFolderItemData? item;
  Rx<FavDetailData> favDetailData = FavDetailData().obs;

  int? mediaId;
  late String heroTag;
  int currentPage = 1;
  bool isLoadingMore = false;
  RxMap favInfo = {}.obs;
  RxList favList = [].obs;
  RxString loadingText = '加载中...'.obs;
  int mediaCount = 0;

  @override
  void onInit() {
    item = Get.arguments;
    if (Get.parameters.keys.isNotEmpty) {
      mediaId = int.parse(Get.parameters['mediaId']!);
      heroTag = Get.parameters['heroTag']!;
    }
    super.onInit();
  }

  Future<ApiResult<FavDetailData>?> queryUserFavFolderDetail({
    type = 'init',
  }) async {
    if (type == 'onLoad' && favList.length >= mediaCount) {
      loadingText.value = '没有更多了';
      return null;
    }
    isLoadingMore = true;
    var res = await UserHttp.userFavFolderDetail(
      pn: currentPage,
      ps: 20,
      mediaId: mediaId!,
    );
    if (res case ApiSuccess<FavDetailData>(:final data)) {
      favInfo.value = Map<dynamic, dynamic>.from(data.info ?? const {});
      if (currentPage == 1 && type == 'init') {
        favList.value = data.medias ?? <FavDetailItemData>[];
        mediaCount = (data.info?['media_count'] as num?)?.toInt() ?? 0;
      } else if (type == 'onLoad') {
        favList.addAll(data.medias ?? <FavDetailItemData>[]);
      }
      if (favList.length >= mediaCount) {
        loadingText.value = '没有更多了';
      }
    }
    currentPage += 1;
    isLoadingMore = false;
    return res;
  }

  onCancelFav(int id) async {
    var result = await VideoHttp.favVideo(
      aid: id,
      addIds: '',
      delIds: mediaId.toString(),
    );
    if (result is ApiSuccess<void>) {
      List dataList = favList;
      for (var i in dataList) {
        if (i.id == id) {
          dataList.remove(i);
          break;
        }
      }
      SmartDialog.showToast('取消收藏');
    }
  }

  onLoad() {
    queryUserFavFolderDetail(type: 'onLoad');
  }
}

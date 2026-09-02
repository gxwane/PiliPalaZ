import 'package:get/get.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';

import '../../models/user/sub_detail.dart';
import '../../models/user/sub_folder.dart';

class SubDetailController extends GetxController {
  late SubFolderItemData item;

  late int id;
  late String heroTag;
  int currentPage = 1;
  bool isLoadingMore = false;
  Rx<DetailInfo> subInfo = DetailInfo().obs;
  RxList<SubDetailMediaItem> subList = <SubDetailMediaItem>[].obs;
  RxString loadingText = '加载中...'.obs;
  int mediaCount = 0;
  RxInt playCount = 0.obs;

  @override
  void onInit() {
    item = Get.arguments;
    if (playCount.value == 0) playCount.value = item.viewCount!;
    if (Get.parameters.keys.isNotEmpty) {
      id = int.parse(Get.parameters['id']!);
      heroTag = Get.parameters['heroTag']!;
    }
    super.onInit();
  }

  Future<ApiResult<SubDetailModelData>?> queryUserSubFolderDetail({
    type = 'init',
  }) async {
    if (type == 'onLoad' && subList.length >= mediaCount) {
      loadingText.value = '没有更多了';
      return null;
    }
    isLoadingMore = true;
    late ApiResult<SubDetailModelData> res;
    if (item.type! == 11) {
      res = await UserHttp.favResourceList(
        id: id,
        ps: 20,
        pn: currentPage,
      );
    } else {
      res = await UserHttp.favSeasonList(// item.type! == 21
        id: id,
        ps: 20,
        pn: currentPage,
      );
    }
    if (res case ApiSuccess<SubDetailModelData>(:final data)) {
      subInfo.value = data.info ?? DetailInfo();
      if (currentPage == 1 && type == 'init') {
        subList.value = data.medias ?? <SubDetailMediaItem>[];
        mediaCount = data.info?.mediaCount ?? 0;
        if (item.type == 11) {
          playCount.value =
              (data.info?.cntInfo?['play'] as num?)?.toInt() ?? 0;
        }
      } else if (type == 'onLoad') {
        subList.addAll(data.medias ?? <SubDetailMediaItem>[]);
      }
      if (subList.length >= mediaCount) {
        loadingText.value = '没有更多了';
      }
    }
    currentPage += 1;
    isLoadingMore = false;
    return res;
  }

  onLoad() {
    queryUserSubFolderDetail(type: 'onLoad');
  }
}

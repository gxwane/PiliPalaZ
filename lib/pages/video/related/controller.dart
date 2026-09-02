import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/http/api_result.dart';
import '../../../../models/model_hot_video_item.dart';

class RelatedController extends GetxController {
  // 视频aid
  String bvid = Get.parameters['bvid'] ?? "";
  // 推荐视频列表
  RxList relatedVideoList = <HotVideoItemModel>[].obs;

  Future<ApiResult<List<HotVideoItemModel>>> queryRelatedVideo() async {
    return VideoHttp.relatedVideoList(bvid: bvid).then((value) {
      if (value case ApiSuccess<List<HotVideoItemModel>>(:final data)) {
        relatedVideoList.value = data;
      } else {
        SmartDialog.showToast(
          (value as ApiFailure<List<HotVideoItemModel>>).message,
        );
      }
      return value;
    });
  }
}

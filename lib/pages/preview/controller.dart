import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PreviewController extends GetxController {
  RxInt initialPage = 0.obs;
  RxInt currentPage = 1.obs;
  RxList imgList = [].obs;
  String currentImgUrl = '';

  // 图片分享
  Future<void> onShareImg() async {
    SmartDialog.showLoading();
    var response = await Dio().get(
      imgList[initialPage.value],
      options: Options(responseType: ResponseType.bytes),
    );
    final temp = await getTemporaryDirectory();
    SmartDialog.dismiss();
    String imgName =
        "PiliPalaZ_pic_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.').first}.jpg";
    var path = '${temp.path}/$imgName';
    File(path).writeAsBytesSync(response.data);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(path)],
        subject: imgList[initialPage.value],
      ),
    );
  }

  void onChange(int index) {
    initialPage.value = index;
    currentPage.value = index + 1;
    currentImgUrl = imgList[index];
  }
}

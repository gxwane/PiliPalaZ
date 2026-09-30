import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/utils/feed_back.dart';
import 'package:pilipalaz/utils/utils.dart';

abstract final class LiveNavHelper {
  static void navigateToAnchorMember(
    BuildContext context,
    int? mid,
    String? face,
  ) {
    feedBack();
    if (mid == null || mid <= 0) {
      SmartDialog.showToast('未能获取主播信息');
      return;
    }
    final heroTag = Utils.makeHeroTag(mid);
    Get.toNamed(
      '/member?mid=$mid',
      arguments: {'face': face ?? '', 'heroTag': heroTag},
    );
  }
}

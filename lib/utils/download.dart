import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pilipalaz/services/gallery_permission_policy.dart';
import 'package:saver_gallery/saver_gallery.dart';

class DownloadUtils {
  static Future<bool> checkPermissionDependOnSdkInt(
    BuildContext context,
  ) async {
    final platform = defaultTargetPlatform;
    int? androidSdk;
    if (platform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      androidSdk = androidInfo.version.sdkInt;
    }

    final kind = galleryPermissionFor(
      platform: platform,
      androidSdk: androidSdk,
    );
    switch (kind) {
      case GalleryPermissionKind.none:
        return true;
      case GalleryPermissionKind.legacyStorage:
        final status = await Permission.storage.request();
        if (status.isGranted) {
          return true;
        }
        if (status.isPermanentlyDenied && context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('提示'),
                content: const Text('存储权限未授权'),
                actions: [
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('去授权'),
                  ),
                ],
              );
            },
          );
        }
        return false;
      case GalleryPermissionKind.photosAddOnly:
        return (await Permission.photosAddOnly.request()).isGranted;
    }
  }

  static Future<bool> downloadImg(
    BuildContext context,
    String imgUrl, {
    String imgType = 'cover',
  }) async {
    try {
      if (!await checkPermissionDependOnSdkInt(context)) {
        return false;
      }
      SmartDialog.showLoading(msg: '正在下载原图');
      var response = await Dio().get(
        imgUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在保存图片至图库');
      String picName =
          "${imgType}_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.').first}";
      final SaveResult result = await SaverGallery.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        fileName: picName,
        // extension: 'jpg',
        // 保存到 PiliPalaZ 文件夹
        androidRelativePath: "Pictures/PiliPalaZ",
        skipIfExists: false,
      );
      SmartDialog.dismiss();
      if (result.isSuccess) {
        await SmartDialog.showToast('「$picName」已保存 ');
      } else {
        await SmartDialog.showToast('保存失败，${result.errorMessage}');
      }
      return true;
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast(err.toString());
      return false;
    }
  }
}

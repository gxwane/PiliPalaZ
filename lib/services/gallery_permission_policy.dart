import 'package:flutter/foundation.dart';

enum GalleryPermissionKind { none, legacyStorage, photosAddOnly }

GalleryPermissionKind galleryPermissionFor({
  required TargetPlatform platform,
  int? androidSdk,
}) {
  if (platform == TargetPlatform.iOS) {
    return GalleryPermissionKind.photosAddOnly;
  }
  if (platform == TargetPlatform.android) {
    if (androidSdk == null) {
      throw ArgumentError.notNull('androidSdk');
    }
    return androidSdk < 29
        ? GalleryPermissionKind.legacyStorage
        : GalleryPermissionKind.none;
  }
  return GalleryPermissionKind.none;
}

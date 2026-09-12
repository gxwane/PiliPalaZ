import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/gallery_permission_policy.dart';

void main() {
  group('galleryPermissionFor', () {
    for (final sdk in <int>[24, 28]) {
      test('uses legacy storage permission on Android SDK $sdk', () {
        expect(
          galleryPermissionFor(
            platform: TargetPlatform.android,
            androidSdk: sdk,
          ),
          GalleryPermissionKind.legacyStorage,
        );
      });
    }

    for (final sdk in <int>[29, 32, 33, 36]) {
      test('does not request media permission on Android SDK $sdk', () {
        expect(
          galleryPermissionFor(
            platform: TargetPlatform.android,
            androidSdk: sdk,
          ),
          GalleryPermissionKind.none,
        );
      });
    }

    test('uses add-only Photos permission on iOS', () {
      expect(
        galleryPermissionFor(platform: TargetPlatform.iOS),
        GalleryPermissionKind.photosAddOnly,
      );
    });

    test('does not request gallery permission on unsupported platforms', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          galleryPermissionFor(platform: platform),
          GalleryPermissionKind.none,
        );
      }
    });

    test('requires an SDK level for Android', () {
      expect(
        () => galleryPermissionFor(platform: TargetPlatform.android),
        throwsArgumentError,
      );
    });
  });
}

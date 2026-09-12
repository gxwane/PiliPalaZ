import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const retainedPermissions = <String>{
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.WAKE_LOCK',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.REQUEST_INSTALL_PACKAGES',
    'android.permission.WRITE_SETTINGS',
  };
  const removedPermissions = <String>{
    'android.permission.ACCESS_WIFI_STATE',
    'android.permission.READ_MEDIA_IMAGES',
    'android.permission.READ_MEDIA_AUDIO',
    'android.permission.READ_MEDIA_VIDEO',
  };

  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final uncommentedManifest = manifest.replaceAll(
    RegExp(r'<!--[\s\S]*?-->'),
    '',
  );
  final permissionTags = RegExp(
    r'<uses-permission\b[^>]*>',
    multiLine: true,
  ).allMatches(uncommentedManifest).map((match) => match.group(0)!);
  final declaredPermissions = permissionTags
      .map(
        (tag) =>
            RegExp(r'android:name\s*=\s*"([^"]+)"').firstMatch(tag)!.group(1)!,
      )
      .toSet();

  test('main Android manifest declares only the approved permissions', () {
    expect(declaredPermissions, retainedPermissions);
    for (final permission in removedPermissions) {
      expect(declaredPermissions, isNot(contains(permission)));
    }
  });

  test('legacy storage permissions stop at Android 9', () {
    for (final permission in <String>[
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
    ]) {
      final tag = permissionTags.singleWhere(
        (candidate) => candidate.contains('android:name="$permission"'),
      );
      expect(tag, contains('android:maxSdkVersion="28"'));
    }
  });

  test('Android security, playback, update, and identity contracts remain', () {
    final buildGradle = File('android/app/build.gradle').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(manifest, contains('androidx.core.content.FileProvider'));
    expect(manifest, contains(r'${applicationId}.fileprovider'));
    expect(
      declaredPermissions,
      contains('android.permission.REQUEST_INSTALL_PACKAGES'),
    );
    expect(
      buildGradle,
      contains('applicationId = "io.github.gxwane.pilipalaz"'),
    );
  });
}

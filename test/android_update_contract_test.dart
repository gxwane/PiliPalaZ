import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android update bridge uses DownloadManager and a private FileProvider',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final channel = File(
        'android/app/src/main/kotlin/io/github/gxwane/pilipalaz/'
        'AppUpdateChannel.kt',
      ).readAsStringSync();
      final paths = File(
        'android/app/src/main/res/xml/app_update_file_paths.xml',
      ).readAsStringSync();
      final dartBridge = File(
        'lib/services/app_update_platform.dart',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
      expect(manifest, contains('androidx.core.content.FileProvider'));
      expect(manifest, contains(r'${applicationId}.fileprovider'));
      expect(paths, contains('external-files-path'));
      expect(paths, contains('Download/updates/'));

      expect(channel, contains('DownloadManager'));
      expect(channel, contains('VISIBILITY_VISIBLE_NOTIFY_COMPLETED'));
      expect(channel, contains('setAllowedOverMetered(true)'));
      expect(channel, contains('setAllowedOverRoaming(false)'));
      expect(channel, contains('canRequestPackageInstalls'));
      expect(channel, contains('ACTION_MANAGE_UNKNOWN_APP_SOURCES'));
      expect(channel, contains('FileProvider.getUriForFile'));

      const methodChannelName = 'io.github.gxwane.pilipalaz/app_update';
      expect(channel, contains(methodChannelName));
      expect(dartBridge, contains(methodChannelName));
      for (final method in <String>[
        'enqueue',
        'query',
        'cancel',
        'sha256',
        'canInstallPackages',
        'openInstallSettings',
        'install',
      ]) {
        expect(channel, contains('"$method"'));
        expect(dartBridge, contains("'$method'"));
      }
    },
  );
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orientation control uses Flutter APIs and an app-owned bridge', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();
    final fullscreen = File(
      'lib/plugin/pl_player/utils/fullscreen.dart',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/io/github/gxwane/pilipalaz/'
      'MainActivity.kt',
    ).readAsStringSync();
    final orientationChannel = File(
      'android/app/src/main/kotlin/io/github/gxwane/pilipalaz/'
      'OrientationChannel.kt',
    );

    expect(pubspec, isNot(contains('auto_orientation_v2:')));
    expect(lockfile, isNot(contains('\n  auto_orientation_v2:')));

    for (final path in <String>[
      'lib/plugin/pl_player/utils/fullscreen.dart',
      'lib/pages/video/view.dart',
      'lib/pages/setting/style_setting.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('package:auto_orientation')),
        reason: '$path must not depend on an orientation plugin',
      );
    }

    expect(orientationChannel.existsSync(), isTrue);
    final nativeBridge = orientationChannel.readAsStringSync();
    const channelName = 'io.github.gxwane.pilipalaz/orientation';
    expect(fullscreen, contains(channelName));
    expect(nativeBridge, contains(channelName));
    expect(fullscreen, contains("'setLandscapeSensor'"));
    expect(nativeBridge, contains('"setLandscapeSensor"'));
    expect(fullscreen, contains("'setFullSensor'"));
    expect(nativeBridge, contains('"setFullSensor"'));
    expect(
      nativeBridge,
      contains('ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE'),
    );
    expect(
      nativeBridge,
      contains('ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR'),
    );
    expect(mainActivity, contains('OrientationChannel(this, flutterEngine)'));
    expect(fullscreen, contains('SystemChrome.setPreferredOrientations'));
  });

  test('root analysis excludes the standalone fl_pip example app', () {
    final analysisOptions = File('analysis_options.yaml').readAsStringSync();

    expect(
      analysisOptions,
      contains('packages/fl_pip/example/**'),
      reason:
          'the example has its own dependency graph and is not part of the app',
    );
  });
}

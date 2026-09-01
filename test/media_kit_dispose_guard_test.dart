import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vendored media_kit_video guards callbacks after disposal', () {
    final android = File(
      'packages/media_kit_video/lib/src/video_controller/'
      'android_video_controller/real.dart',
    ).readAsStringSync();
    final native = File(
      'packages/media_kit_video/lib/src/video_controller/'
      'native_video_controller/real.dart',
    ).readAsStringSync();

    expect(android, contains('var _disposed = false;'));
    expect(android, contains('if (_disposed)'));
    expect(android, contains('_disposed = true;'));
    expect(native, contains('var _disposed = false;'));
    expect(native, contains('if (_disposed ||'));
    expect(native, contains('_disposed = true;'));
  });
}

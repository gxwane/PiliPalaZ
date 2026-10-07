import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BAC-20: Tablet Landscape Cinema Viewport and Conditional SafeArea Tests', () {
    test(
      'Dual column layout isolates offline black cinema viewport and online theme surface',
      () {
        final rawCode = File('lib/pages/video/view.dart').readAsStringSync();
        final normalizedCode = rawCode.replaceAll(RegExp(r'\s+'), ' ');

        // 1. Conditional Body/Scaffold background
        expect(
          normalizedCode.contains(
            'videoDetailController.isOffline ? Colors.black : Theme.of(context).colorScheme.surface',
          ),
          isTrue,
          reason:
              'Scaffold background must conditionally use Colors.black for offline and surface for online',
        );

        // 2. Conditional outer SafeArea
        expect(
          normalizedCode.contains(
            '!videoDetailController.isOffline && !removeSafeArea',
          ),
          isTrue,
          reason:
              'Outer SafeArea left/right must be disabled for offline mode to allow cinema black extension',
        );

        // 3. Offline left pane is pure black cinema viewport with clamped responsive dimensions
        expect(
          normalizedCode.contains(
            'width: leftWidth, height: safeConstraints.maxHeight, color: Colors.black',
          ),
          isTrue,
          reason:
              'Offline landscape left column container must be Colors.black to eliminate white letterboxes',
        );

        // 4. Offline right pane encapsulates theme surface and PageStorageKey
        expect(
          normalizedCode.contains(
                "PageStorageKey<String>( '离线简介\${videoDetailController.bvid}', )",
              ) ||
              normalizedCode.contains("'离线简介\${videoDetailController.bvid}'"),
          isTrue,
          reason:
              'Offline right pane must encapsulate Theme surface and PageStorageKey',
        );
      },
    );

    test(
      'Single Scaffold nullifies AppBar and omits Expanded in phone landscape mode to prevent 24px overflow',
      () {
        final rawCode = File('lib/pages/video/view.dart').readAsStringSync();
        final code = rawCode.replaceAll('\r\n', '\n');

        // 1. Conditional AppBar
        expect(
          code.contains('_buildAppBar') &&
              code.contains('Orientation.landscape') &&
              code.contains('ScreenUtils.isTablet'),
          isTrue,
          reason:
              'Scaffold AppBar must be nullified in landscape mode to prevent taking status bar height from body',
        );

        // 2. Conditional Expanded
        expect(
          code.contains(
            'if (MediaQuery.orientationOf(context) != Orientation.landscape)\n          Expanded(',
          ),
          isTrue,
          reason:
              'Expanded tab view must be omitted in landscape mode to prevent RenderFlex overflow',
        );
      },
    );
  });
}

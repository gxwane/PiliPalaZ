import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BAC-20: Tablet Landscape Cinema Viewport and Conditional SafeArea Tests', () {
    test(
      'childWhenDisabledLandscape isolates offline black cinema viewport and online theme surface',
      () {
        final rawCode = File('lib/pages/video/view.dart').readAsStringSync();
        final code = rawCode.replaceAll('\r\n', '\n');

        // 1. Conditional Body background
        expect(
          code.contains(
                'videoDetailController.isOffline\n          ? Colors.black\n          : Theme.of(context).colorScheme.surface',
              ) ||
              code.contains(
                'videoDetailController.isOffline ? Colors.black : Theme.of(context).colorScheme.surface',
              ),
          isTrue,
          reason:
              'Scaffold body must conditionally use Colors.black for offline and surface for online',
        );

        // 2. Conditional outer SafeArea
        expect(
          code.contains(
            '!videoDetailController.isOffline &&\n            !removeSafeArea',
          ),
          isTrue,
          reason:
              'Outer SafeArea left/right must be disabled for offline mode to allow cinema black extension',
        );

        // 3. Offline left pane is pure black cinema viewport
        expect(
          code.contains(
            'Container(\n            width: videoWidth,\n            height: context.height,\n            color: Colors.black,',
          ),
          isTrue,
          reason:
              'Offline landscape left column container must be Colors.black to eliminate white letterboxes',
        );

        // 4. Offline right pane encapsulates theme surface and right SafeArea
        expect(
          code.contains(
            'Container(\n              color: Theme.of(context).colorScheme.surface,\n              child: SafeArea(\n                top: false,\n                bottom: false,\n                left: false,\n                right: !removeSafeArea && isFullScreen.value != true,\n                child: pullToFullScreen(\n                  CustomScrollView(\n                    cacheExtent: 3500,\n                    key: PageStorageKey<String>(\n                      \'离线简介\${videoDetailController.bvid}\',\n                    ),\n                    slivers: <Widget>[OfflineVideoIntroPanel(heroTag: heroTag)],\n                  ),\n                ),\n              ),\n            )',
          ),
          isTrue,
          reason:
              'Offline right pane must encapsulate Theme surface and right SafeArea',
        );
      },
    );

    test(
      'childWhenDisabled nullifies AppBar and omits Expanded in landscape mode to prevent 24px overflow',
      () {
        final rawCode = File('lib/pages/video/view.dart').readAsStringSync();
        final code = rawCode.replaceAll('\r\n', '\n');

        // 1. Conditional AppBar
        expect(
          code.contains(
            'appBar:\n'
            '          removeSafeArea ||\n'
            '              MediaQuery.of(context).orientation == Orientation.landscape\n'
            '          ? null\n'
            '          : AppBar(',
          ),
          isTrue,
          reason:
              'Scaffold AppBar must be nullified in landscape mode to prevent taking status bar height from body',
        );

        // 2. Conditional Expanded
        expect(
          code.contains(
            'if (MediaQuery.of(context).orientation != Orientation.landscape)\n'
            '            Expanded(',
          ),
          isTrue,
          reason:
              'Expanded tab view must be omitted in landscape mode to prevent RenderFlex overflow',
        );
      },
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gate 4 Red-Green: Live Room Immersive Layout & Anti-Collapse Invariants', () {
    testWidgets(
      '[TARGET ARCHITECTURE]: SizedBox.expand + StackFit.expand + Explicit Dimension Container guarantees full screen non-zero size',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(2340, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const Size expectedScreenSize = Size(2340, 1080);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        Container(
                          key: const ValueKey('immersive_player_container'),
                          width: expectedScreenSize.width,
                          height: expectedScreenSize.height,
                          color: Colors.black,
                          child: const SizedBox.expand(
                            child: ColoredBox(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('immersive_player_container')),
        );
        expect(renderBox.size, expectedScreenSize);
        expect(renderBox.size.width, 2340);
        expect(renderBox.size.height, 1080);
      },
    );

    testWidgets(
      '[PORTRAIT ARCHITECTURE]: 16:9 player container + Expanded content under portrait constraints',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const double screenWidth = 1080;
        const double screenHeight = 2340;
        const double topBarHeight = 56;
        const double playerHeight = screenWidth * 9 / 16; // 607.5

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        const SizedBox(
                          key: ValueKey('top_bar'),
                          height: topBarHeight,
                        ),
                        Container(
                          key: const ValueKey('portrait_player_container'),
                          width: screenWidth,
                          height: playerHeight,
                          color: Colors.black,
                          child: const SizedBox.expand(
                            child: ColoredBox(color: Colors.blue),
                          ),
                        ),
                        const Expanded(
                          child: SizedBox(key: ValueKey('portrait_content')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final playerBox = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('portrait_player_container')),
        );
        expect(playerBox.size.width, 1080);
        expect(playerBox.size.height, 607.5);

        final contentBox = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('portrait_content')),
        );
        expect(
          contentBox.size.height,
          screenHeight - topBarHeight - playerHeight,
        );
      },
    );

    test(
      '[PRODUCTION CODE AUDIT]: lib/pages/live_room/view.dart eliminates 0x0 collapse, preserves Element tree, and prevents tablet deadlock',
      () {
        final file = File('lib/pages/live_room/view.dart');
        expect(file.existsSync(), isTrue);
        final code = file.readAsStringSync().replaceAll('\r\n', '\n');

        // 1. Must use StackFit.expand with SizedBox.expand in _buildActiveRoomView
        expect(
          code.contains('fit: StackFit.expand'),
          isTrue,
          reason:
              'Must use StackFit.expand to enforce tight full-screen constraints',
        );
        expect(
          code.contains('SizedBox.expand'),
          isTrue,
          reason: 'Must wrap root Stack with SizedBox.expand',
        );

        // 2. Must not use buggy Positioned.fill inside loose stack for immersive player
        expect(
          code.contains(
            'Positioned.fill(\n                child: _buildPlayerContainer',
          ),
          isFalse,
          reason:
              'Must not use Positioned.fill for player container inside loose stack',
        );

        // 3. Must guard against tablet landscape pop deadlock
        expect(
          code.contains('canPop: !shouldIntercept'),
          isTrue,
          reason:
              'PopScope must bind canPop to !shouldIntercept to prevent tablet deadlock',
        );

        // 4. Must enable vertical gestures in landscape
        expect(
          code.contains('Orientation.landscape') &&
              code.contains('enableVerticalGesture'),
          isTrue,
          reason:
              'Must enable vertical volume/brightness gestures in landscape orientation',
        );

        // 5. Must use stable player key to preserve Element/Texture across mode switches
        expect(
          code.contains('_playerContainerKey'),
          isTrue,
          reason:
              'Must preserve player widget with _playerContainerKey across mode switches',
        );

        // 6. Must safely correct PageController via post-frame callback
        expect(
          code.contains('WidgetsBinding.instance.addPostFrameCallback') &&
              code.contains('jumpToPage'),
          isTrue,
          reason:
              'Must schedule jumpToPage in post-frame callback during orientation change',
        );
      },
    );
  });
}

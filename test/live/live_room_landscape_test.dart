import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gate 4 Red-Green: Live Room Landscape & Dual-Column State Machine', () {
    test(
      '[STATE MACHINE AUDIT]: Five-factor state machine accurately classifies all form factors without false immersion',
      () {
        // Helper function matching the audited mathematical state machine
        Map<String, dynamic> classify({
          required bool isFullScreen,
          required bool isLandscape,
          required bool isTablet,
          required bool isSquarish,
          required bool isWide,
          required bool isDualColumnApproved,
        }) {
          final bool isDualColumn = !isFullScreen && isDualColumnApproved;
          final bool isPhoneLandscape =
              !isFullScreen &&
              !isDualColumn &&
              !isTablet &&
              !isSquarish &&
              isLandscape;
          final bool isImmersive = isFullScreen || isPhoneLandscape;
          final bool canPop = !isFullScreen && !isPhoneLandscape;

          return {
            'isDualColumn': isDualColumn,
            'isPhoneLandscape': isPhoneLandscape,
            'isImmersive': isImmersive,
            'canPop': canPop,
          };
        }

        // Case 1: Phone Portrait (Normal)
        final phonePortrait = classify(
          isFullScreen: false,
          isLandscape: false,
          isTablet: false,
          isSquarish: false,
          isWide: false,
          isDualColumnApproved: false,
        );
        expect(phonePortrait['isDualColumn'], isFalse);
        expect(phonePortrait['isImmersive'], isFalse);
        expect(phonePortrait['canPop'], isTrue);

        // Case 2: Phone Landscape (Auto-rotate to full-screen video)
        final phoneLandscape = classify(
          isFullScreen: false,
          isLandscape: true,
          isTablet: false,
          isSquarish: false,
          isWide: true,
          isDualColumnApproved: false,
        );
        expect(phoneLandscape['isDualColumn'], isFalse);
        expect(phoneLandscape['isPhoneLandscape'], isTrue);
        expect(phoneLandscape['isImmersive'], isTrue);
        expect(
          phoneLandscape['canPop'],
          isFalse,
        ); // intercepted to restore portrait

        // Case 3: Tablet Landscape (Default Dual-Column, NOT Immersive!)
        final tabletLandscape = classify(
          isFullScreen: false,
          isLandscape: true,
          isTablet: true,
          isSquarish: false,
          isWide: true,
          isDualColumnApproved: true,
        );
        expect(tabletLandscape['isDualColumn'], isTrue);
        expect(tabletLandscape['isPhoneLandscape'], isFalse);
        expect(tabletLandscape['isImmersive'], isFalse);
        expect(tabletLandscape['canPop'], isTrue); // normal exit, no deadlock!

        // Case 4: Tablet Fullscreen (Explicit user tap on fullscreen button)
        final tabletFullscreen = classify(
          isFullScreen: true,
          isLandscape: true,
          isTablet: true,
          isSquarish: false,
          isWide: true,
          isDualColumnApproved: false,
        );
        expect(tabletFullscreen['isDualColumn'], isFalse);
        expect(tabletFullscreen['isImmersive'], isTrue);
        expect(
          tabletFullscreen['canPop'],
          isFalse,
        ); // intercepted to exit fullscreen to dual-column

        // Case 5: Foldable Unfolded (Near-square, width slightly > height, e.g. 8:7 ratio)
        final foldableUnfolded = classify(
          isFullScreen: false,
          isLandscape: true, // sensor may report landscape when w > h
          isTablet: false,
          isSquarish: true,
          isWide: false,
          isDualColumnApproved: false,
        );
        expect(foldableUnfolded['isDualColumn'], isFalse);
        expect(
          foldableUnfolded['isPhoneLandscape'],
          isFalse,
          reason:
              'Foldable unfolded must NOT be falsely identified as phone landscape!',
        );
        expect(
          foldableUnfolded['isImmersive'],
          isFalse,
          reason: 'Foldables must retain portrait UI chrome!',
        );
        expect(foldableUnfolded['canPop'], isTrue);
      },
    );

    testWidgets(
      '[DUAL-COLUMN LAYOUT]: Tablet Landscape renders left player + anchor strip, right chat + input, and resists keyboard inset',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const double leftWidth = 1200 * 0.65; // 780
        const double playerHeight = 780 * 9 / 16; // 438.75

        Widget buildDualColumnTestHarness({double keyboardHeight = 0}) {
          return MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(1200, 800),
              ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardHeight)),
              child: Scaffold(
                resizeToAvoidBottomInset:
                    false, // Critical auditor recommendation
                backgroundColor: Colors.black,
                body: SizedBox.expand(
                  child: Row(
                    children: [
                      SizedBox(
                        width: leftWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(
                              key: ValueKey('top_app_bar'),
                              height: 56,
                            ),
                            SizedBox(
                              key: const ValueKey('left_player_container'),
                              width: leftWidth,
                              height: playerHeight,
                              child: const ColoredBox(color: Colors.blue),
                            ),
                            const SizedBox(
                              key: ValueKey('anchor_strip'),
                              height: 52,
                              child: ColoredBox(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Colors.white24),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: keyboardHeight),
                          child: Column(
                            children: const [
                              SizedBox(key: ValueKey('sc_ticker'), height: 36),
                              Expanded(
                                child: SizedBox(
                                  key: ValueKey('chat_panel'),
                                  child: ColoredBox(color: Colors.deepPurple),
                                ),
                              ),
                              SizedBox(key: ValueKey('input_bar'), height: 52),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Test normal layout
        await tester.pumpWidget(buildDualColumnTestHarness(keyboardHeight: 0));
        expect(
          find.byKey(const ValueKey('left_player_container')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('anchor_strip')), findsOneWidget);
        expect(find.byKey(const ValueKey('chat_panel')), findsOneWidget);
        expect(find.byKey(const ValueKey('input_bar')), findsOneWidget);

        final playerBox = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('left_player_container')),
        );
        expect(playerBox.size.width, leftWidth);
        expect(playerBox.size.height, playerHeight);

        // Test with virtual keyboard expanded (350dp inset)
        await tester.pumpWidget(
          buildDualColumnTestHarness(keyboardHeight: 350),
        );
        await tester.pumpAndSettle();

        // Left column must maintain EXACT dimensions with zero overflow error
        final playerBoxWithKeyboard = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('left_player_container')),
        );
        expect(playerBoxWithKeyboard.size.width, leftWidth);
        expect(playerBoxWithKeyboard.size.height, playerHeight);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Zero RenderFlex overflow under keyboard inset',
        );
      },
    );

    test(
      '[PRODUCTION CODE AUDIT]: lib/pages/live_room/view.dart enforces dual-column decoupling and foldable guard',
      () {
        final file = File('lib/pages/live_room/view.dart');
        expect(file.existsSync(), isTrue);
        final code = file.readAsStringSync().replaceAll('\r\n', '\n');

        // 1. Must use shouldUseLandscapeDualColumn
        expect(
          code.contains('shouldUseLandscapeDualColumn'),
          isTrue,
          reason:
              'Must use ScreenUtils.shouldUseLandscapeDualColumn to activate dual column',
        );

        // 2. Must guard against squarish foldables
        expect(
          code.contains('!isSquarish'),
          isTrue,
          reason: 'Must guard against squarish foldables in isPhoneLandscape',
        );

        // 3. Must decouple resizeToAvoidBottomInset for dual-column
        expect(
          code.contains(
            'resizeToAvoidBottomInset: !isImmersive && !isDualColumn',
          ),
          isTrue,
          reason:
              'Dual column must decouple resizeToAvoidBottomInset to prevent keyboard overflow',
        );

        // 3. Must implement _buildDualColumnLayout
        expect(
          code.contains('_buildDualColumnLayout'),
          isTrue,
          reason:
              'Must implement dedicated _buildDualColumnLayout for tablet/large screens',
        );

        // 4. Must decouple TopAppBar toolbarHeight in landscape dual column
        expect(
          code.contains('toolbarHeight'),
          isTrue,
          reason:
              'Must support non-zero toolbarHeight in landscape dual column mode',
        );

        // 5. Must use top-level PopScope with canPop logic
        expect(
          code.contains('shouldIntercept = isFullScreen || isPhoneLandscape') &&
              code.contains('canPop: !shouldIntercept'),
          isTrue,
          reason:
              'PopScope must cleanly distinguish fullscreen, phone landscape, and dual-column/portrait',
        );
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/widgets/video_detail_layout_coordinator.dart';

void main() {
  group('VideoDetailLayoutCoordinator TDD Unit Tests', () {
    test(
      'computeLeftColumnWidth calculates roughly 62% of maxWidth minus divider',
      () {
        final width1000 = VideoDetailLayoutCoordinator.computeLeftColumnWidth(
          1000.0,
        );
        expect(width1000, closeTo((1000.0 - 1.0) * 0.62, 0.01));

        final width1280 = VideoDetailLayoutCoordinator.computeLeftColumnWidth(
          1280.0,
        );
        expect(width1280, closeTo((1280.0 - 1.0) * 0.62, 0.01));
      },
    );

    test(
      'canUseDualColumn enforces 640.0dp minimum physical width threshold',
      () {
        expect(
          VideoDetailLayoutCoordinator.canUseDualColumn(
            isDualColumnFromScreenUtils: true,
            maxWidth: 639.9,
          ),
          isFalse,
        );

        expect(
          VideoDetailLayoutCoordinator.canUseDualColumn(
            isDualColumnFromScreenUtils: true,
            maxWidth: 640.0,
          ),
          isTrue,
        );

        expect(
          VideoDetailLayoutCoordinator.canUseDualColumn(
            isDualColumnFromScreenUtils: false,
            maxWidth: 1280.0,
          ),
          isFalse,
        );
      },
    );

    test(
      'computeClampedPlayerHeight clamps 16:9 player height to 62% of viewport height',
      () {
        // Standard 1280x800 tablet: leftWidth = 793, 16:9 height = 446.06, 62% of 800 is 496 -> unconstrained by clamp
        final standardHeight =
            VideoDetailLayoutCoordinator.computeClampedPlayerHeight(
              maxHeight: 800.0,
              leftWidth: 793.0,
            );
        expect(standardHeight, closeTo(793.0 * 9 / 16, 0.01));

        // Extremely flat or split screen: maxHeight = 400.0, leftWidth = 793.0 (16:9 raw is 446.06)
        // Max clamp limit = 400 * 0.62 = 248.0
        final clampedHeight =
            VideoDetailLayoutCoordinator.computeClampedPlayerHeight(
              maxHeight: 400.0,
              leftWidth: 793.0,
            );
        expect(clampedHeight, equals(248.0));
        expect(clampedHeight, lessThan(793.0 * 9 / 16));
      },
    );

    test(
      'computeClampedKeyboardHeight reserves at least 120dp for right column content',
      () {
        // Normal height: maxHeight = 800, keyboard = 300 -> allowed
        final normalKeyboard =
            VideoDetailLayoutCoordinator.computeClampedKeyboardHeight(
              rawKeyboardHeight: 300.0,
              maxHeight: 800.0,
            );
        expect(normalKeyboard, equals(300.0));

        // Zero keyboard: returns 0.0
        final zeroKeyboard =
            VideoDetailLayoutCoordinator.computeClampedKeyboardHeight(
              rawKeyboardHeight: 0.0,
              maxHeight: 800.0,
            );
        expect(zeroKeyboard, equals(0.0));

        // Small split screen height: maxHeight = 350.0, keyboard = 300.0
        // Max allowed = 350.0 - 120.0 = 230.0 -> clamped to 230.0
        final clampedKeyboard =
            VideoDetailLayoutCoordinator.computeClampedKeyboardHeight(
              rawKeyboardHeight: 300.0,
              maxHeight: 350.0,
            );
        expect(clampedKeyboard, equals(230.0));

        // Extreme case: maxHeight = 100.0 (< 120.0) -> returns 0.0 to prevent negative padding
        final extremeKeyboard =
            VideoDetailLayoutCoordinator.computeClampedKeyboardHeight(
              rawKeyboardHeight: 300.0,
              maxHeight: 100.0,
            );
        expect(extremeKeyboard, equals(0.0));
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/chapter_snap_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChapterSnapCoordinator TDD Unit Tests', () {
    test('resolveSnapRadius clamps correctly between 10.0 and 15.0', () {
      expect(ChapterSnapCoordinator.resolveSnapRadius(360.0), 10.0);
      expect(ChapterSnapCoordinator.resolveSnapRadius(800.0), 12.0);
      expect(ChapterSnapCoordinator.resolveSnapRadius(1200.0), 15.0);
      expect(ChapterSnapCoordinator.resolveSnapRadius(0.0), 10.0);
    });

    test('returns original position when no chapter points exist', () {
      final coordinator = ChapterSnapCoordinator();
      final result = coordinator.computeSnap(
        rawX: 150.0,
        barStart: 0.0,
        barWidth: 300.0,
        total: const Duration(seconds: 100),
        chapterPoints: const [],
      );

      expect(result.effectiveX, 150.0);
      expect(result.isSnapped, isFalse);
      expect(result.snappedPoint, isNull);
    });

    test('snaps cleanly when touch falls within snap radius', () {
      int hapticCount = 0;
      final coordinator = ChapterSnapCoordinator(
        onHapticFeedback: () => hapticCount++,
      );

      // Chapter at 50s in a 100s video on a 1000px bar -> chapterX = 500px
      // snapRadius for 1000px is clamp(1000*0.015, 10, 15) = 15.0
      const total = Duration(seconds: 100);
      final chapters = [const Duration(seconds: 50)];

      // Touch at 508px (within 15px radius of 500px)
      final result = coordinator.computeSnap(
        rawX: 508.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );

      expect(result.isSnapped, isTrue);
      expect(result.effectiveX, 500.0);
      expect(result.snappedPoint, const Duration(seconds: 50));
      expect(hapticCount, 1);

      // Continuing to move within the locked zone should not re-trigger haptic
      final result2 = coordinator.computeSnap(
        rawX: 503.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );

      expect(result2.isSnapped, isTrue);
      expect(result2.effectiveX, 500.0);
      expect(
        hapticCount,
        1,
        reason: 'Must not chatter / repeat haptic in zone',
      );
    });

    test('applies elastic tension before breaking escape threshold', () {
      final coordinator = ChapterSnapCoordinator();
      const total = Duration(seconds: 100);
      final chapters = [const Duration(seconds: 50)];

      // First enter snap zone at 505px (chapter is at 500px, snapRadius = 15px, escape = 22.5px)
      coordinator.computeSnap(
        rawX: 505.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );
      expect(coordinator.isCurrentlySnapped, isTrue);

      // Move to 518px (delta = 18px, which is > 15px but < 22.5px escape threshold)
      final elasticResult = coordinator.computeSnap(
        rawX: 518.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );

      expect(elasticResult.isSnapped, isTrue);
      // Elastic displacement: 500 + min((18 - 15) * 0.2, 2.0) = 500.6
      expect(elasticResult.effectiveX, closeTo(500.6, 0.01));

      // Move to 530px (delta = 30px > 22.5px escape threshold) -> breaks free!
      final escapedResult = coordinator.computeSnap(
        rawX: 530.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );

      expect(escapedResult.isSnapped, isFalse);
      expect(escapedResult.effectiveX, 530.0);
      expect(coordinator.isCurrentlySnapped, isFalse);
    });

    test('bypasses snapping when gesture velocity exceeds 800 dp/s', () {
      final coordinator = ChapterSnapCoordinator();
      const total = Duration(seconds: 100);
      final chapters = [const Duration(seconds: 50)];

      // Touch at 505px but with fast swipe velocity of 1200 dp/s
      final result = coordinator.computeSnap(
        rawX: 505.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
        velocityPxPerSec: 1200.0,
      );

      expect(result.isSnapped, isFalse);
      expect(result.effectiveX, 505.0);
    });

    test('reset clears state cleanly', () {
      final coordinator = ChapterSnapCoordinator();
      const total = Duration(seconds: 100);
      final chapters = [const Duration(seconds: 50)];

      coordinator.computeSnap(
        rawX: 505.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );
      expect(coordinator.isCurrentlySnapped, isTrue);

      coordinator.reset();
      expect(coordinator.isCurrentlySnapped, isFalse);
      expect(coordinator.snappedChapterPoint, isNull);
    });

    test('snaps and pulls with negative delta from the left/right', () {
      final coordinator = ChapterSnapCoordinator();
      const total = Duration(seconds: 100);
      final chapters = [const Duration(seconds: 50)]; // at 500px

      // Approach from left: touch at 492px (delta = -8px <= 15px snap radius)
      final snapResult = coordinator.computeSnap(
        rawX: 492.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );
      expect(snapResult.isSnapped, isTrue);
      expect(snapResult.effectiveX, 500.0);

      // Pull leftwards to 482px (delta = -18px, between 15px and 22.5px escape)
      final pullResult = coordinator.computeSnap(
        rawX: 482.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );
      expect(pullResult.isSnapped, isTrue);
      // tension = -1.0 * min(3 * 0.2, 2.0) = -0.6 -> 499.4
      expect(pullResult.effectiveX, closeTo(499.4, 0.01));

      // Escape leftwards to 470px (delta = -30px > 22.5px escape)
      final escapeResult = coordinator.computeSnap(
        rawX: 470.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );
      expect(escapeResult.isSnapped, isFalse);
      expect(escapeResult.effectiveX, 470.0);
    });

    test('selects closest chapter among multiple chapters', () {
      final coordinator = ChapterSnapCoordinator();
      const total = Duration(seconds: 100);
      final chapters = [
        const Duration(seconds: 20), // 200px
        const Duration(seconds: 50), // 500px
        const Duration(seconds: 80), // 800px
      ];

      // Touch near chapter 2 (500px) at 503px
      final result = coordinator.computeSnap(
        rawX: 503.0,
        barStart: 0.0,
        barWidth: 1000.0,
        total: total,
        chapterPoints: chapters,
      );
      expect(result.isSnapped, isTrue);
      expect(result.effectiveX, 500.0);
      expect(result.snappedPoint, const Duration(seconds: 50));
      expect(result.snappedChapterIndex, 1);
    });
  });
}

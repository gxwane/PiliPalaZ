import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/audio_video_progress_bar.dart';

void main() {
  group('ProgressBar Magnetic Snap-to-Chapter Widget Tests', () {
    testWidgets('magnetic snap locks thumb to chapter boundary during drag', (
      tester,
    ) async {
      ThumbDragDetails? latestDetails;
      Duration? seekTarget;

      // Bar width = 200 logical pixels. Total duration = 100 seconds.
      // Chapter split at 50 seconds (middle of bar).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: ProgressBar(
                  progress: Duration.zero,
                  total: const Duration(seconds: 100),
                  chapterPoints: const [Duration(seconds: 50)],
                  enableChapterSnap: true,
                  barHeight: 10.0,
                  thumbRadius: 10.0,
                  timeLabelLocation: TimeLabelLocation.none,
                  onDragUpdate: (details) {
                    latestDetails = details;
                  },
                  onSeek: (target) {
                    seekTarget = target;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final barFinder = find.byType(ProgressBar);
      expect(barFinder, findsOneWidget);

      final barTopLeft = tester.getTopLeft(barFinder);
      final barSize = tester.getSize(barFinder);
      final barCenterY = barTopLeft.dy + barSize.height / 2;

      // Start drag at left (0s)
      final gesture = await tester.startGesture(
        Offset(barTopLeft.dx + 5, barCenterY),
      );
      await tester.pump();

      // Drag towards chapter point at 50s (middle ~ 100px)
      // Moving to ~102px (very close to 100px, within snap radius 10-15px)
      await gesture.moveTo(Offset(barTopLeft.dx + 102, barCenterY));
      await tester.pump();

      expect(latestDetails, isNotNull);
      expect(latestDetails!.isSnapped, isTrue);
      expect(latestDetails!.snappedPoint, const Duration(seconds: 50));
      expect(latestDetails!.timeStamp, const Duration(seconds: 50));

      // Release gesture to seek
      await gesture.up();
      await tester.pump();

      expect(seekTarget, const Duration(seconds: 50));
    });

    testWidgets('enableChapterSnap: false bypasses snapping completely', (
      tester,
    ) async {
      ThumbDragDetails? latestDetails;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: ProgressBar(
                  progress: Duration.zero,
                  total: const Duration(seconds: 100),
                  chapterPoints: const [Duration(seconds: 50)],
                  enableChapterSnap: false,
                  barHeight: 10.0,
                  thumbRadius: 10.0,
                  timeLabelLocation: TimeLabelLocation.none,
                  onDragUpdate: (details) {
                    latestDetails = details;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final barFinder = find.byType(ProgressBar);
      final barTopLeft = tester.getTopLeft(barFinder);
      final barSize = tester.getSize(barFinder);
      final barCenterY = barTopLeft.dy + barSize.height / 2;

      final gesture = await tester.startGesture(
        Offset(barTopLeft.dx + 5, barCenterY),
      );
      await tester.pump();

      // Drag close to 50s mark (102px)
      await gesture.moveTo(Offset(barTopLeft.dx + 102, barCenterY));
      await tester.pump();

      expect(latestDetails, isNotNull);
      expect(latestDetails!.isSnapped, isFalse);
      expect(latestDetails!.snappedPoint, isNull);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('dragging far away from chapter points does not snap', (
      tester,
    ) async {
      ThumbDragDetails? latestDetails;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: ProgressBar(
                  progress: Duration.zero,
                  total: const Duration(seconds: 100),
                  chapterPoints: const [Duration(seconds: 50)],
                  enableChapterSnap: true,
                  barHeight: 10.0,
                  thumbRadius: 10.0,
                  timeLabelLocation: TimeLabelLocation.none,
                  onDragUpdate: (details) {
                    latestDetails = details;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final barFinder = find.byType(ProgressBar);
      final barTopLeft = tester.getTopLeft(barFinder);
      final barSize = tester.getSize(barFinder);
      final barCenterY = barTopLeft.dy + barSize.height / 2;

      final gesture = await tester.startGesture(
        Offset(barTopLeft.dx + 5, barCenterY),
      );
      await tester.pump();

      // Drag to ~20px (far away from 100px)
      await gesture.moveTo(Offset(barTopLeft.dx + 20, barCenterY));
      await tester.pump();

      expect(latestDetails, isNotNull);
      expect(latestDetails!.isSnapped, isFalse);
      expect(latestDetails!.snappedPoint, isNull);

      await gesture.up();
      await tester.pump();
    });
  });
}

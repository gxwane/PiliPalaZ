import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/audio_video_progress_bar.dart';

void main() {
  group('ProgressBar Segmented Chapters TDD Widget Tests', () {
    testWidgets('renders continuous bar without chapterPoints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ProgressBar(
                  progress: const Duration(seconds: 50),
                  buffered: const Duration(seconds: 100),
                  total: const Duration(seconds: 200),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('renders segmented bar with chapterPoints safely', (
      tester,
    ) async {
      final chapters = [
        const Duration(seconds: 60),
        const Duration(seconds: 120),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ProgressBar(
                  progress: const Duration(seconds: 80),
                  buffered: const Duration(seconds: 150),
                  total: const Duration(seconds: 200),
                  chapterPoints: chapters,
                  chapterGapWidth: 3.0,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets(
      'handles progress at exactly chapter boundaries without crashing',
      (tester) async {
        final chapters = [
          const Duration(seconds: 50),
          const Duration(seconds: 100),
        ];

        // Test progress exactly at 0, 50, 100, 200
        for (final sec in [0, 50, 100, 200]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 300,
                    child: ProgressBar(
                      progress: Duration(seconds: sec),
                      total: const Duration(seconds: 200),
                      chapterPoints: chapters,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(ProgressBar), findsOneWidget);
        }
      },
    );

    testWidgets(
      'handles chapterPoints with single or out-of-range boundaries gracefully',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: ProgressBar(
                    progress: const Duration(seconds: 10),
                    total: const Duration(seconds: 100),
                    chapterPoints: const [
                      Duration(seconds: 0),
                      Duration(seconds: 100),
                      Duration(seconds: 250), // > total
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(ProgressBar), findsOneWidget);
      },
    );
  });
}

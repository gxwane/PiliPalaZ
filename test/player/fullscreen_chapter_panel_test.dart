import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/video/play/chapter.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/fullscreen_chapter_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FullScreenChapterPanel Widget & Interaction TDD Tests', () {
    final testChapters = [
      const VideoChapter(from: 0, to: 90, title: '引言部分'),
      const VideoChapter(from: 90, to: 250, title: '关键特性演示'),
      const VideoChapter(from: 250, to: 500, title: '尾声与鸣谢'),
    ];

    testWidgets('renders chapters, header, and active badge in landscape', (
      tester,
    ) async {
      final activeChapter = Rx<VideoChapter?>(testChapters[1]);
      VideoChapter? selectedChapter;

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenChapterPanel(
              chapters: testChapters,
              activeChapter: activeChapter,
              onSelect: (c) => selectedChapter = c,
            ),
          ),
        ),
      );

      expect(find.text('看点列表'), findsOneWidget);
      expect(find.text('共 3 个分段'), findsOneWidget);
      expect(find.text('引言部分'), findsOneWidget);
      expect(find.text('关键特性演示'), findsOneWidget);
      expect(find.text('尾声与鸣谢'), findsOneWidget);
      expect(find.text('00:00 - 01:30'), findsOneWidget);
      expect(find.text('01:30 - 04:10'), findsOneWidget);
      expect(find.text('播放中'), findsOneWidget);

      // Tap on first chapter
      await tester.tap(find.text('引言部分'));
      await tester.pumpAndSettle();
      expect(selectedChapter, testChapters[0]);
    });

    testWidgets('swiping right triggers dismiss callback', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenChapterPanel(
              chapters: testChapters,
              activeChapter: Rx<VideoChapter?>(testChapters[0]),
              onSelect: (_) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Perform swipe right gesture
      await tester.drag(find.text('看点列表'), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('auto-dismisses when orientation becomes portrait', (
      tester,
    ) async {
      bool dismissed = false;

      // Start in portrait
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenChapterPanel(
              chapters: testChapters,
              activeChapter: Rx<VideoChapter?>(testChapters[0]),
              onSelect: (_) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('FullScreenChapterPanel.show opens dialog and selects item', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      VideoChapter? selectedChapter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    FullScreenChapterPanel.show(
                      context: context,
                      chapters: testChapters,
                      activeChapter: Rx<VideoChapter?>(testChapters[0]),
                      onSelect: (c) => selectedChapter = c,
                    );
                  },
                  child: const Text('打开看点'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开看点'));
      await tester.pumpAndSettle();

      expect(find.text('看点列表'), findsOneWidget);
      expect(find.text('关键特性演示'), findsOneWidget);

      await tester.tap(find.text('关键特性演示'));
      await tester.pumpAndSettle();

      expect(selectedChapter, testChapters[1]);
      // Dialog should be dismissed
      expect(find.text('看点列表'), findsNothing);
    });
  });
}

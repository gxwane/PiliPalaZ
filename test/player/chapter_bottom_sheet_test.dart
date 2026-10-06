import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/video/play/chapter.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/chapter_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChapterBottomSheet Widget TDD Tests', () {
    final testChapters = [
      const VideoChapter(from: 0, to: 120, title: '第一章：背景引入'),
      const VideoChapter(from: 120, to: 300, title: '第二章：核心实现'),
      const VideoChapter(from: 300, to: 450, title: '第三章：总结回顾'),
    ];

    testWidgets('renders all chapters and header correctly', (tester) async {
      VideoChapter? selectedChapter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterBottomSheet(
              chapters: testChapters,
              activeChapter: testChapters[1],
              onSelect: (c) => selectedChapter = c,
            ),
          ),
        ),
      );

      expect(find.text('看点列表'), findsOneWidget);
      expect(find.text('共 3 个分段'), findsOneWidget);
      expect(find.text('第一章：背景引入'), findsOneWidget);
      expect(find.text('第二章：核心实现'), findsOneWidget);
      expect(find.text('第三章：总结回顾'), findsOneWidget);
      expect(find.text('00:00 - 02:00'), findsOneWidget);
      expect(find.text('02:00 - 05:00'), findsOneWidget);

      // Tap on third chapter
      await tester.tap(find.text('第三章：总结回顾'));
      expect(selectedChapter, testChapters[2]);
    });
  });
}

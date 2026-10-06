import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/video.dart';

void main() {
  group('VideoChapter Model TDD Tests', () {
    test('parses standard view_point json successfully', () {
      final json = <String, dynamic>{
        'type': 1,
        'from': 0,
        'to': 75,
        'content': '引言与背景',
        'imgUrl': 'https://example.com/thumb1.jpg',
      };

      final chapter = VideoChapter.fromJson(json);

      expect(chapter.from, 0);
      expect(chapter.to, 75);
      expect(chapter.title, '引言与背景');
      expect(chapter.imgUrl, 'https://example.com/thumb1.jpg');
      expect(chapter.durationSeconds, 75);
    });

    test('supports alternative title keys and string numbers', () {
      final json = <String, dynamic>{
        'from': '75',
        'to': 120.8,
        'title': '核心架构解析',
      };

      final chapter = VideoChapter.fromJson(json);

      expect(chapter.from, 75);
      expect(chapter.to, 120);
      expect(chapter.title, '核心架构解析');
      expect(chapter.imgUrl, isNull);
    });

    test('handles missing or malformed fields defensively without crash', () {
      final json = <String, dynamic>{
        'from': null,
        'to': 'invalid',
        'content': null,
      };

      final chapter = VideoChapter.fromJson(json);

      expect(chapter.from, 0);
      expect(chapter.to, 0);
      expect(chapter.title, '');
    });

    test('normalizes reversed or negative intervals safely', () {
      final json = <String, dynamic>{
        'from': 100,
        'to': 50,
        'content': '异常反向区间',
      };

      final chapter = VideoChapter.fromJson(json);

      expect(chapter.from, 50);
      expect(chapter.to, 100);
      expect(chapter.durationSeconds, 50);
    });

    test('contains correctly checks if a second falls within chapter', () {
      const chapter = VideoChapter(from: 10, to: 30, title: '中间章节');

      expect(chapter.contains(9), isFalse);
      expect(chapter.contains(10), isTrue);
      expect(chapter.contains(20), isTrue);
      expect(chapter.contains(30), isFalse); // right-open interval
      expect(chapter.contains(31), isFalse);

      // When isLast is specified, right boundary is inclusive
      expect(chapter.contains(30, isLast: true), isTrue);
    });
  });

  group('VideoPlayerMetadata TDD Tests', () {
    test('creates metadata with default empty lists', () {
      const metadata = VideoPlayerMetadata();
      expect(metadata.subtitles, isEmpty);
      expect(metadata.chapters, isEmpty);
    });

    test('holds subtitles and chapters accurately', () {
      const chapter = VideoChapter(from: 0, to: 10, title: 'C1');
      const subtitle = VideoSubtitleSource(
        url: 'https://example.com/sub.json',
        language: 'zh-Hans',
        title: '中文',
      );

      final metadata = VideoPlayerMetadata(
        subtitles: [subtitle],
        chapters: [chapter],
      );

      expect(metadata.subtitles.length, 1);
      expect(metadata.chapters.length, 1);
      expect(metadata.chapters.first.title, 'C1');
    });

    test(
      'resolveChapterSplitPoints extracts sorted boundary points within duration',
      () {
        final chapters = [
          const VideoChapter(from: 0, to: 60, title: 'Part 1'),
          const VideoChapter(from: 60, to: 150, title: 'Part 2'),
          const VideoChapter(from: 150, to: 300, title: 'Part 3'),
        ];

        final splitPoints = VideoChapter.resolveChapterSplitPoints(
          chapters,
          totalDurationSeconds: 300,
        );

        // Boundaries between chapters: 60 and 150 (0 and 300 are outer edges)
        expect(splitPoints, [
          const Duration(seconds: 60),
          const Duration(seconds: 150),
        ]);
      },
    );

    test(
      'resolveChapterSplitPoints discards invalid/out-of-range boundaries',
      () {
        final chapters = [
          const VideoChapter(from: 0, to: 50, title: 'Part 1'),
          const VideoChapter(
            from: 50,
            to: 400,
            title: 'Part 2',
          ), // 400 > total 300
        ];

        final splitPoints = VideoChapter.resolveChapterSplitPoints(
          chapters,
          totalDurationSeconds: 300,
        );

        expect(splitPoints, [const Duration(seconds: 50)]);
      },
    );
  });
}

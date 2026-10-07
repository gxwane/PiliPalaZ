import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/video/play/chapter.dart';
import 'package:pilipalaz/services/download/offline_chapter_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_chapters_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OfflineChapterService - downloadChapters', () {
    test('拉取成功并原子持久化章节数据', () async {
      final mockChapters = <VideoChapter>[
        const VideoChapter(from: 0, to: 60, title: '开场引入'),
        const VideoChapter(
          from: 60,
          to: 180,
          title: '核心特性',
          imgUrl: 'https://example.com/c2.jpg',
        ),
      ];

      final service = OfflineChapterService(
        chapterFetcher: ({String? aid, String? bvid, required int cid}) async {
          expect(bvid, equals('BV1test'));
          expect(cid, equals(1001));
          return ApiSuccess<List<VideoChapter>>(mockChapters);
        },
      );

      final targetFile = File('${tempDir.path}/chapters.json');
      final result = await service.downloadChapters(
        bvid: 'BV1test',
        cid: 1001,
        targetFile: targetFile,
      );

      expect(result, isTrue);
      expect(await targetFile.exists(), isTrue);

      // 验证 tmp 文件已被重命名清理
      final tmpFile = File('${targetFile.path}.tmp');
      expect(await tmpFile.exists(), isFalse);

      final loaded = await OfflineChapterService.loadChaptersFromFile(
        targetFile,
      );
      expect(loaded, isNotNull);
      expect(loaded!.length, equals(2));
      expect(loaded[0].title, equals('开场引入'));
      expect(loaded[0].from, equals(0));
      expect(loaded[0].to, equals(60));
      expect(loaded[1].title, equals('核心特性'));
      expect(loaded[1].imgUrl, equals('https://example.com/c2.jpg'));
    });

    test('空章节列表时优雅返回 true 且不创建垃圾文件', () async {
      final service = OfflineChapterService(
        chapterFetcher: ({String? aid, String? bvid, required int cid}) async {
          return const ApiSuccess<List<VideoChapter>>(<VideoChapter>[]);
        },
      );

      final targetFile = File('${tempDir.path}/chapters.json');
      final result = await service.downloadChapters(
        bvid: 'BV1empty',
        cid: 1002,
        targetFile: targetFile,
      );

      expect(result, isTrue);
      expect(await targetFile.exists(), isFalse);
    });

    test('任务已取消时及时熔断并返回 false', () async {
      final cancelToken = CancelToken();
      final service = OfflineChapterService(
        chapterFetcher: ({String? aid, String? bvid, required int cid}) async {
          cancelToken.cancel();
          return const ApiSuccess<List<VideoChapter>>([
            VideoChapter(from: 0, to: 30, title: '测试'),
          ]);
        },
      );

      final targetFile = File('${tempDir.path}/chapters.json');
      final result = await service.downloadChapters(
        bvid: 'BV1cancel',
        cid: 1003,
        targetFile: targetFile,
        cancelToken: cancelToken,
      );

      expect(result, isFalse);
      expect(await targetFile.exists(), isFalse);
    });

    test('接口报错时返回 false', () async {
      final service = OfflineChapterService(
        chapterFetcher: ({String? aid, String? bvid, required int cid}) async {
          return const ApiFailure<List<VideoChapter>>(
            kind: ApiFailureKind.network,
            message: '网络连接超时',
          );
        },
      );

      final targetFile = File('${tempDir.path}/chapters.json');
      final result = await service.downloadChapters(
        bvid: 'BV1fail',
        cid: 1004,
        targetFile: targetFile,
      );

      expect(result, isFalse);
      expect(await targetFile.exists(), isFalse);
    });

    test('接口返回乱序分段时自动按时间戳单调升序归一化排序', () async {
      final unordered = <VideoChapter>[
        const VideoChapter(from: 300, to: 500, title: '尾声总结'),
        const VideoChapter(from: 0, to: 100, title: '开头引入'),
        const VideoChapter(from: 100, to: 300, title: '核心演示'),
      ];

      final service = OfflineChapterService(
        chapterFetcher: ({String? aid, String? bvid, required int cid}) async {
          return ApiSuccess<List<VideoChapter>>(unordered);
        },
      );

      final targetFile = File('${tempDir.path}/chapters.json');
      final result = await service.downloadChapters(
        bvid: 'BV1sort',
        cid: 1005,
        targetFile: targetFile,
      );

      expect(result, isTrue);
      final loaded = await OfflineChapterService.loadChaptersFromFile(
        targetFile,
      );
      expect(loaded, isNotNull);
      expect(loaded![0].from, equals(0));
      expect(loaded[0].title, equals('开头引入'));
      expect(loaded[1].from, equals(100));
      expect(loaded[1].title, equals('核心演示'));
      expect(loaded[2].from, equals(300));
      expect(loaded[2].title, equals('尾声总结'));
    });
  });

  group('OfflineChapterService - loadChaptersFromFile', () {
    test('文件不存在时安全返回 null', () async {
      final nonExistent = File('${tempDir.path}/not_found.json');
      final chapters = await OfflineChapterService.loadChaptersFromFile(
        nonExistent,
      );
      expect(chapters, isNull);
    });

    test('文件内容为空时安全返回 null', () async {
      final emptyFile = File('${tempDir.path}/empty.json');
      await emptyFile.writeAsString('   ');
      final chapters = await OfflineChapterService.loadChaptersFromFile(
        emptyFile,
      );
      expect(chapters, isNull);
    });

    test('文件内容损坏或格式非法时安全返回 null 且不抛出未捕获异常', () async {
      final corruptedFile = File('${tempDir.path}/corrupt.json');
      await corruptedFile.writeAsString('{{{ invalid json ...');
      final chapters = await OfflineChapterService.loadChaptersFromFile(
        corruptedFile,
      );
      expect(chapters, isNull);
    });

    test('JSON 根结构非 List 时安全返回 null', () async {
      final mapFile = File('${tempDir.path}/map.json');
      await mapFile.writeAsString('{"key": "value"}');
      final chapters = await OfflineChapterService.loadChaptersFromFile(
        mapFile,
      );
      expect(chapters, isNull);
    });

    test('JSON 列表为空数组时安全返回 null', () async {
      final emptyListFile = File('${tempDir.path}/empty_list.json');
      await emptyListFile.writeAsString('[]');
      final chapters = await OfflineChapterService.loadChaptersFromFile(
        emptyListFile,
      );
      expect(chapters, isNull);
    });

    test('本地反序列化亦保持单调递增排序', () async {
      final file = File('${tempDir.path}/test_sort.json');
      await file.writeAsString('''[
        {"from": 120, "to": 200, "title": "B"},
        {"from": 10, "to": 120, "title": "A"}
      ]''');

      final chapters = await OfflineChapterService.loadChaptersFromFile(file);
      expect(chapters, isNotNull);
      expect(chapters!.length, equals(2));
      expect(chapters[0].title, equals('A'));
      expect(chapters[0].from, equals(10));
      expect(chapters[1].title, equals('B'));
      expect(chapters[1].from, equals(120));
    });
  });
}

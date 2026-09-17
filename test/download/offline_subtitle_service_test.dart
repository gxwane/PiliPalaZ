import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/services/download/offline_subtitle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_subtitle_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OfflineSubtitleService TDD & Idempotency Tests', () {
    test(
      'downloadSubtitles successfully fetches, converts, and saves subtitles to JSON',
      () async {
        final targetFile = File('${tempDir.path}/subtitles.json');

        final mockSources = [
          const VideoSubtitleSource(
            url: 'https://example.com/zh.json',
            language: 'zh-Hans',
            title: '中文（简体）',
          ),
          const VideoSubtitleSource(
            url: 'https://example.com/en.json',
            language: 'en-US',
            title: 'English',
          ),
        ];

        final mockVttTracks = [
          <String, String>{
            'language': 'zh-Hans',
            'title': '中文（简体）',
            'text': 'WEBVTT\n\n1\n00:00:01.000 --> 00:00:03.000\n你好世界\n\n',
          },
          <String, String>{
            'language': 'en-US',
            'title': 'English',
            'text':
                'WEBVTT\n\n1\n00:00:01.000 --> 00:00:03.000\nHello World\n\n',
          },
        ];

        final service = OfflineSubtitleService(
          videoMetaFetcher:
              ({String? aid, String? bvid, required int cid}) async {
                expect(bvid, 'BV1test');
                expect(cid, 123456);
                return ApiSuccess(mockSources);
              },
          vttConverter: (sources) async {
            expect(sources.length, 2);
            return ApiSuccess(mockVttTracks);
          },
        );

        final bool result = await service.downloadSubtitles(
          bvid: 'BV1test',
          cid: 123456,
          targetFile: targetFile,
        );

        expect(result, isTrue);
        expect(await targetFile.exists(), isTrue);

        // Verify deserialization
        final loaded = await OfflineSubtitleService.loadSubtitlesFromFile(
          targetFile,
        );
        expect(loaded, isNotNull);
        expect(loaded!.length, 3); // 1 (关闭字幕) + 2 (内容字幕)
        expect(loaded.first['title'], '关闭字幕');
        expect(loaded[1]['language'], 'zh-Hans');
        expect(loaded[1]['title'], '中文（简体）');
        expect(loaded[1]['text'], contains('你好世界'));
        expect(loaded[2]['language'], 'en-US');
      },
    );

    test(
      'downloadSubtitles returns true gracefully when video has no subtitles',
      () async {
        final targetFile = File('${tempDir.path}/subtitles.json');

        final service = OfflineSubtitleService(
          videoMetaFetcher:
              ({String? aid, String? bvid, required int cid}) async {
                return const ApiSuccess(<VideoSubtitleSource>[]);
              },
        );

        final bool result = await service.downloadSubtitles(
          bvid: 'BV1nosubs',
          cid: 654321,
          targetFile: targetFile,
        );

        expect(result, isTrue);
        // No file created when there are no subtitles
        expect(await targetFile.exists(), isFalse);

        final loaded = await OfflineSubtitleService.loadSubtitlesFromFile(
          targetFile,
        );
        expect(loaded, isNull);
      },
    );

    test('downloadSubtitles respects CancelToken and aborts early', () async {
      final targetFile = File('${tempDir.path}/subtitles.json');
      final cancelToken = CancelToken();
      cancelToken.cancel('User canceled download');

      bool fetcherCalled = false;
      final service = OfflineSubtitleService(
        videoMetaFetcher:
            ({String? aid, String? bvid, required int cid}) async {
              fetcherCalled = true;
              return const ApiSuccess([]);
            },
      );

      final bool result = await service.downloadSubtitles(
        bvid: 'BV1cancel',
        cid: 111,
        targetFile: targetFile,
        cancelToken: cancelToken,
      );

      expect(fetcherCalled, isFalse);
      expect(result, isFalse);
      expect(await targetFile.exists(), isFalse);
    });

    test(
      'loadSubtitlesFromFile safely handles corrupt or empty JSON files',
      () async {
        final corruptFile = File('${tempDir.path}/corrupt.json');
        await corruptFile.writeAsString('{not valid json', flush: true);

        final result1 = await OfflineSubtitleService.loadSubtitlesFromFile(
          corruptFile,
        );
        expect(result1, isNull);

        final emptyFile = File('${tempDir.path}/empty.json');
        await emptyFile.writeAsString('', flush: true);

        final result2 = await OfflineSubtitleService.loadSubtitlesFromFile(
          emptyFile,
        );
        expect(result2, isNull);

        final wrongTypeFile = File('${tempDir.path}/wrong_type.json');
        await wrongTypeFile.writeAsString(
          jsonEncode({'not': 'a list'}),
          flush: true,
        );

        final result3 = await OfflineSubtitleService.loadSubtitlesFromFile(
          wrongTypeFile,
        );
        expect(result3, isNull);
      },
    );

    test('loadSubtitlesFromFile enforces idempotent Index 0 "关闭字幕"', () async {
      final file = File('${tempDir.path}/already_has_close.json');
      final content = [
        {'language': '', 'title': '关闭字幕', 'text': ''},
        {'language': 'zh-Hans', 'title': '中文', 'text': 'WEBVTT\n\n'},
      ];
      await file.writeAsString(jsonEncode(content), flush: true);

      final loaded = await OfflineSubtitleService.loadSubtitlesFromFile(file);
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[0]['title'], '关闭字幕');
      expect(loaded[1]['title'], '中文');
    });
  });
}

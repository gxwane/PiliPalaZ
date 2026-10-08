import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';
import 'package:pilipalaz/services/download/download_task_executor.dart';
import 'package:pilipalaz/services/download/offline_chapter_service.dart';
import 'package:pilipalaz/services/download/offline_danmaku_service.dart';
import 'package:pilipalaz/services/download/offline_subtitle_service.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  )
  handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

DownloadTask _makeTask({int cid = 101}) {
  return DownloadTask.create(
    bvid: 'BV1resilience',
    cid: cid,
    title: 'Resilience Test Video',
    cover: '',
    ownerName: 'Test UP',
    duration: 60,
    videoQuality: 80,
    videoQualityDesc: '1080P',
    videoCodec: 'avc1',
    audioQuality: 30280,
  );
}

OfflineDanmakuService _stubDanmakuService() => OfflineDanmakuService(
  danmakuFetcher: ({required cid, required segmentIndex}) async =>
      const ApiFailure(kind: ApiFailureKind.network, message: 'dummy'),
);

OfflineSubtitleService _stubSubtitleService() => OfflineSubtitleService(
  videoMetaFetcher: ({aid, bvid, required cid}) async =>
      const ApiFailure(kind: ApiFailureKind.network, message: 'dummy'),
);

OfflineChapterService _stubChapterService() => OfflineChapterService(
  chapterFetcher: ({aid, bvid, required cid}) async =>
      const ApiFailure(kind: ApiFailureKind.network, message: 'dummy'),
);

void main() {
  group('DownloadErrorClassifier', () {
    test('正确分类各种 DioException 和底层网络异常', () {
      final req = RequestOptions(path: 'http://test');

      // 用户取消
      expect(
        DownloadErrorClassifier.classify(
          DioException(requestOptions: req, type: DioExceptionType.cancel),
        ),
        equals(DownloadErrorType.cancelled),
      );

      // 磁盘不足
      expect(
        DownloadErrorClassifier.classify(
          DioException(requestOptions: req, message: 'insufficient_disk_space'),
        ),
        equals(DownloadErrorType.insufficientSpace),
      );

      // Token 过期 (403, 410)
      expect(
        DownloadErrorClassifier.classify(
          DioException(
            requestOptions: req,
            response: Response(requestOptions: req, statusCode: 403),
          ),
        ),
        equals(DownloadErrorType.expiredToken),
      );
      expect(
        DownloadErrorClassifier.classify(
          DioException(
            requestOptions: req,
            response: Response(requestOptions: req, statusCode: 410),
          ),
        ),
        equals(DownloadErrorType.expiredToken),
      );

      // 损坏断点 HTTP 416
      expect(
        DownloadErrorClassifier.classify(
          DioException(
            requestOptions: req,
            response: Response(requestOptions: req, statusCode: 416),
          ),
        ),
        equals(DownloadErrorType.corruptedRange),
      );

      // 瞬态 HTTP 状态码 (500, 502, 503, 504, 408, 429)
      for (final code in [500, 502, 503, 504, 408, 429]) {
        expect(
          DownloadErrorClassifier.classify(
            DioException(
              requestOptions: req,
              response: Response(requestOptions: req, statusCode: code),
            ),
          ),
          equals(DownloadErrorType.transientNetwork),
        );
      }

      // 瞬态网络超时与连接异常
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          DownloadErrorClassifier.classify(
            DioException(requestOptions: req, type: type),
          ),
          equals(DownloadErrorType.transientNetwork),
        );
      }

      // DioException 包装 SocketException / HttpException
      expect(
        DownloadErrorClassifier.classify(
          DioException(
            requestOptions: req,
            error: const SocketException('Connection reset'),
          ),
        ),
        equals(DownloadErrorType.transientNetwork),
      );
      expect(
        DownloadErrorClassifier.classify(
          DioException(
            requestOptions: req,
            error: const HttpException('Connection closed'),
          ),
        ),
        equals(DownloadErrorType.transientNetwork),
      );

      // 原生网络与文件系统异常
      expect(
        DownloadErrorClassifier.classify(
          const SocketException('Network unreachable'),
        ),
        equals(DownloadErrorType.transientNetwork),
      );
      expect(
        DownloadErrorClassifier.classify(
          const FileSystemException('No space left on device'),
        ),
        equals(DownloadErrorType.insufficientSpace),
      );

      // 致命错误 (404, 401, 400)
      for (final code in [400, 401, 404]) {
        expect(
          DownloadErrorClassifier.classify(
            DioException(
              requestOptions: req,
              response: Response(requestOptions: req, statusCode: code),
            ),
          ),
          equals(DownloadErrorType.fatal),
        );
      }
    });
  });

  group('RetryDelayProvider', () {
    test('defaultRetryDelay 在 Duration.zero 时立即返回', () async {
      await defaultRetryDelay(Duration.zero, null);
    });

    test('defaultRetryDelay 在 CancelToken 取消时立即中断抛出 cancel 异常', () async {
      final token = CancelToken();
      final future = defaultRetryDelay(const Duration(seconds: 10), token);
      token.cancel();

      expect(
        future,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    });
  });

  group('DownloadTaskExecutor 韧性重试与自愈实测', () {
    late Directory tmpDir;
    late DownloadStorageManager storageManager;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('resilience_test_');
      storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 1024 * 1024 * 1024,
      );
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('TEST-RES-01: 瞬态网络超时 2 次后重试成功', () async {
      final task = _makeTask(cid: 1);
      int videoCallCount = 0;
      int audioCallCount = 0;
      final recordedRetryCounts = <int>[];

      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((
        options,
        requestStream,
        cancelFuture,
      ) async {
        if (options.path.contains('video')) {
          videoCallCount++;
          if (videoCallCount <= 2) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            );
          }
          final bytes = utf8.encode('mock_video_data');
          return ResponseBody(
            Stream.value(Uint8List.fromList(bytes)),
            200,
            headers: {
              'content-length': ['${bytes.length}'],
            },
          );
        } else {
          audioCallCount++;
          final bytes = utf8.encode('mock_audio_data');
          return ResponseBody(
            Stream.value(Uint8List.fromList(bytes)),
            200,
            headers: {
              'content-length': ['${bytes.length}'],
            },
          );
        }
      });

      final executor = DownloadTaskExecutor(
        task: task,
        storageManager: storageManager,
        videoUrl: 'http://cdn/video.m4s',
        audioUrl: 'http://cdn/audio.m4s',
        dio: dio,
        danmakuService: _stubDanmakuService(),
        subtitleService: _stubSubtitleService(),
        chapterService: _stubChapterService(),
        retryDelayProvider: (delay, token) async {
          recordedRetryCounts.add(task.retryCount);
        },
      );

      final status = await executor.execute();
      expect(status, equals(DownloadTaskStatus.completed));
      expect(videoCallCount, equals(3)); // 1 initial + 2 retries
      expect(audioCallCount, equals(1));
      expect(recordedRetryCounts, equals([1, 2]));
      expect(task.retryCount, equals(0)); // 成功后重置
      expect(task.retryMessage, isNull);

      final videoFile = File(
        await storageManager.absolutePath(
          storageManager.pathsForTask(task).videoRelativePath,
        ),
      );
      expect(videoFile.existsSync(), isTrue);
      expect(await videoFile.readAsString(), equals('mock_video_data'));

      executor.dispose();
    });

    test('TEST-RES-02: 连续超时耗尽 3 次重试后终止并记录错误', () async {
      final task = _makeTask(cid: 2);
      int callCount = 0;

      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((
        options,
        requestStream,
        cancelFuture,
      ) async {
        callCount++;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      });

      final executor = DownloadTaskExecutor(
        task: task,
        storageManager: storageManager,
        videoUrl: 'http://cdn/video.m4s',
        audioUrl: 'http://cdn/audio.m4s',
        dio: dio,
        danmakuService: _stubDanmakuService(),
        subtitleService: _stubSubtitleService(),
        chapterService: _stubChapterService(),
        retryDelayProvider: (delay, cancelToken) async {},
      );

      expect(executor.execute(), throwsA(isA<DioException>()));
      // 1 首次 + 3 次重试 = 4 次调用
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(callCount, equals(4));
      expect(task.errorMessage, contains('网络连接超时，已尝试 3 次重试'));

      executor.dispose();
    });

    test('TEST-HEAL-01: HTTP 416 损坏断点自愈清理并从 0 字节重新拉取成功', () async {
      final task = _makeTask(cid: 3);
      final paths = storageManager.pathsForTask(task);
      final videoPartPath = await storageManager.videoPartPath(task);
      final videoPartFile = File(videoPartPath);
      await Directory(videoPartFile.parent.path).create(recursive: true);
      // 预先写入 1024 字节损坏脏数据
      await videoPartFile.writeAsBytes(List<int>.filled(1024, 0xFF));
      expect(videoPartFile.existsSync(), isTrue);

      int videoCallCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((
        options,
        requestStream,
        cancelFuture,
      ) async {
        if (options.path.contains('video')) {
          videoCallCount++;
          final range = options.headers['Range'] as String?;
          if (range != null && range.contains('bytes=1024-')) {
            // 首次请求 Range: 1024- 时服务端返回 416
            return ResponseBody(
              Stream.empty(),
              416,
              headers: {
                'content-range': ['bytes */1024'],
              },
            );
          }
          // 自愈重置后无 Range，返回 200 与正规数据
          final bytes = utf8.encode('healed_video_content');
          return ResponseBody(
            Stream.value(Uint8List.fromList(bytes)),
            200,
            headers: {
              'content-length': ['${bytes.length}'],
            },
          );
        } else {
          final bytes = utf8.encode('audio_content');
          return ResponseBody(
            Stream.value(Uint8List.fromList(bytes)),
            200,
            headers: {
              'content-length': ['${bytes.length}'],
            },
          );
        }
      });

      final executor = DownloadTaskExecutor(
        task: task,
        storageManager: storageManager,
        videoUrl: 'http://cdn/video.m4s',
        audioUrl: 'http://cdn/audio.m4s',
        dio: dio,
        danmakuService: _stubDanmakuService(),
        subtitleService: _stubSubtitleService(),
        chapterService: _stubChapterService(),
        retryDelayProvider: (delay, cancelToken) async {},
      );

      final status = await executor.execute();
      expect(status, equals(DownloadTaskStatus.completed));
      expect(videoCallCount, equals(2)); // 首次 416 + 自愈后成功

      final videoFile = File(
        await storageManager.absolutePath(paths.videoRelativePath),
      );
      expect(videoFile.existsSync(), isTrue);
      expect(await videoFile.readAsString(), equals('healed_video_content'));

      executor.dispose();
    });

    test('TEST-HEAL-02: HTTP 416 熔断机制防止死锁死循环', () async {
      final task = _makeTask(cid: 4);
      final videoPartPath = await storageManager.videoPartPath(task);
      final videoPartFile = File(videoPartPath);
      await Directory(videoPartFile.parent.path).create(recursive: true);
      await videoPartFile.writeAsBytes(List<int>.filled(512, 0xAA));

      int videoCallCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockAdapter((
        options,
        requestStream,
        cancelFuture,
      ) async {
        videoCallCount++;
        // 持续返回 416
        return ResponseBody(
          Stream.empty(),
          416,
          headers: {
            'content-range': ['bytes */0'],
          },
        );
      });

      final executor = DownloadTaskExecutor(
        task: task,
        storageManager: storageManager,
        videoUrl: 'http://cdn/video.m4s',
        audioUrl: 'http://cdn/audio.m4s',
        dio: dio,
        danmakuService: _stubDanmakuService(),
        subtitleService: _stubSubtitleService(),
        chapterService: _stubChapterService(),
        retryDelayProvider: (delay, cancelToken) async {},
      );

      expect(executor.execute(), throwsA(isA<DioException>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 首次 416 (触发展开自愈) + 自愈后仍 416 (触发单次自愈熔断) = 2 次，绝不无限循环
      expect(videoCallCount, equals(2));

      executor.dispose();
    });
  });
}

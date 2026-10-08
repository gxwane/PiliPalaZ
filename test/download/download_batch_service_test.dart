import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/services/download/download_dao.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';
import 'package:pilipalaz/services/download/download_task_executor.dart';
import 'package:pilipalaz/services/download/offline_chapter_service.dart';
import 'package:pilipalaz/services/download/offline_danmaku_service.dart';
import 'package:pilipalaz/services/download/offline_subtitle_service.dart';

DownloadTask _makeTask({
  String bvid = 'BVbatch',
  required int cid,
  String title = 'Batch Video',
  DateTime? createdAt,
}) {
  return DownloadTask.create(
    bvid: bvid,
    cid: cid,
    title: '$title P$cid',
    cover: '',
    ownerName: 'UP',
    duration: 60,
    videoQuality: 80,
    videoQualityDesc: '1080P',
    videoCodec: 'avc1',
    audioQuality: 30280,
    createdAt: createdAt,
  );
}

class _MockDownloadExecutor extends DownloadTaskExecutor {
  _MockDownloadExecutor({
    required super.task,
    required super.storageManager,
    required super.videoUrl,
    required super.audioUrl,
    super.onProgress,
    this.onExecute,
  }) : super(
         danmakuService: OfflineDanmakuService(
           danmakuFetcher: ({required cid, required segmentIndex}) async =>
               const ApiFailure(kind: ApiFailureKind.network, message: 'dummy'),
         ),
         subtitleService: OfflineSubtitleService(
           videoMetaFetcher: ({aid, bvid, required cid}) async =>
               const ApiFailure(kind: ApiFailureKind.network, message: 'dummy'),
         ),
         chapterService: OfflineChapterService(
           chapterFetcher: ({aid, bvid, required cid}) async =>
               const ApiFailure(kind: ApiFailureKind.network, message: 'dummy'),
         ),
       );

  final Future<DownloadTaskStatus> Function()? onExecute;

  @override
  Future<DownloadTaskStatus> execute() async {
    if (onExecute != null) {
      return onExecute!();
    }
    return DownloadTaskStatus.completed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late DownloadDao dao;
  late DownloadStorageManager storageManager;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('dl_batch_test_');
    Hive.init(tmpDir.path);
    dao = await DownloadDao.init();
    storageManager = DownloadStorageManager(
      directoryProvider: () async => tmpDir,
      diskSpaceProvider: (_) async => 10 * 1024 * 1024 * 1024, // 10 GB
    );
  });

  tearDown(() async {
    try {
      await DownloadService.instance.dispose();
    } catch (_) {}
    await dao.dispose();
    await Hive.close();
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  group('DownloadService 批量下载与队列调度治理', () {
    test('TEST-BATCH-01: startTasks 批量原子入库与路径自动分配', () async {
      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
        maxConcurrent: 2,
        urlResolver: (task) async => const ResolvedDownloadUrls(
          videoUrl: 'http://mock/video',
          audioUrl: 'http://mock/audio',
        ),
        executorFactory:
            ({
              required task,
              required storageManager,
              required videoUrl,
              required audioUrl,
              onProgress,
            }) => _MockDownloadExecutor(
              task: task,
              storageManager: storageManager,
              videoUrl: videoUrl,
              audioUrl: audioUrl,
              onProgress: onProgress,
              onExecute: () async {
                // 挂起，保持 downloading
                await Completer<void>().future;
                return DownloadTaskStatus.completed;
              },
            ),
      );

      final tasks = [_makeTask(cid: 1), _makeTask(cid: 2), _makeTask(cid: 3)];

      final saved = await service.startTasks(tasks);
      expect(saved.length, equals(3));
      expect(dao.taskCount, equals(3));

      // 验证路径自动分配
      for (final t in saved) {
        expect(t.videoRelativePath, isNotNull);
        expect(t.audioRelativePath, isNotNull);
        expect(t.chaptersRelativePath, isNotNull);
      }

      // 验证并发槽位：前 2 个进入 downloading，第 3 个保持 pending
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(service.activeCount, equals(2));
      final allTasks = service.getAllTasks();
      final downloadingCount = allTasks
          .where((t) => t.status == DownloadTaskStatus.downloading)
          .length;
      final pendingCount = allTasks
          .where((t) => t.status == DownloadTaskStatus.pending)
          .length;
      expect(downloadingCount, equals(2));
      expect(pendingCount, equals(1));
    });

    test('TEST-BATCH-02: 服务层磁盘不足水位安全防御', () async {
      // 模拟磁盘剩余空间不足 200MB (100MB)
      final lowStorageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 100 * 1024 * 1024,
      );

      final service = await DownloadService.init(
        dao: dao,
        storageManager: lowStorageManager,
      );

      // 1. 批量提交直接被拒绝为 failed
      final tasks = [_makeTask(cid: 10), _makeTask(cid: 11)];
      final result = await service.startTasks(tasks);

      expect(result.length, equals(2));
      for (final t in result) {
        expect(t.status, equals(DownloadTaskStatus.failed));
        expect(t.errorMessage, contains('低于安全水位 200MB'));
      }
      expect(service.activeCount, equals(0));

      // 2. resumeTask 同样拦截
      await service.resumeTask('BVbatch_10');
      final resumed = service.getTask('BVbatch_10');
      expect(resumed?.status, equals(DownloadTaskStatus.failed));
      expect(resumed?.errorMessage, contains('低于安全水位 200MB'));

      // 3. resumeAll 同样拦截
      await service.resumeAll();
      for (final t in service.getAllTasks()) {
        expect(t.status, equals(DownloadTaskStatus.failed));
      }
    });

    test('TEST-BATCH-03: 动态并发槽位 (updateMaxConcurrent 1~4) 与队列自动消耗', () async {
      final completers = <String, Completer<DownloadTaskStatus>>{};

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
        maxConcurrent: 1, // 初始 1 个槽位
        urlResolver: (task) async => const ResolvedDownloadUrls(
          videoUrl: 'http://mock/video',
          audioUrl: 'http://mock/audio',
        ),
        executorFactory:
            ({
              required task,
              required storageManager,
              required videoUrl,
              required audioUrl,
              onProgress,
            }) {
              final c = Completer<DownloadTaskStatus>();
              completers[task.id] = c;
              return _MockDownloadExecutor(
                task: task,
                storageManager: storageManager,
                videoUrl: videoUrl,
                audioUrl: audioUrl,
                onProgress: onProgress,
                onExecute: () => c.future,
              );
            },
      );

      expect(service.maxConcurrent, equals(1));

      // 提交 3 个任务
      await service.startTasks([
        _makeTask(cid: 1),
        _makeTask(cid: 2),
        _makeTask(cid: 3),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(service.activeCount, equals(1));
      expect(
        service.getTask('BVbatch_1')!.status,
        equals(DownloadTaskStatus.downloading),
      );
      expect(
        service.getTask('BVbatch_2')!.status,
        equals(DownloadTaskStatus.pending),
      );

      // 动态扩容槽位到 2
      service.updateMaxConcurrent(2);
      expect(service.maxConcurrent, equals(2));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // 槽位增加后，第 2 个任务自动被调度
      expect(service.activeCount, equals(2));
      expect(
        service.getTask('BVbatch_2')!.status,
        equals(DownloadTaskStatus.downloading),
      );
      expect(
        service.getTask('BVbatch_3')!.status,
        equals(DownloadTaskStatus.pending),
      );

      // 边界钳制测试 (0 被钳制为 1，5 被钳制为 4)
      service.updateMaxConcurrent(0);
      expect(service.maxConcurrent, equals(1));
      service.updateMaxConcurrent(5);
      expect(service.maxConcurrent, equals(4));

      // 完成任务 1 和 2，任务 3 自动消耗完成
      completers['BVbatch_1']?.complete(DownloadTaskStatus.completed);
      completers['BVbatch_2']?.complete(DownloadTaskStatus.completed);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        service.getTask('BVbatch_3')!.status,
        equals(DownloadTaskStatus.downloading),
      );
      completers['BVbatch_3']?.complete(DownloadTaskStatus.completed);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.activeCount, equals(0));
      expect(
        service.getTask('BVbatch_3')!.status,
        equals(DownloadTaskStatus.completed),
      );
    });

    test('TEST-BATCH-04: 多 P 同批次任务严格按分 P (cid) 升序调度', () async {
      final scheduledOrder = <int>[];
      final completers = <String, Completer<DownloadTaskStatus>>{};

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
        maxConcurrent: 1, // 单槽位串行验证顺序
        urlResolver: (task) async => const ResolvedDownloadUrls(
          videoUrl: 'http://mock/video',
          audioUrl: 'http://mock/audio',
        ),
        executorFactory:
            ({
              required task,
              required storageManager,
              required videoUrl,
              required audioUrl,
              onProgress,
            }) {
              scheduledOrder.add(task.cid);
              final c = Completer<DownloadTaskStatus>();
              completers[task.id] = c;
              return _MockDownloadExecutor(
                task: task,
                storageManager: storageManager,
                videoUrl: videoUrl,
                audioUrl: audioUrl,
                onProgress: onProgress,
                onExecute: () => c.future,
              );
            },
      );

      final now = DateTime.now();
      Future<void> waitForOrderLength(int targetLength) async {
        for (int i = 0; i < 50; i++) {
          if (scheduledOrder.length >= targetLength) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      // 乱序加入: cid 3, cid 1, cid 2 (创建时间一致)
      await service.startTasks([
        _makeTask(cid: 3, createdAt: now),
        _makeTask(cid: 1, createdAt: now),
        _makeTask(cid: 2, createdAt: now),
      ]);
      await waitForOrderLength(1);

      // 应当首先调度 cid 1
      expect(scheduledOrder, equals([1]));

      // 完成 cid 1，接下来应当调度 cid 2
      completers['BVbatch_1']?.complete(DownloadTaskStatus.completed);
      await waitForOrderLength(2);
      expect(scheduledOrder, equals([1, 2]));

      // 完成 cid 2，接下来应当调度 cid 3
      completers['BVbatch_2']?.complete(DownloadTaskStatus.completed);
      await waitForOrderLength(3);
      expect(scheduledOrder, equals([1, 2, 3]));

      completers['BVbatch_3']?.complete(DownloadTaskStatus.completed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.activeCount, equals(0));
    });

    test('TEST-BATCH-05: DownloadTask.copyWith 严密保持原始 createdAt 不变', () {
      final originTime = DateTime(2025, 1, 1, 12, 0, 0);
      final task = _makeTask(cid: 99, createdAt: originTime);
      expect(task.createdAt, equals(originTime));

      // 调用 copyWith 且不传 createdAt
      final copied = task.copyWith(status: DownloadTaskStatus.downloading);
      expect(copied.createdAt, equals(originTime));

      // 显式传入新 createdAt
      final newTime = DateTime(2025, 2, 1, 12, 0, 0);
      final copiedWithNewTime = task.copyWith(createdAt: newTime);
      expect(copiedWithNewTime.createdAt, equals(newTime));
    });
  });
}

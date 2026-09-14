import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/pages/download/controller.dart';
import 'package:pilipalaz/services/download/download_dao.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';

DownloadTask _makeTask({
  required String id,
  required DownloadTaskStatus status,
  int totalBytes = 1000,
  int downloadedBytes = 500,
  int speed = 0,
}) {
  final parts = id.split('_');
  return DownloadTask(
    id: id,
    bvid: parts.first,
    cid: int.parse(parts.last),
    title: '任务 $id',
    partTitle: 'P1',
    cover: 'https://example.com/pic.jpg',
    ownerName: 'UP主',
    duration: 300,
    videoQuality: 80,
    videoQualityDesc: '1080P',
    videoCodec: 'avc1',
    audioQuality: 30280,
    status: status,
    totalBytes: totalBytes,
    downloadedBytes: downloadedBytes,
    downloadSpeed: speed,
  );
}

void main() {
  group('DownloadPageController 工具方法测试', () {
    test('formatBytes 格式化覆盖各种量级', () {
      expect(DownloadPageController.formatBytes(0), equals('0 B'));
      expect(DownloadPageController.formatBytes(500), equals('500 B'));
      expect(DownloadPageController.formatBytes(1024), equals('1.0 KB'));
      expect(DownloadPageController.formatBytes(1536), equals('1.5 KB'));
      expect(DownloadPageController.formatBytes(1048576), equals('1.0 MB'));
      expect(DownloadPageController.formatBytes(1073741824), equals('1.0 GB'));
    });

    test('formatSpeed 格式化下载速度', () {
      expect(DownloadPageController.formatSpeed(0), equals('0 KB/s'));
      expect(DownloadPageController.formatSpeed(1048576), equals('1.0 MB/s'));
    });

    test('formatDuration 格式化分秒与时分秒', () {
      expect(DownloadPageController.formatDuration(0), equals('00:00'));
      expect(DownloadPageController.formatDuration(45), equals('00:45'));
      expect(DownloadPageController.formatDuration(125), equals('02:05'));
      expect(DownloadPageController.formatDuration(3665), equals('01:01:05'));
    });
  });

  group('DownloadPageController 任务分类与操作', () {
    late Directory tempDir;
    late DownloadDao dao;
    late DownloadStorageManager storageManager;
    late DownloadService service;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('dl_page_ctr_test_');
      Hive.init(tempDir.path);
      dao = await DownloadDao.init();
      storageManager = DownloadStorageManager(
        directoryProvider: () async => tempDir,
        diskSpaceProvider: (_) async => 10 * 1024 * 1024 * 1024,
      );
      service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );
    });

    tearDown(() async {
      await service.dispose();
      await dao.dispose();
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('refreshTasks 正确分类已完成和进行中任务', () async {
      // 写入 2 个已完成，1 个下载中，1 个暂停
      await dao.saveTask(
        _makeTask(id: 'BV1_101', status: DownloadTaskStatus.completed),
      );
      await dao.saveTask(
        _makeTask(id: 'BV1_102', status: DownloadTaskStatus.completed),
      );
      await dao.saveTask(
        _makeTask(id: 'BV2_201', status: DownloadTaskStatus.downloading),
      );
      await dao.saveTask(
        _makeTask(id: 'BV2_202', status: DownloadTaskStatus.paused),
      );

      final controller = DownloadPageController(
        downloadService: service,
        storageManager: storageManager,
      );
      controller.onInit();

      expect(controller.completedTasks.length, equals(2));
      expect(controller.activeTasks.length, equals(2));

      controller.onClose();
    });

    test('deleteTask 移除指定任务', () async {
      await dao.saveTask(
        _makeTask(id: 'BVdel_1', status: DownloadTaskStatus.completed),
      );

      final controller = DownloadPageController(
        downloadService: service,
        storageManager: storageManager,
      );
      controller.onInit();

      expect(controller.completedTasks.length, equals(1));

      await controller.deleteTask('BVdel_1', deleteFiles: false);

      expect(controller.completedTasks.length, equals(0));
      expect(dao.getTask('BVdel_1'), isNull);

      controller.onClose();
    });
  });
}

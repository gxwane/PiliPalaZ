import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/services/download/download_dao.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';

DownloadTask _task({
  String bvid = 'BV1test',
  int cid = 100,
  DownloadTaskStatus status = DownloadTaskStatus.pending,
}) {
  return DownloadTask.create(
    bvid: bvid,
    cid: cid,
    title: '测试',
    cover: '',
    ownerName: 'UP',
    duration: 120,
    videoQuality: 80,
    videoQualityDesc: '1080P',
    videoCodec: 'avc1.640032',
    audioQuality: 30280,
  )..status = status;
}

void main() {
  group('DownloadStorageManager', () {
    late Directory tmpDir;
    late DownloadStorageManager manager;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('storage_mgr_test_');
      manager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 500 * 1024 * 1024, // 500 MB
      );
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('getRootPath 创建下载根目录', () async {
      final root = await manager.getRootPath();
      expect(root, contains('pilipalaz_downloads'));
      expect(Directory(root).existsSync(), isTrue);

      // 二次调用返回相同路径（缓存）
      final root2 = await manager.getRootPath();
      expect(root2, equals(root));
    });

    test('pathsForTask 生成标准相对路径', () {
      final task = _task(bvid: 'BV1abc', cid: 42);
      final paths = manager.pathsForTask(task);

      expect(paths.videoRelativePath, contains('BV1abc_42'));
      expect(paths.videoRelativePath, endsWith('video.m4s'));
      expect(paths.audioRelativePath, endsWith('audio.m4s'));
      expect(paths.danmakuRelativePath, endsWith('danmaku.bin'));
      expect(paths.coverRelativePath, endsWith('cover.jpg'));
    });

    test('absolutePath 将相对路径转为绝对路径', () async {
      final abs = await manager.absolutePath('BV1_1/video.m4s');
      expect(abs, contains('pilipalaz_downloads'));
      expect(abs, contains('BV1_1'));
    });

    test('hasEnoughSpace 检测磁盘容量', () async {
      // 500 MB 可用，预估 100 MB，需 100+200=300 MB < 500 MB → 充足
      expect(await manager.hasEnoughSpace(100 * 1024 * 1024), isTrue);

      // 预估 400 MB，需 400+200=600 MB > 500 MB → 不足
      expect(await manager.hasEnoughSpace(400 * 1024 * 1024), isFalse);
    });

    test('isBelowSafetyThreshold 检测安全水位', () async {
      // 500 MB > 200 MB → 未低于水位
      expect(await manager.isBelowSafetyThreshold(), isFalse);

      // 创建磁盘不足的 manager
      final lowManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 100 * 1024 * 1024, // 100 MB
      );
      expect(await lowManager.isBelowSafetyThreshold(), isTrue);
    });

    test('deleteTaskFiles 清理任务目录', () async {
      final task = _task();
      final root = await manager.getRootPath();
      final taskDir = Directory('$root/${manager.taskDirName(task)}');
      await taskDir.create(recursive: true);
      await File('${taskDir.path}/video.m4s').create();
      await File('${taskDir.path}/audio.m4s.part').create();

      expect(taskDir.existsSync(), isTrue);

      await manager.deleteTaskFiles(task);
      expect(taskDir.existsSync(), isFalse);
    });

    test('deleteTaskFiles 目录不存在时不抛异常', () async {
      final task = _task(bvid: 'BVnonexistent', cid: 999);
      // 不应抛异常
      await manager.deleteTaskFiles(task);
    });

    test('taskDiskUsage 计算已占用空间', () async {
      final task = _task();
      final root = await manager.getRootPath();
      final taskDir = Directory('$root/${manager.taskDirName(task)}');
      await taskDir.create(recursive: true);

      // 写入 1000 字节测试文件
      final file = File('${taskDir.path}/video.m4s');
      await file.writeAsBytes(List<int>.filled(1000, 0));

      final usage = await manager.taskDiskUsage(task);
      expect(usage, equals(1000));
    });
  });

  group('DownloadService 冷启动自愈', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('dl_svc_test_');
      Hive.init(tmpDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
      try {
        await DownloadDao.instance.dispose();
      } on AssertionError {
        // ignore
      }
      try {
        await DownloadService.instance.dispose();
      } on AssertionError {
        // ignore
      }
    });

    test('init 将 downloading 僵尸任务重置为 paused', () async {
      final dao = await DownloadDao.init();

      // 模拟应用被杀进程后残留的 downloading 状态
      final zombie = _task(bvid: 'BVzombie', cid: 1)
        ..status = DownloadTaskStatus.downloading;
      await dao.saveTask(zombie);

      final normal = _task(bvid: 'BVnormal', cid: 2)
        ..status = DownloadTaskStatus.completed;
      await dao.saveTask(normal);

      final storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 1024 * 1024 * 1024,
      );

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );

      // 僵尸任务应被自愈为 paused
      final healed = dao.getTask('BVzombie_1')!;
      expect(healed.status, equals(DownloadTaskStatus.paused));

      // 正常任务不受影响
      final intact = dao.getTask('BVnormal_2')!;
      expect(intact.status, equals(DownloadTaskStatus.completed));

      await service.dispose();
      await dao.dispose();
    });

    test('startTask 对已存在的任务直接返回', () async {
      final dao = await DownloadDao.init();
      final storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 1024 * 1024 * 1024,
      );

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );

      // 预先写入一个已完成的任务到 DAO
      final existing = _task(bvid: 'BVdup', cid: 1)
        ..status = DownloadTaskStatus.completed;
      await dao.saveTask(existing);

      // 再次提交相同 ID 的任务，应直接返回已有任务而不重复创建
      final result = await service.startTask(_task(bvid: 'BVdup', cid: 1));
      expect(result, isNotNull);
      expect(result!.status, equals(DownloadTaskStatus.completed));
      expect(dao.taskCount, equals(1)); // 不应重复创建

      await service.dispose();
      await dao.dispose();
    });

    test('pauseTask 与状态流转', () async {
      final dao = await DownloadDao.init();
      final storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 1024 * 1024 * 1024,
      );

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );

      // 手动写入 downloading 状态任务
      final task = _task(bvid: 'BVpause', cid: 1)
        ..status = DownloadTaskStatus.downloading;
      await dao.saveTask(task);

      // 暂停
      await service.pauseTask('BVpause_1');
      expect(dao.getTask('BVpause_1')!.status, DownloadTaskStatus.paused);

      // 验证 isResumable
      expect(dao.getTask('BVpause_1')!.isResumable, isTrue);

      await service.dispose();
      await dao.dispose();
    });

    test('cancelTask 删除元数据和文件', () async {
      final dao = await DownloadDao.init();
      final storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 1024 * 1024 * 1024,
      );

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );

      final task = _task(bvid: 'BVcancel', cid: 1);
      await dao.saveTask(task);

      // 创建模拟文件
      final root = await storageManager.getRootPath();
      final taskDir = Directory('$root/BVcancel_1');
      await taskDir.create(recursive: true);
      await File('${taskDir.path}/video.m4s.part').create();

      await service.cancelTask('BVcancel_1');

      expect(dao.getTask('BVcancel_1'), isNull);
      expect(taskDir.existsSync(), isFalse);

      await service.dispose();
      await dao.dispose();
    });

    test('pauseAll 暂停所有下载中的任务', () async {
      final dao = await DownloadDao.init();
      final storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 1024 * 1024 * 1024,
      );

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );

      // 手动写入几个 downloading 状态任务
      await dao.saveTask(
        _task(bvid: 'BVa', cid: 1)..status = DownloadTaskStatus.downloading,
      );
      await dao.saveTask(
        _task(bvid: 'BVb', cid: 2)..status = DownloadTaskStatus.downloading,
      );

      await service.pauseAll();

      expect(dao.getTask('BVa_1')!.status, DownloadTaskStatus.paused);
      expect(dao.getTask('BVb_2')!.status, DownloadTaskStatus.paused);

      await service.dispose();
      await dao.dispose();
    });

    test('taskUpdates 广播流推送状态变更', () async {
      final dao = await DownloadDao.init();
      final storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 1024 * 1024 * 1024,
      );

      final service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );

      final List<DownloadTaskStatus> statuses = <DownloadTaskStatus>[];
      final sub = service.taskUpdates.listen((DownloadTask t) {
        statuses.add(t.status);
      });

      final task = _task(bvid: 'BVstream', cid: 1)
        ..status = DownloadTaskStatus.downloading;
      await dao.saveTask(task);

      await service.pauseTask('BVstream_1');

      // 等待流事件传递
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(statuses, contains(DownloadTaskStatus.paused));

      await sub.cancel();
      await service.dispose();
      await dao.dispose();
    });
  });
}

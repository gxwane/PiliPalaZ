import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/services/download/download_dao.dart';

/// 构建测试用 [DownloadTask] 实例。
DownloadTask _createTask({
  String bvid = 'BV1test123',
  int cid = 12345,
  int? aid = 67890,
  String title = '测试视频标题',
  String partTitle = 'P1 第一部分',
  String cover = 'https://example.com/cover.jpg',
  String ownerName = '测试UP主',
  int duration = 600,
  int videoQuality = 80,
  String videoQualityDesc = '1080P 高清',
  String videoCodec = 'avc1.640032',
  int audioQuality = 30280,
  DownloadTaskStatus status = DownloadTaskStatus.pending,
}) {
  return DownloadTask.create(
    bvid: bvid,
    cid: cid,
    aid: aid,
    title: title,
    partTitle: partTitle,
    cover: cover,
    ownerName: ownerName,
    duration: duration,
    videoQuality: videoQuality,
    videoQualityDesc: videoQualityDesc,
    videoCodec: videoCodec,
    audioQuality: audioQuality,
  )..status = status;
}

void main() {
  group('DownloadTaskStatus', () {
    test('fromString 还原所有合法枚举值', () {
      for (final DownloadTaskStatus s in DownloadTaskStatus.values) {
        expect(DownloadTaskStatus.fromString(s.name), equals(s));
      }
    });

    test('fromString 未知值回退为 pending', () {
      expect(
        DownloadTaskStatus.fromString('unknown'),
        DownloadTaskStatus.pending,
      );
      expect(DownloadTaskStatus.fromString(null), DownloadTaskStatus.pending);
      expect(DownloadTaskStatus.fromString(''), DownloadTaskStatus.pending);
    });
  });

  group('DownloadTask 模型', () {
    test('create 工厂正确生成 ID', () {
      final task = _createTask(bvid: 'BV1abc', cid: 999);
      expect(task.id, equals('BV1abc_999'));
      expect(task.status, equals(DownloadTaskStatus.pending));
      expect(task.progress, equals(0.0));
      expect(
        task.createdAt.isBefore(DateTime.now().add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('progress 计算覆盖边界', () {
      final task = _createTask()
        ..totalBytes = 1000
        ..downloadedBytes = 500;
      expect(task.progress, closeTo(0.5, 0.001));

      task.downloadedBytes = 0;
      expect(task.progress, equals(0.0));

      task.downloadedBytes = 1000;
      expect(task.progress, equals(1.0));

      // totalBytes 为 0 时安全返回 0
      task.totalBytes = 0;
      expect(task.progress, equals(0.0));

      // 超出范围被 clamp
      task
        ..totalBytes = 100
        ..downloadedBytes = 200;
      expect(task.progress, equals(1.0));
    });

    test('isTerminal 与 isResumable 状态判定', () {
      final task = _createTask();

      task.status = DownloadTaskStatus.pending;
      expect(task.isTerminal, isFalse);
      expect(task.isResumable, isFalse);

      task.status = DownloadTaskStatus.downloading;
      expect(task.isTerminal, isFalse);
      expect(task.isResumable, isFalse);

      task.status = DownloadTaskStatus.paused;
      expect(task.isTerminal, isFalse);
      expect(task.isResumable, isTrue);

      task.status = DownloadTaskStatus.completed;
      expect(task.isTerminal, isTrue);
      expect(task.isResumable, isFalse);

      task.status = DownloadTaskStatus.failed;
      expect(task.isTerminal, isTrue);
      expect(task.isResumable, isTrue);
    });

    test('toMap / fromMap 往返序列化完整性', () {
      final original = _createTask()
        ..videoRelativePath = 'BV1test123_12345/video.m4s'
        ..audioRelativePath = 'BV1test123_12345/audio.m4s'
        ..danmakuRelativePath = 'BV1test123_12345/danmaku.bin'
        ..coverRelativePath = 'BV1test123_12345/cover.jpg'
        ..status = DownloadTaskStatus.downloading
        ..totalBytes = 104857600
        ..downloadedBytes = 52428800
        ..errorMessage = null;

      final map = original.toMap();
      final restored = DownloadTask.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.bvid, equals(original.bvid));
      expect(restored.cid, equals(original.cid));
      expect(restored.aid, equals(original.aid));
      expect(restored.title, equals(original.title));
      expect(restored.partTitle, equals(original.partTitle));
      expect(restored.cover, equals(original.cover));
      expect(restored.ownerName, equals(original.ownerName));
      expect(restored.duration, equals(original.duration));
      expect(restored.videoQuality, equals(original.videoQuality));
      expect(restored.videoQualityDesc, equals(original.videoQualityDesc));
      expect(restored.videoCodec, equals(original.videoCodec));
      expect(restored.audioQuality, equals(original.audioQuality));
      expect(restored.videoRelativePath, equals(original.videoRelativePath));
      expect(restored.audioRelativePath, equals(original.audioRelativePath));
      expect(
        restored.danmakuRelativePath,
        equals(original.danmakuRelativePath),
      );
      expect(restored.coverRelativePath, equals(original.coverRelativePath));
      expect(
        restored.subtitlesRelativePath,
        equals(original.subtitlesRelativePath),
      );
      expect(restored.status, equals(original.status));
      expect(restored.totalBytes, equals(original.totalBytes));
      expect(restored.downloadedBytes, equals(original.downloadedBytes));
      expect(restored.errorMessage, isNull);
      expect(
        restored.createdAt.toIso8601String(),
        equals(original.createdAt.toIso8601String()),
      );
    });

    test('fromMap 对缺失的可选字段提供安全默认值', () {
      final minimalMap = <String, dynamic>{
        'id': 'BV1min_1',
        'bvid': 'BV1min',
        'cid': 1,
        'videoQuality': 80,
        'audioQuality': 30280,
      };

      final task = DownloadTask.fromMap(minimalMap);
      expect(task.id, equals('BV1min_1'));
      expect(task.title, equals(''));
      expect(task.partTitle, equals(''));
      expect(task.cover, equals(''));
      expect(task.ownerName, equals(''));
      expect(task.duration, equals(0));
      expect(task.videoQualityDesc, equals(''));
      expect(task.videoCodec, equals(''));
      expect(task.status, equals(DownloadTaskStatus.pending));
      expect(task.totalBytes, equals(0));
      expect(task.downloadedBytes, equals(0));
      expect(task.errorMessage, isNull);
      expect(task.videoRelativePath, isNull);
      expect(task.subtitlesRelativePath, isNull);
    });

    test('toMap 不包含 downloadSpeed（瞬态字段）', () {
      final task = _createTask()..downloadSpeed = 1024000;
      final map = task.toMap();
      expect(map.containsKey('downloadSpeed'), isFalse);
    });

    test('copyWith 保持不变量并仅更新指定字段', () {
      final original = _createTask()
        ..totalBytes = 1000
        ..downloadedBytes = 500;

      final updated = original.copyWith(
        status: DownloadTaskStatus.completed,
        downloadedBytes: 1000,
        completedAt: DateTime(2026, 9, 14),
      );

      // 不变字段
      expect(updated.id, equals(original.id));
      expect(updated.bvid, equals(original.bvid));
      expect(updated.title, equals(original.title));
      expect(updated.videoCodec, equals(original.videoCodec));
      expect(updated.totalBytes, equals(1000));

      // 已更新字段
      expect(updated.status, equals(DownloadTaskStatus.completed));
      expect(updated.downloadedBytes, equals(1000));
      expect(updated.completedAt, equals(DateTime(2026, 9, 14)));

      // 原始对象不受影响
      expect(original.status, equals(DownloadTaskStatus.pending));
      expect(original.downloadedBytes, equals(500));
    });

    test('copyWith errorMessage 显式传 null 清空错误信息', () {
      final original = _createTask()..errorMessage = '网络错误';
      final cleared = original.copyWith(errorMessage: null);
      expect(cleared.errorMessage, isNull);
    });

    test('equality 基于 id', () {
      final a = _createTask(bvid: 'BV1x', cid: 1);
      final b = _createTask(bvid: 'BV1x', cid: 1);
      final c = _createTask(bvid: 'BV1y', cid: 2);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString 包含关键信息', () {
      final task = _createTask()..status = DownloadTaskStatus.downloading;
      expect(task.toString(), contains('BV1test123_12345'));
      expect(task.toString(), contains('downloading'));
    });
  });

  group('DownloadDao 持久化', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('download_dao_test_');
      Hive.init(tmpDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
      // 重置单例以避免测试间泄漏
      try {
        await DownloadDao.instance.dispose();
      } on AssertionError {
        // 若 instance 未初始化则忽略
      }
    });

    test('init 加载空 Box 返回空列表', () async {
      final dao = await DownloadDao.init();
      expect(dao.getAllTasks(), isEmpty);
      expect(dao.taskCount, equals(0));
      await dao.dispose();
    });

    test('saveTask 与 getTask 往返一致', () async {
      final dao = await DownloadDao.init();
      final task = _createTask();

      await dao.saveTask(task);
      expect(dao.taskCount, equals(1));

      final loaded = dao.getTask(task.id);
      expect(loaded, isNotNull);
      expect(loaded!.id, equals(task.id));
      expect(loaded.bvid, equals(task.bvid));
      expect(loaded.title, equals(task.title));
      await dao.dispose();
    });

    test('saveTask 更新已有任务状态', () async {
      final dao = await DownloadDao.init();
      final task = _createTask();
      await dao.saveTask(task);

      final updated = task.copyWith(
        status: DownloadTaskStatus.downloading,
        downloadedBytes: 1024,
      );
      await dao.saveTask(updated);

      expect(dao.taskCount, equals(1));
      final loaded = dao.getTask(task.id)!;
      expect(loaded.status, equals(DownloadTaskStatus.downloading));
      expect(loaded.downloadedBytes, equals(1024));
      await dao.dispose();
    });

    test('deleteTask 移除缓存与持久化', () async {
      final dao = await DownloadDao.init();
      final task = _createTask();
      await dao.saveTask(task);
      expect(dao.taskCount, equals(1));

      await dao.deleteTask(task.id);
      expect(dao.taskCount, equals(0));
      expect(dao.getTask(task.id), isNull);
      await dao.dispose();
    });

    test('saveTasks 批量写入多个任务', () async {
      final dao = await DownloadDao.init();
      final tasks = [
        _createTask(bvid: 'BV1a', cid: 1),
        _createTask(bvid: 'BV1b', cid: 2),
        _createTask(bvid: 'BV1c', cid: 3),
      ];

      await dao.saveTasks(tasks);
      expect(dao.taskCount, equals(3));
      expect(dao.getTask('BV1b_2'), isNotNull);
      await dao.dispose();
    });

    test('getAllTasks 返回不可变快照', () async {
      final dao = await DownloadDao.init();
      await dao.saveTask(_createTask(bvid: 'BV1x', cid: 1));
      await dao.saveTask(_createTask(bvid: 'BV1y', cid: 2));

      final snapshot = dao.getAllTasks();
      expect(snapshot.length, equals(2));

      // 快照不应受后续变更影响
      await dao.deleteTask('BV1x_1');
      expect(snapshot.length, equals(2)); // 快照不变
      expect(dao.taskCount, equals(1)); // 实际已删除
      await dao.dispose();
    });

    test('init 从已有 Box 恢复缓存', () async {
      // 第一次：写入数据
      final dao1 = await DownloadDao.init();
      await dao1.saveTask(_createTask(bvid: 'BV1persist', cid: 42));
      await dao1.dispose();

      // 第二次：重新初始化，验证数据恢复
      final dao2 = await DownloadDao.init();
      expect(dao2.taskCount, equals(1));
      final restored = dao2.getTask('BV1persist_42');
      expect(restored, isNotNull);
      expect(restored!.bvid, equals('BV1persist'));
      await dao2.dispose();
    });
  });
}

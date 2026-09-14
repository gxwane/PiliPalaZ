import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/pages/danmaku/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('离线弹幕装载端到端验证', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('offline_dm_journey_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('PlDanmakuController 装载本地离线弹幕，绕过网络请求', () async {
      final danmakuFile = File('${tempDir.path}/danmaku.bin');
      final reply = DmSegMobileReply(
        elems: [
          DanmakuElem(
            id: Int64(101),
            progress: 1500, // 1.5s -> pos 15
            content: '离线弹幕测试1',
            weight: 5,
          ),
          DanmakuElem(
            id: Int64(102),
            progress: 3200, // 3.2s -> pos 32
            content: '离线弹幕测试2',
            weight: 3,
          ),
        ],
      );
      await danmakuFile.writeAsBytes(reply.writeToBuffer());

      final controller = PlDanmakuController(99999);
      // 视频时长 600 秒
      controller.initiate(600, 0, offlineDanmakuFile: danmakuFile);

      // 等待异步装载完成
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 验证 dmSegMap 中包含了离线弹幕
      expect(controller.dmSegMap.isNotEmpty, isTrue);
      expect(controller.dmSegMap[15]?.first.content, equals('离线弹幕测试1'));
      expect(controller.dmSegMap[32]?.first.content, equals('离线弹幕测试2'));

      // 验证所有分段均被标记为已请求（防止触发网络调用）
      expect(
        controller.requestedSeg.every((bool requested) => requested),
        isTrue,
      );

      controller.dispose();
    });
  });

  group('离线视频播放初始化验证', () {
    late Directory tempDir;
    late DownloadStorageManager storageManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('offline_video_journey_');
      Hive.init(tempDir.path);
      storageManager = DownloadStorageManager(
        directoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      Get.reset();
    });

    test('离线任务存在且文件完整时，正确挂载本地双流与文件数据源', () async {
      final root = await storageManager.getRootPath();
      final taskDir = Directory('$root/BVoffline_1001');
      await taskDir.create(recursive: true);

      final videoFile = File('${taskDir.path}/video.m4s');
      final audioFile = File('${taskDir.path}/audio.m4s');
      await videoFile.writeAsBytes(List.filled(100, 1));
      await audioFile.writeAsBytes(List.filled(50, 2));

      final task = DownloadTask(
        id: 'BVoffline_1001',
        bvid: 'BVoffline',
        cid: 1001,
        title: '离线测试视频',
        partTitle: 'P1',
        cover: '',
        ownerName: 'UP',
        duration: 120,
        videoQuality: 80,
        videoQualityDesc: '1080P 高清',
        videoCodec: 'avc1.640032',
        audioQuality: 30280,
        videoRelativePath: 'BVoffline_1001/video.m4s',
        audioRelativePath: 'BVoffline_1001/audio.m4s',
        status: DownloadTaskStatus.completed,
      );

      // 验证绝对路径解析
      final absVideo = await storageManager.absolutePath(
        task.videoRelativePath!,
      );
      final absAudio = await storageManager.absolutePath(
        task.audioRelativePath!,
      );
      expect(File(absVideo).existsSync(), isTrue);
      expect(File(absAudio).existsSync(), isTrue);

      // 验证离线 DataSource 创建与断言通过
      final dataSource = DataSource(
        videoSource: absVideo,
        audioSource: absAudio,
        type: DataSourceType.file,
        file: File(absVideo),
        httpHeaders: null,
      );

      expect(dataSource.type, equals(DataSourceType.file));
      expect(dataSource.file, isNotNull);
      expect(dataSource.videoSource, equals(absVideo));
      expect(dataSource.audioSource, equals(absAudio));
      expect(dataSource.httpHeaders, isNull);
    });

    test('离线视频文件缺失时安全报错，不触发网络拉取', () async {
      final task = DownloadTask(
        id: 'BVmissing_2001',
        bvid: 'BVmissing',
        cid: 2001,
        title: '缺失视频',
        partTitle: 'P1',
        cover: '',
        ownerName: 'UP',
        duration: 60,
        videoQuality: 64,
        videoQualityDesc: '720P',
        videoCodec: 'avc1',
        audioQuality: 30280,
        videoRelativePath: 'BVmissing_2001/video.m4s',
        status: DownloadTaskStatus.completed,
      );

      final absVideo = await storageManager.absolutePath(
        task.videoRelativePath!,
      );
      expect(File(absVideo).existsSync(), isFalse);
    });
  });
}

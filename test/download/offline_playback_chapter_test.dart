import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
import 'package:pilipalaz/services/audio_handler.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

final class _TestPlaybackAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    audioSessionHandler = _TestPlaybackAudioSession();
    tempDir = await Directory.systemTemp.createTemp(
      'pilipalaz-offline-chapter-test-',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
    videoPlayerServiceHandler = VideoPlayerServiceHandler(
      settingBox: GStorage.setting,
    );
  });

  tearDownAll(() async {
    await PlPlayerController.disposeIfExists();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Offline Chapter Integration & Storage Tests', () {
    late DownloadStorageManager storageManager;

    setUp(() {
      storageManager = DownloadStorageManager(
        directoryProvider: () async => tempDir,
      );
    });

    test('pathsForTask 为新任务分配 chapters.json 相对路径', () {
      final task = DownloadTask.create(
        bvid: 'BV1test_chapter',
        cid: 555666,
        title: '测试离线分章',
        cover: '',
        ownerName: 'UP',
        duration: 200,
        videoQuality: 80,
        videoQualityDesc: '1080P',
        videoCodec: 'avc1',
        audioQuality: 30280,
      );

      final paths = storageManager.pathsForTask(task);
      expect(
        paths.chaptersRelativePath,
        equals('BV1test_chapter_555666${Platform.pathSeparator}chapters.json'),
      );
    });

    test('离线播放装载 chapters.json 自动激活分段断点与当前章节', () async {
      Get.testMode = true;
      PlPlayerController.isHeadlessTestMode = true;
      final controller = PlPlayerController.getInstance();

      final chapterFile = File('${tempDir.path}/test_task/chapters.json');
      await chapterFile.parent.create(recursive: true);
      await chapterFile.writeAsString('''[
        {"from": 0, "to": 80, "title": "第一段: 架构设计"},
        {"from": 80, "to": 240, "title": "第二段: 核心代码实施"},
        {"from": 240, "to": 360, "title": "第三段: 质检验收"}
      ]''');

      final dummyVideo = File('${tempDir.path}/test_task/video.m4s');
      await dummyVideo.writeAsString('video');

      final dataSource = DataSource(
        type: DataSourceType.file,
        file: dummyVideo,
        videoSource: dummyVideo.path,
        offlineChapterFile: chapterFile,
      );

      // 触发离线装载
      controller.setDataSource(
        dataSource,
        owner: PlayerResourceOwner(),
        seekTo: Duration.zero,
      );

      // 等待异步文件读取完成
      await Future<void>.delayed(const Duration(milliseconds: 150));

      controller.durationSeconds.value = 360;

      // 验证章节正确装载
      expect(controller.chapters.length, equals(3));
      expect(controller.chapters[0].title, equals('第一段: 架构设计'));
      expect(controller.chapters[1].title, equals('第二段: 核心代码实施'));
      expect(controller.chapters[2].title, equals('第三段: 质检验收'));

      // 验证进度条分段切分点自动生成
      expect(
        controller.chapterSplitPoints,
        equals([const Duration(seconds: 80), const Duration(seconds: 240)]),
      );

      // 验证时间落点响应式高亮
      controller.updateCurrentChapter(100);
      expect(controller.currentChapter.value?.title, equals('第二段: 核心代码实施'));

      await PlPlayerController.disposeIfExists();
      Get.reset();
    });

    test('离线无章节文件时安全降级为空列表，不崩溃', () async {
      Get.testMode = true;
      PlPlayerController.isHeadlessTestMode = true;
      final controller = PlPlayerController.getInstance();

      final dummyVideo = File('${tempDir.path}/no_chapter_task/video.m4s');
      await dummyVideo.parent.create(recursive: true);
      await dummyVideo.writeAsString('video');

      final nonExistentChapter = File(
        '${tempDir.path}/no_chapter_task/chapters.json',
      );

      final dataSource = DataSource(
        type: DataSourceType.file,
        file: dummyVideo,
        videoSource: dummyVideo.path,
        offlineChapterFile: nonExistentChapter,
      );

      controller.setDataSource(dataSource, owner: PlayerResourceOwner());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.chapters, isEmpty);
      expect(controller.chapterSplitPoints, isEmpty);
      expect(controller.currentChapter.value, isNull);

      await PlPlayerController.disposeIfExists();
      Get.reset();
    });
  });
}

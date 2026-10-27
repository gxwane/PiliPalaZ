import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/services/audio_handler.dart';
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
      'pilipalaz-subtitle-controller-test-',
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

  group('PlPlayerController Subtitle Engine Dual-Dispatch Tests (Gate 4)', () {
    late PlPlayerController controller;

    setUp(() {
      Get.testMode = true;
      PlPlayerController.isHeadlessTestMode = true;
      controller = PlPlayerController.getInstance();
    });

    tearDown(() async {
      await PlPlayerController.disposeIfExists();
      Get.reset();
    });

    test(
      'controller dispatches SubtitleTrackOption to active engine on setSubtitle',
      () async {
        await controller.setDataSource(
          DataSource(
            videoSource: 'https://test.bilibili.com/video1.mp4',
            type: DataSourceType.network,
          ),
          owner: PlayerResourceOwner(),
          seekTo: Duration.zero,
          duration: const Duration(minutes: 5),
        );

        final engine = controller.engine;
        expect(engine, isA<HeadlessPlayerEngine>());
        final headless = engine as HeadlessPlayerEngine;

        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {
            'title': '中文',
            'language': 'zh-CN',
            'text': 'WEBVTT\n1\n00:00:01.000 --> 00:00:04.000\nHello',
          },
        ];

        // Enable track 1
        controller.setSubtitle(1);
        expect(controller.vttSubtitlesIndex.value, equals(1));
        expect(headless.lastSubtitleTrack, isNotNull);
        expect(headless.lastSubtitleTrack!.data, contains('Hello'));
        expect(headless.lastSubtitleTrack!.label, equals('中文'));
        expect(headless.lastSubtitleTrack!.language, equals('zh-CN'));

        // Disable track (0)
        controller.setSubtitle(0);
        expect(controller.vttSubtitlesIndex.value, equals(0));
        expect(headless.lastSubtitleTrack, equals(SubtitleTrackOption.off));
      },
    );
  });
}

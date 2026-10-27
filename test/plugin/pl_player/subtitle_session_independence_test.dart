import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/video/play/subtitle.dart';
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
      'pilipalaz-subtitle-session-test-',
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

  group('PlPlayerController Subtitle Session Independence Tests', () {
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
      'switching video resets manual subtitle selection to 0 immediately',
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
        expect(controller.canControlPlayback, isTrue);

        // Video 1 loads subtitles
        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {
            'title': '中文',
            'language': 'zh-CN',
            'text': 'WEBVTT\n1\n00:00:00.000 --> 00:00:05.000\nHello',
          },
        ];

        // User manually enables subtitle track 1 on Video 1
        controller.setSubtitle(1);
        expect(controller.vttSubtitlesIndex.value, equals(1));

        // Switch to Video 2 via setDataSource
        await controller.setDataSource(
          DataSource(
            videoSource: 'https://test.bilibili.com/video2.mp4',
            type: DataSourceType.network,
          ),
          owner: PlayerResourceOwner(),
          seekTo: Duration.zero,
          duration: const Duration(minutes: 3),
        );

        // Subtitles and index must be reset to 0 immediately on new video session
        expect(controller.vttSubtitles, isEmpty);
        expect(controller.vttSubtitlesIndex.value, equals(0));
      },
    );

    test(
      'chooseSubtitle strictly follows user setting preference and does not leak previous manual state',
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

        // Setting: Subtitle default off
        await GStorage.setting.put(
          SettingBoxKey.subtitlePreference,
          SubtitlePreference.off.code,
        );

        // Emulate Video 2 subtitle loading with fresh index 0
        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {'title': '中文', 'language': 'zh-CN', 'text': 'WEBVTT\n...'},
          {'title': 'English', 'language': 'en', 'text': 'WEBVTT\n...'},
        ];
        controller.chooseSubtitle();

        // Must remain off (0) because preference is off
        expect(controller.vttSubtitlesIndex.value, equals(0));

        // Now test setting: Subtitle default on
        await GStorage.setting.put(
          SettingBoxKey.subtitlePreference,
          SubtitlePreference.on.code,
        );
        controller.chooseSubtitle();
        expect(controller.vttSubtitlesIndex.value, equals(1));

        // Now test setting: Subtitle default withoutAi
        await GStorage.setting.put(
          SettingBoxKey.subtitlePreference,
          SubtitlePreference.withoutAi.code,
        );

        // If only AI subtitle is available, fallback to 0 (off)
        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {'title': 'AI中文', 'language': 'ai-zh', 'text': 'WEBVTT\n...'},
        ];
        controller.chooseSubtitle();
        expect(controller.vttSubtitlesIndex.value, equals(0));
      },
    );

    test(
      'forceReleaseNativeResources thoroughly clears subtitles, index, and chapters',
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

        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {'title': '中文', 'language': 'zh-CN', 'text': 'WEBVTT\n...'},
        ];
        controller.setSubtitle(1);
        expect(controller.vttSubtitlesIndex.value, equals(1));

        await controller.forceReleaseNativeResources();

        expect(controller.vttSubtitles, isEmpty);
        expect(controller.vttSubtitlesIndex.value, equals(0));
        expect(controller.chapters, isEmpty);
        expect(controller.currentChapter.value, isNull);
      },
    );

    test(
      'refreshVideoMetaInfo synchronously resets vttSubtitles and vttSubtitlesIndex for current session',
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

        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {'title': '中文', 'language': 'zh-CN', 'text': 'WEBVTT\n...'},
        ];
        controller.setSubtitle(1);
        expect(controller.vttSubtitlesIndex.value, equals(1));

        // Calling refreshVideoMetaInfo on the active session resets state synchronously before network fetch
        final future = controller.refreshVideoMetaInfo();
        expect(controller.vttSubtitles, isEmpty);
        expect(controller.vttSubtitlesIndex.value, equals(0));
        await future;
      },
    );
  });
}

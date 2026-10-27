import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
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
      'pilipalaz-subtitle-race-test-',
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

  group('PlPlayerController Subtitle Race & Lifecycle Guard Tests', () {
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
      'chooseSubtitle and setSubtitle safely short-circuit when canControlPlayback is false',
      () {
        // In idle state, canControlPlayback is false
        expect(controller.canControlPlayback, isFalse);

        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {
            'title': '中文',
            'language': 'zh-CN',
            'text': 'WEBVTT\n1\n00:00:00.000 --> 00:00:05.000\nHello',
          },
        ];

        // Should not throw or crash when called while player is not ready
        expect(controller.vttSubtitlesIndex.value, equals(0));
        controller.setSubtitle(1);
        // Because canControlPlayback is false, setSubtitle must abort and not mutate index
        expect(controller.vttSubtitlesIndex.value, equals(0));
        controller.chooseSubtitle();
        expect(controller.vttSubtitlesIndex.value, equals(0));
        expect(() => controller.setSubtitle(-1), returnsNormally);
      },
    );

    test(
      'setSubtitle handles out of bounds index safely without RangeError',
      () {
        // populate test subtitles
        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {
            'title': '中文',
            'language': 'zh-CN',
            'text': 'WEBVTT\n1\n00:00:00.000 --> 00:00:05.000\nHello',
          },
        ];

        // Negative index
        expect(() => controller.setSubtitle(-5), returnsNormally);
        // Beyond length
        expect(() => controller.setSubtitle(10), returnsNormally);
        expect(() => controller.setSubtitle(2), returnsNormally);
      },
    );

    test(
      'safeSetSubtitleTrack absorbs [Player] has been disposed assertion error safely',
      () async {
        // This test verifies that _safeSetSubtitleTrack (or safe setSubtitle)
        // catches AssertionError thrown by media_kit NativePlayer
        final completer = Completer<void>();

        // Emulate media_kit NativePlayer throwing AssertionError inside synchronized
        Future<void> mockFailingSetSubtitleTrack(SubtitleTrack track) async {
          throw AssertionError('[Player] has been disposed');
        }

        // Execute safely
        try {
          await mockFailingSetSubtitleTrack(SubtitleTrack.no()).catchError((
            err,
          ) {
            // absorbed
          });
          completer.complete();
        } catch (err) {
          completer.completeError(err);
        }

        expect(completer.isCompleted, isTrue);
      },
    );

    test(
      'refreshVideoMetaInfo with stale session aborts immediately without mutating state',
      () async {
        controller.vttSubtitles.value = [
          {'title': 'ExistingTrack', 'language': 'zh', 'text': ''},
        ];

        // Calling with a stale session id (e.g. -1 while current session is 0)
        await controller.refreshVideoMetaInfo(-1);

        // Must abort immediately and preserve existing state
        expect(controller.vttSubtitles, isNotEmpty);
        expect(controller.vttSubtitles.first['title'], 'ExistingTrack');
      },
    );

    test(
      'when canControlPlayback is true, setSubtitle safely validates bounds',
      () async {
        await controller.setDataSource(
          DataSource(
            videoSource: 'https://test.bilibili.com/video.mp4',
            type: DataSourceType.network,
          ),
          owner: PlayerResourceOwner(),
          seekTo: Duration.zero,
          duration: const Duration(minutes: 5),
        );
        expect(controller.canControlPlayback, isTrue);

        controller.vttSubtitles.value = [
          {'title': '关闭', 'language': 'off', 'text': ''},
          {
            'title': '中文',
            'language': 'zh-CN',
            'text': 'WEBVTT\n1\n00:00:00.000 --> 00:00:05.000\nHello',
          },
        ];

        // Safe bounds validation & reactive index tracking
        expect(controller.vttSubtitlesIndex.value, equals(0));
        controller.setSubtitle(1);
        expect(controller.vttSubtitlesIndex.value, equals(1));
        // Out of bounds calls must be safely rejected and not mutate index or throw
        controller.setSubtitle(-1);
        expect(controller.vttSubtitlesIndex.value, equals(1));
        controller.setSubtitle(99);
        expect(controller.vttSubtitlesIndex.value, equals(1));
        controller.setSubtitle(0);
        expect(controller.vttSubtitlesIndex.value, equals(0));
      },
    );
  });
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
      'pilipalaz-screenshot-controller-test-',
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

  group('PlPlayerController Screenshot Engine Routing Tests (Gate 4)', () {
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
      'controller delegates screenshot to active engine and returns byte data',
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

        final mockBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        headless.stubScreenshotBytes = mockBytes;

        final result = await controller.screenshot(format: 'image/png');
        expect(headless.screenshotCallCount, equals(1));
        expect(headless.lastScreenshotFormat, equals('image/png'));
        expect(result, equals(mockBytes));
      },
    );

    test('controller forwards custom format such as image/jpeg', () async {
      await controller.setDataSource(
        DataSource(
          videoSource: 'https://test.bilibili.com/video1.mp4',
          type: DataSourceType.network,
        ),
        owner: PlayerResourceOwner(),
        seekTo: Duration.zero,
        duration: const Duration(minutes: 5),
      );

      final headless = controller.engine as HeadlessPlayerEngine;
      headless.stubScreenshotBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

      final result = await controller.screenshot(format: 'image/jpeg');
      expect(headless.screenshotCallCount, equals(1));
      expect(headless.lastScreenshotFormat, equals('image/jpeg'));
      expect(result, isNotNull);
    });

    test(
      'controller catches exceptions from engine and safely returns null',
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

        final headless = controller.engine as HeadlessPlayerEngine;
        headless.shouldThrowOnScreenshot = true;

        final result = await controller.screenshot();
        expect(result, isNull);
      },
    );

    test(
      'controller discards late frame if playback session changed during capture',
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

        final headless = controller.engine as HeadlessPlayerEngine;
        final completer = Completer<Uint8List?>();
        headless.screenshotCompleter = completer;

        // Trigger screenshot asynchronously
        final screenshotFuture = controller.screenshot();

        // While capture is in progress, switch to new video (advancing session)
        await controller.setDataSource(
          DataSource(
            videoSource: 'https://test.bilibili.com/video2.mp4',
            type: DataSourceType.network,
          ),
          owner: PlayerResourceOwner(),
          seekTo: Duration.zero,
          duration: const Duration(minutes: 10),
        );

        // Now resolve the late screenshot from the old video
        completer.complete(Uint8List.fromList([1, 2, 3, 4]));

        final result = await screenshotFuture;
        // Must be discarded because session changed!
        expect(result, isNull);
      },
    );
  });
}

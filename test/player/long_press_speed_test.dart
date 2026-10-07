import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_status.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
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
      'pilipalaz-long-press-speed-test-',
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

  group('PlPlayerController Long Press Fast-Forward TDD Unit Tests', () {
    late PlPlayerController controller;

    setUp(() async {
      Get.testMode = true;
      PlPlayerController.isHeadlessTestMode = true;
      controller = PlPlayerController.getInstance();
      await controller.setDataSource(
        DataSource(
          videoSource: 'https://test.bilibili.com/video.mp4',
          type: DataSourceType.network,
        ),
        owner: PlayerResourceOwner(),
        seekTo: Duration.zero,
        duration: const Duration(minutes: 5),
      );
      controller.playerStatus.status.value = PlayerStatus.playing;
      controller.controlsLock.value = false;
      controller.videoType.value = '';
    });

    tearDown(() async {
      await controller.dispose();
    });

    test('startLongPressSpeed activates when video is playing', () async {
      controller.playerStatus.status.value = PlayerStatus.playing;
      final activated = controller.startLongPressSpeed();

      expect(activated, isTrue);
      expect(controller.doubleSpeedStatus.value, controller.longPressSpeed);
    });

    test('startLongPressSpeed is rejected when video is paused', () async {
      controller.playerStatus.status.value = PlayerStatus.paused;
      final activated = controller.startLongPressSpeed();

      expect(activated, isFalse);
      expect(controller.doubleSpeedStatus.value, 0.0);
    });

    test('startLongPressSpeed is rejected when controls are locked', () async {
      controller.playerStatus.status.value = PlayerStatus.playing;
      controller.controlsLock.value = true;
      final activated = controller.startLongPressSpeed();

      expect(activated, isFalse);
      expect(controller.doubleSpeedStatus.value, 0.0);
    });

    test('startLongPressSpeed is rejected in live mode', () async {
      controller.playerStatus.status.value = PlayerStatus.playing;
      controller.videoType.value = 'live';
      final activated = controller.startLongPressSpeed();

      expect(activated, isFalse);
      expect(controller.doubleSpeedStatus.value, 0.0);
    });

    test(
      'stopLongPressSpeed restores baseline speed and resets status',
      () async {
        controller.playerStatus.status.value = PlayerStatus.playing;
        controller.startLongPressSpeed();
        expect(controller.doubleSpeedStatus.value, greaterThan(0.0));

        final stopped = controller.stopLongPressSpeed();
        expect(stopped, isTrue);
        expect(controller.doubleSpeedStatus.value, 0.0);
      },
    );

    test('stopLongPressSpeed with silent flag completes cleanly', () async {
      controller.playerStatus.status.value = PlayerStatus.playing;
      controller.startLongPressSpeed();

      final stopped = controller.stopLongPressSpeed(silent: true);
      expect(stopped, isTrue);
      expect(controller.doubleSpeedStatus.value, 0.0);
    });

    test('autoLongPressSpeed doubles playbackSpeed when enabled', () async {
      controller.enableAutoLongPressSpeed = true;
      await controller.setPlaybackSpeed(1.5);
      controller.playerStatus.status.value = PlayerStatus.playing;

      final activated = controller.startLongPressSpeed();
      expect(activated, isTrue);
      expect(controller.doubleSpeedStatus.value, 3.0);
    });
  });
}

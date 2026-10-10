import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_status.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
import 'package:pilipalaz/plugin/pl_player/utils/fullscreen.dart';
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
      'pilipalaz-fullscreen-orientation-test-',
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

  group('FullScreen Orientation State Machine & Timer Elimination TDD Tests', () {
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
      stopScreenTimer();
    });

    test('stopScreenTimer cancels and zeroes screenTimer', () {
      stopScreenTimer();
      expect(screenTimer, isNull);
    });

    test('verticalScreenForTwoSeconds does not leave an active screenTimer', () async {
      await verticalScreenForTwoSeconds();
      expect(screenTimer, isNull);
    });

    test('triggerFullScreen with vertical direction toggles isFullScreen cleanly', () async {
      controller.direction.value = 'vertical';
      expect(controller.isFullScreen.value, isFalse);

      await controller.triggerFullScreen(status: true);
      expect(controller.isFullScreen.value, isTrue);
      expect(screenTimer, isNull);

      await controller.triggerFullScreen(status: false);
      expect(controller.isFullScreen.value, isFalse);
      expect(screenTimer, isNull);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
import 'package:pilipalaz/services/audio_handler.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

final class _NoOpPlaybackAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  late PlPlayerController controller;

  setUpAll(() async {
    audioSessionHandler = _NoOpPlaybackAudioSession();
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-speed-isolation-test-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
    videoPlayerServiceHandler = VideoPlayerServiceHandler(
      settingBox: GStorage.setting,
    );

    PlPlayerController.isHeadlessTestMode = true;
  });

  tearDownAll(() async {
    await PlPlayerController.disposeIfExists();
    await Hive.close();
    if (hiveDirectory.existsSync()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test(
    'Playback speed remains isolated and preserved across live room transitions',
    () async {
      // 1. Initial video mode with active playback source: set speed to 1.5x
      controller = PlPlayerController.getInstance(videoType: 'archive');
      await controller.setDataSource(
        DataSource(
          videoSource: 'https://example.com/test.mp4',
          type: DataSourceType.network,
        ),
        owner: PlayerResourceOwner(),
        autoplay: false,
      );
      await controller.setPlaybackSpeed(1.5);
      expect(controller.playbackSpeed, equals(1.5));

      // 2. Switch to live mode
      controller = PlPlayerController.getInstance(videoType: 'live');
      await controller.setDataSource(
        DataSource(
          videoSource: 'https://example.com/live.m3u8',
          type: DataSourceType.network,
        ),
        owner: PlayerResourceOwner(),
        autoplay: false,
      );
      expect(controller.videoType.value, equals('live'));

      // In live mode, calling setPlaybackSpeed(1.0) must not overwrite user's video playback speed preference
      await controller.setPlaybackSpeed(1.0);

      // Explicit anti-laziness negative assertion: user's video speed must NOT be polluted to 1.0
      expect(
        controller.playbackSpeed,
        equals(1.5),
        reason:
            'Entering live room must not pollute video playbackSpeed to 1.0',
      );

      // 3. Switch back to video mode
      controller = PlPlayerController.getInstance(videoType: 'archive');
      expect(controller.videoType.value, equals('archive'));
      expect(
        controller.playbackSpeed,
        equals(1.5),
        reason: 'Returning from live room must preserve user speed of 1.5x',
      );
    },
  );
}

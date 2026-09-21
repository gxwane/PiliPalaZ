import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/engine/impl/headless_player_engine.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
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
  late PlPlayerController controller;

  setUpAll(() async {
    audioSessionHandler = _TestPlaybackAudioSession();
    tempDir = await Directory.systemTemp.createTemp(
      'pilipalaz-volume-integration-test-',
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
    PlPlayerController.isHeadlessTestMode = true;
    controller = PlPlayerController.getInstance();
  });

  tearDownAll(() async {
    await PlPlayerController.disposeIfExists();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'PlPlayerController applies volume and loudness metadata through coordinator',
    () async {
      const meta = AudioVolumeMetadata(
        targetOffset: -6.0,
        targetTp: -1.0,
        measuredTp: -1.0,
      );

      final source = DataSource(
        videoSource: 'https://example.com/test.mp4',
        type: DataSourceType.network,
        volumeMetadata: meta,
      );

      await controller.setDataSource(
        source,
        owner: PlayerResourceOwner(),
        autoplay: false,
      );

      final engine = controller.engine;
      expect(engine, isNotNull);
      expect(engine is HeadlessPlayerEngine, isTrue);

      final headless = engine as HeadlessPlayerEngine;
      // -6 dB is roughly 0.501
      expect(
        controller.volumeCoordinator.loudnessFactor,
        closeTo(0.501, 0.005),
      );
      expect(headless.volume, closeTo(0.501, 0.005));

      // Test ducking
      PlPlayerController.setAudioDuckingIfExists(true);
      expect(headless.volume, closeTo(0.501 * 0.3, 0.005));

      PlPlayerController.setAudioDuckingIfExists(false);
      expect(headless.volume, closeTo(0.501, 0.005));

      // Test user volume
      await controller.setUserVolume(0.8);
      expect(headless.volume, closeTo(0.8 * 0.501, 0.005));

      // Test sync from system key
      controller.syncVolumeFromSystem(5);
      expect(controller.volumeCoordinator.hardwareStep, 5);
      expect(controller.volume.value, closeTo(5 / 15.0, 0.001));
    },
  );
}

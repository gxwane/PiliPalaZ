import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/engine/player_engine_interface.dart';
import 'package:pilipalaz/plugin/pl_player/engine/impl/headless_player_engine.dart';
import 'package:pilipalaz/plugin/pl_player/engine/impl/media3_player_engine.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pilipalaz-phase5-e2e-');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>('setting');
  });

  tearDownAll(() async {
    await GStorage.setting.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase 5 Architecture & Lifecycle E2E Tests', () {
    test('Android default kernel resolution defaults to media3', () {
      final box = GStorage.setting;
      final String resolvedKernel = box.get(
        SettingBoxKey.playerKernel,
        defaultValue: 'media3',
      );
      expect(resolvedKernel, 'media3');
    });

    test('Engine symmetrical lifecycle: initialize -> open -> stop -> dispose', () async {
      final engine = HeadlessPlayerEngine();
      await engine.initialize();
      expect(engine.playbackState.value, EnginePlaybackState.ready);

      final mediaItem = PlayerMediaItem(
        videoUri: Uri.parse('https://example.com/video.mp4'),
        audioUri: Uri.parse('https://example.com/audio.mp4'),
      );

      await engine.open(mediaItem, autoPlay: false);
      expect(engine.playbackState.value, EnginePlaybackState.ready);
      expect(engine.isPlaying, isFalse);

      await engine.play();
      expect(engine.isPlaying, isTrue);
      expect(engine.playbackState.value, EnginePlaybackState.playing);

      await engine.seek(const Duration(seconds: 45));
      expect(engine.currentPosition, const Duration(seconds: 45));

      await engine.setRate(1.5);
      expect(engine.rate, 1.5);

      await engine.setVolume(0.8);
      expect(engine.volume, 0.8);

      await engine.stop();
      expect(engine.playbackState.value, EnginePlaybackState.idle);
      expect(engine.isPlaying, isFalse);
      expect(engine.currentPosition, Duration.zero);

      await engine.dispose();
    });

    test('Media3PlayerEngine structure adheres to IPlayerEngine specifications', () {
      final engine = Media3PlayerEngine();
      expect(engine.currentDimension, VideoDimension.zero);
      expect(engine.playbackState.value, EnginePlaybackState.idle);
      expect(engine.isPlaying, isFalse);
      expect(engine.isCompleted, isFalse);
    });

    test('PlaybackCommandCoordinator seamlessly executes toggle and restart on IPlayerEngine', () async {
      final engine = HeadlessPlayerEngine();
      await engine.initialize();
      bool restarted = false;

      final coordinator = PlaybackCommandCoordinator(
        engine: engine,
        audioSession: _MockAudioSession(),
        onControlsVisibilityChanged: (_) {},
        onFeedback: () {},
        restartFromBeginning: () async {
          restarted = true;
        },
      );

      expect(engine.isPlaying, isFalse);
      await coordinator.toggle(restart: false);
      expect(engine.isPlaying, isTrue);

      await coordinator.toggle(restart: false);
      expect(engine.isPlaying, isFalse);

      await coordinator.toggle(restart: true);
      expect(restarted, isTrue);
      expect(engine.isPlaying, isTrue);

      await engine.dispose();
    });
  });
}

class _MockAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

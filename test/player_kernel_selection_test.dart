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
    tempDir = await Directory.systemTemp.createTemp('pilipalaz-kernel-test-');
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

  group('Player Kernel Setting & Persistence', () {
    test('defaults to media3 and persists kernel selection', () async {
      final box = GStorage.setting;
      expect(box.get(SettingBoxKey.playerKernel, defaultValue: 'media3'), 'media3');

      await box.put(SettingBoxKey.playerKernel, 'mpv');
      expect(box.get(SettingBoxKey.playerKernel), 'mpv');

      await box.put(SettingBoxKey.playerKernel, 'media3');
      expect(box.get(SettingBoxKey.playerKernel), 'media3');
    });
  });

  group('PlaybackEngine & IPlayerEngine Contract Alignment', () {
    test('HeadlessPlayerEngine satisfies PlaybackEngine contract', () async {
      final PlaybackEngine engine = HeadlessPlayerEngine();
      if (engine is IPlayerEngine) {
        await engine.initialize();
      }
      expect(engine.isPlaying, isFalse);
      expect(engine.isCompleted, isFalse);

      await engine.play();
      expect(engine.isPlaying, isTrue);

      await engine.pause();
      expect(engine.isPlaying, isFalse);
      if (engine is IPlayerEngine) {
        await engine.dispose();
      }
    });

    test('Media3PlayerEngine satisfies PlaybackEngine contract', () {
      final Object engine = Media3PlayerEngine();
      expect(engine is PlaybackEngine, isTrue);
      expect(engine is IPlayerEngine, isTrue);
    });

    test('PlaybackCommandCoordinator works uniformly with IPlayerEngine', () async {
      final engine = HeadlessPlayerEngine();
      await engine.initialize();
      bool controlsVisible = false;

      final coordinator = PlaybackCommandCoordinator(
        engine: engine,
        audioSession: _MockAudioSession(),
        onControlsVisibilityChanged: (v) => controlsVisible = v,
        onFeedback: () {},
        restartFromBeginning: () async {},
      );

      expect(coordinator.engine.isPlaying, isFalse);
      await coordinator.play(hideControls: false);
      expect(coordinator.engine.isPlaying, isTrue);
      expect(engine.isPlaying, isTrue);
      expect(controlsVisible, isTrue);

      await coordinator.pause();
      expect(coordinator.engine.isPlaying, isFalse);
      expect(engine.isPlaying, isFalse);
      await engine.dispose();
    });
  });

  group('Engine Stream Synchronization Contract', () {
    test('HeadlessPlayerEngine streams propagate correctly', () async {
      final engine = HeadlessPlayerEngine();
      await engine.initialize();

      final positions = <Duration>[];
      final durations = <Duration>[];
      final states = <EnginePlaybackState>[];

      final sub1 = engine.positionStream.listen(positions.add);
      final sub2 = engine.durationStream.listen(durations.add);
      engine.playbackState.addListener(() {
        states.add(engine.playbackState.value);
      });

      engine.emitPosition(const Duration(seconds: 15));
      engine.emitDuration(const Duration(seconds: 120));
      await engine.play();
      await engine.pause();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(positions, contains(const Duration(seconds: 15)));
      expect(durations, contains(const Duration(seconds: 120)));
      expect(states, contains(EnginePlaybackState.playing));
      expect(states, contains(EnginePlaybackState.paused));

      await sub1.cancel();
      await sub2.cancel();
      await engine.dispose();
    });
  });
}

class _MockAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

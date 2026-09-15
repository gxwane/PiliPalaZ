import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/playback_lifecycle.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-playback-test-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('PlaybackLifecycle Guards', () {
    test(
      'PlPlayerController guards playback commands when not ready',
      () async {
        final controller = PlPlayerController.getInstance();

        // Initially lifecycle is idle, canControlPlayback must be false
        expect(controller.canControlPlayback, isFalse);
        expect(controller.isPlaying, isFalse);

        // Calling seekTo, setPlaybackSpeed, and screenshot must be safe no-ops
        await expectLater(
          controller.seekTo(const Duration(seconds: 10)),
          completes,
        );
        await expectLater(controller.setPlaybackSpeed(1.5), completes);
        final screenshot = await controller.screenshot();
        expect(screenshot, isNull);
      },
    );

    test('PlPlayerController disposes timers and drains native callbacks', () {
      final code = File(
        'lib/plugin/pl_player/controller.dart',
      ).readAsStringSync();

      expect(code, contains('void _cancelAllTimers()'));
      expect(code, contains('_timerForLongPressSpeed'));
      expect(code, contains('_timerForShowingVolume?.cancel()'));
      expect(code, contains('_cancelAllTimers();'));
      expect(
        code,
        contains('platform.release'),
        reason:
            'Pre-release callbacks must be drained before native player disposal',
      );
      expect(
        code,
        contains('canControlPlayback && _videoPlayerController!.state.playing'),
        reason: 'Do not access state on an unready or disposing player',
      );
    });

    test('BAC-19: PlPlayerController enforces readiness before _initializePlayer and dispatches rate safely', () {
      final rawCode = File(
        'lib/plugin/pl_player/controller.dart',
      ).readAsStringSync();
      final code = rawCode.replaceAll('\r\n', '\n');

      // markReady must happen before _initializePlayer
      final markReadyIndex = code.indexOf('_playbackLifecycle.markReady(session)');
      final initPlayerIndex = code.indexOf('await _initializePlayer();');
      expect(markReadyIndex, isNonNegative);
      expect(initPlayerIndex, isNonNegative);
      expect(
        markReadyIndex < initPlayerIndex,
        isTrue,
        reason: 'markReady must be called before _initializePlayer so canControlPlayback is true',
      );

      // Session abort guards
      expect(
        code,
        contains('if (!_playbackLifecycle.markReady(session))'),
        reason: 'If session is superseded, abort before _initializePlayer',
      );
      expect(
        code,
        contains('await _initializePlayer();\n      if (session != _playbackSession) return;'),
        reason: 'Session must be verified after async _initializePlayer',
      );

      // setDefaultSpeed must route through setPlaybackSpeed
      expect(
        code,
        contains('await setPlaybackSpeed(speed);'),
        reason: 'setDefaultSpeed must delegate to setPlaybackSpeed',
      );
    });

    test('Session increment supersedes prior async callbacks and timers', () {
      final lifecycle = PlaybackLifecycle();

      final session1 = lifecycle.beginLoading();
      expect(lifecycle.isCurrent(session1), isTrue);
      expect(lifecycle.canControlPlayback, isFalse);

      final session2 = lifecycle.beginLoading();
      expect(lifecycle.isCurrent(session1), isFalse);
      expect(lifecycle.isCurrent(session2), isTrue);

      expect(lifecycle.markReady(session1), isFalse);
      expect(lifecycle.canControlPlayback, isFalse);

      expect(lifecycle.markReady(session2), isTrue);
      expect(lifecycle.canControlPlayback, isTrue);

      lifecycle.beginRelease();
      expect(lifecycle.isCurrent(session2), isFalse);
      expect(lifecycle.canControlPlayback, isFalse);
    });

    test('PlayerResourceOwnership releases only for the current owner', () {
      final ownership = PlaybackResourceOwnership();
      final owner1 = PlayerResourceOwner();
      final owner2 = PlayerResourceOwner();

      ownership.claim(owner1);
      expect(ownership.owns(owner1), isTrue);
      expect(ownership.owns(owner2), isFalse);

      expect(ownership.release(owner2), isFalse);
      expect(ownership.owns(owner1), isTrue);

      expect(ownership.release(owner1), isTrue);
      expect(ownership.owns(owner1), isFalse);
    });
  });
}

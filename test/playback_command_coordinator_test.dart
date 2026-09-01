import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';

void main() {
  group('PlaybackCommandCoordinator', () {
    late _FakePlaybackEngine engine;
    late _FakePlaybackAudioSession audioSession;
    late List<bool> controlsVisibility;
    late List<String> logs;
    late List<String> events;
    late int feedbackCount;
    Object? restartError;
    late PlaybackCommandCoordinator coordinator;

    setUp(() {
      events = <String>[];
      engine = _FakePlaybackEngine(events);
      audioSession = _FakePlaybackAudioSession(events);
      controlsVisibility = <bool>[];
      logs = <String>[];
      feedbackCount = 0;
      restartError = null;
      coordinator = PlaybackCommandCoordinator(
        engine: engine,
        audioSession: audioSession,
        onControlsVisibilityChanged: controlsVisibility.add,
        onFeedback: () {
          feedbackCount++;
          events.add('feedback');
        },
        restartFromBeginning: () async {
          events.add('restart');
          final error = restartError;
          if (error != null) throw error;
        },
        onLog: logs.add,
      );
    });

    test('play waits for the engine without publishing app state', () async {
      final completer = Completer<void>();
      engine.playCompleter = completer;

      var completed = false;
      final future = coordinator.play()..whenComplete(() => completed = true);
      await _flushMicrotasks();

      expect(controlsVisibility, <bool>[false]);
      expect(audioSession.requests, <bool>[true]);
      expect(engine.playCalls, 1);
      expect(completed, isFalse);

      completer.complete();
      await future;

      expect(completed, isTrue);
    });

    test('play can keep controls visible when requested', () async {
      await coordinator.play(hideControls: false);

      expect(controlsVisibility, <bool>[true]);
    });

    test('completed toggle restarts before audio focus and play', () async {
      engine.completed = true;

      await coordinator.toggle();

      expect(events, <String>['feedback', 'restart', 'focus:true', 'play']);
      expect(engine.playCalls, 1);
    });

    test('direct play restarts a completed engine', () async {
      engine.completed = true;

      await coordinator.play();

      expect(events, <String>['restart', 'focus:true', 'play']);
    });

    test(
      'explicit completed state restarts even before engine catches up',
      () async {
        await coordinator.toggle(restart: true);

        expect(events, <String>['feedback', 'restart', 'focus:true', 'play']);
      },
    );

    test('normal paused playback does not restart', () async {
      await coordinator.toggle();

      expect(events, <String>['feedback', 'focus:true', 'play']);
    });

    test('audio focus rejection does not block playback', () async {
      audioSession.result = false;

      await coordinator.play();

      expect(engine.playCalls, 1);
      expect(logs, hasLength(1));
    });

    test('audio focus errors do not block playback', () async {
      audioSession.error = StateError('focus unavailable');

      await coordinator.play();

      expect(engine.playCalls, 1);
      expect(logs.single, contains('focus unavailable'));
    });

    test('engine play errors restore controls and preserve status', () async {
      final error = StateError('play failed');
      engine.playError = error;

      await expectLater(coordinator.play(), throwsA(same(error)));

      expect(controlsVisibility, <bool>[false, true]);
      expect(audioSession.requests, <bool>[true, false]);
    });

    test('restart errors restore controls without focus or play', () async {
      final error = StateError('restart failed');
      restartError = error;

      await expectLater(coordinator.play(restart: true), throwsA(same(error)));

      expect(controlsVisibility, <bool>[false, true]);
      expect(audioSession.requests, isEmpty);
      expect(engine.playCalls, 0);
    });

    test('pause waits for the engine and releases audio focus', () async {
      engine.playing = true;

      await coordinator.pause();

      expect(engine.pauseCalls, 1);
      expect(audioSession.requests, <bool>[false]);
    });

    test('interruption pause keeps audio focus owned by the session', () async {
      engine.playing = true;

      await coordinator.pause(isInterrupt: true);

      expect(engine.pauseCalls, 1);
      expect(audioSession.requests, isEmpty);
    });

    test('toggle plays a stopped engine with one feedback event', () async {
      await coordinator.toggle();

      expect(feedbackCount, 1);
      expect(engine.playCalls, 1);
      expect(engine.pauseCalls, 0);
    });

    test('toggle pauses a playing engine with one feedback event', () async {
      engine.playing = true;

      await coordinator.toggle();

      expect(feedbackCount, 1);
      expect(engine.playCalls, 0);
      expect(engine.pauseCalls, 1);
    });
  });

  test('player UI routes play toggles through PlPlayerController', () {
    final button = File(
      'lib/plugin/pl_player/widgets/play_pause_btn.dart',
    ).readAsStringSync();
    final view = File('lib/plugin/pl_player/view.dart').readAsStringSync();
    final controller = File(
      'lib/plugin/pl_player/controller.dart',
    ).readAsStringSync();
    final audioHandler = File(
      'lib/services/audio_handler.dart',
    ).readAsStringSync();
    final commands = File(
      'lib/plugin/pl_player/playback_commands.dart',
    ).readAsStringSync();

    expect(button, contains('onTap: canControl ? controller!.togglePlay'));
    expect(button, isNot(contains('onTap: player.playOrPause')));
    expect(button, isNot(contains('videoPlayerController!')));
    expect(button, isNot(contains('late Player player')));
    expect(view, contains('unawaited(playerController.togglePlay());'));
    expect(
      view,
      isNot(contains('playerController.videoPlayerController!.playOrPause()')),
    );
    expect(controller, contains('() => togglePlay()'));
    expect(audioHandler, contains('await PlPlayerController.playIfExists();'));
    expect(commands, isNot(contains('onStatusChanged')));
    expect(controller, contains('restart: repeat || playerStatus.completed'));
    expect(
      RegExp(
        r'''seekTo\(Duration\.zero, type: ['"]slider['"]\)''',
      ).allMatches(controller),
      hasLength(1),
      reason: 'completed replay must reset the timeline exactly once',
    );
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakePlaybackEngine implements PlaybackEngine {
  _FakePlaybackEngine(this.events);

  final List<String> events;
  bool playing = false;
  bool completed = false;

  int playCalls = 0;
  int pauseCalls = 0;
  Completer<void>? playCompleter;
  Object? playError;

  @override
  bool get isPlaying => playing;

  @override
  bool get isCompleted => completed;

  @override
  Future<void> play() async {
    playCalls++;
    events.add('play');
    final completer = playCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = playError;
    if (error != null) {
      throw error;
    }
    playing = true;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playing = false;
  }
}

class _FakePlaybackAudioSession implements PlaybackAudioSession {
  _FakePlaybackAudioSession(this.events);

  final List<String> events;
  final List<bool> requests = <bool>[];
  bool result = true;
  Object? error;

  @override
  Future<bool> setActive(bool active) async {
    requests.add(active);
    events.add('focus:$active');
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return result;
  }
}

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

abstract interface class PlaybackEngine {
  bool get isPlaying;

  bool get isCompleted;

  Future<void> play();

  Future<void> pause();
}

abstract interface class PlaybackAudioSession {
  Future<bool> setActive(bool active);
}

class MediaKitPlaybackEngine implements PlaybackEngine {
  MediaKitPlaybackEngine(this.player);

  final Player player;

  @override
  bool get isPlaying => player.state.playing;

  @override
  bool get isCompleted => player.state.completed;

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();
}

class PlaybackCommandCoordinator {
  PlaybackCommandCoordinator({
    required this.engine,
    required this.audioSession,
    required this.onControlsVisibilityChanged,
    required this.onFeedback,
    required this.restartFromBeginning,
    ValueChanged<String>? onLog,
  }) : onLog = onLog ?? debugPrint;

  final PlaybackEngine engine;
  final PlaybackAudioSession audioSession;
  final ValueChanged<bool> onControlsVisibilityChanged;
  final VoidCallback onFeedback;
  final Future<void> Function() restartFromBeginning;
  final ValueChanged<String> onLog;

  Future<void> play({bool hideControls = true, bool restart = false}) async {
    onControlsVisibilityChanged(!hideControls);
    var audioSessionActive = false;

    try {
      if (restart || engine.isCompleted) {
        await restartFromBeginning();
      }
      audioSessionActive = await _setAudioSessionActive(true);
      await engine.play();
    } catch (_) {
      if (audioSessionActive) {
        await _setAudioSessionActive(false);
      }
      if (hideControls) {
        onControlsVisibilityChanged(true);
      }
      rethrow;
    }
  }

  Future<void> pause({bool isInterrupt = false}) async {
    await engine.pause();

    if (!isInterrupt) {
      await _setAudioSessionActive(false);
    }
  }

  Future<void> toggle({bool restart = false}) async {
    onFeedback();
    if (engine.isPlaying) {
      await pause();
    } else {
      await play(restart: restart);
    }
  }

  Future<bool> _setAudioSessionActive(bool active) async {
    try {
      final accepted = await audioSession.setActive(active);
      if (!accepted) {
        onLog('Audio session rejected setActive($active).');
      }
      return accepted;
    } catch (error, stackTrace) {
      onLog('Audio session setActive($active) failed: $error\n$stackTrace');
      return false;
    }
  }
}

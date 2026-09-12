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
  bool get isPlaying {
    try {
      return player.state.playing;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isCompleted {
    try {
      return player.state.completed;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> play() async {
    try {
      await player.play();
    } catch (e) {
      debugPrint('MediaKitPlaybackEngine.play failed: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await player.pause();
    } catch (e) {
      debugPrint('MediaKitPlaybackEngine.pause failed: $e');
    }
  }
}

class HeadlessTestPlaybackEngine implements PlaybackEngine {
  HeadlessTestPlaybackEngine([this.onPlayingChanged]);

  final void Function(bool isPlaying)? onPlayingChanged;
  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  bool get isCompleted => false;

  @override
  Future<void> play() async {
    _playing = true;
    onPlayingChanged?.call(true);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    onPlayingChanged?.call(false);
  }
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

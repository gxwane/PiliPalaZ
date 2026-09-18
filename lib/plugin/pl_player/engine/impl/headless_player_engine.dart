import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pilipalaz/plugin/pl_player/engine/player_engine_interface.dart';

/// 用于无原生环境与自动化单元测试的轻量级无头播放引擎
class HeadlessPlayerEngine implements IPlayerEngine {
  final ValueNotifier<EnginePlaybackState> _state =
      ValueNotifier<EnginePlaybackState>(EnginePlaybackState.idle);

  final VideoDimension _dimension = const VideoDimension(1920, 1080);
  Duration _position = Duration.zero;
  Duration _duration = const Duration(minutes: 10);
  Duration _bufferedPosition = const Duration(minutes: 5);
  double _rate = 1.0;
  double _volume = 1.0;
  bool _looping = false;
  bool _isDisposed = false;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _bufferedPositionController =
      StreamController<Duration>.broadcast();
  final StreamController<VideoDimension> _dimensionController =
      StreamController<VideoDimension>.broadcast();
  final StreamController<EngineError> _errorController =
      StreamController<EngineError>.broadcast();

  final void Function(bool isPlaying)? onPlayingChanged;

  HeadlessPlayerEngine({this.onPlayingChanged});

  @override
  Future<void> initialize() async {
    _state.value = EnginePlaybackState.ready;
  }

  @override
  Future<void> open(PlayerMediaItem item, {bool autoPlay = true}) async {
    if (_isDisposed) return;
    _state.value = EnginePlaybackState.loading;
    _position = item.startPosition ?? Duration.zero;
    _duration = const Duration(minutes: 10);
    _bufferedPosition = _duration;
    _state.value = EnginePlaybackState.ready;

    if (!_isDisposed) {
      _positionController.add(_position);
      _durationController.add(_duration);
      _bufferedPositionController.add(_bufferedPosition);
      _dimensionController.add(_dimension);
    }

    if (autoPlay) {
      await play();
    }
  }

  @override
  ValueListenable<EnginePlaybackState> get playbackState => _state;

  @override
  VideoDimension get currentDimension => _dimension;

  @override
  Duration get currentPosition => _position;

  @override
  Duration get currentDuration => _duration;

  @override
  Duration get currentBufferedPosition => _bufferedPosition;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  @override
  Stream<VideoDimension> get dimensionStream => _dimensionController.stream;

  @override
  Stream<EngineError> get errorStream => _errorController.stream;

  @override
  bool get isPlaying => _state.value == EnginePlaybackState.playing;

  @override
  bool get isCompleted => _state.value == EnginePlaybackState.completed;

  @override
  Future<void> play() async {
    if (_isDisposed) return;
    _state.value = EnginePlaybackState.playing;
    onPlayingChanged?.call(true);
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    _state.value = EnginePlaybackState.paused;
    onPlayingChanged?.call(false);
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) return;
    _state.value = EnginePlaybackState.idle;
    _position = Duration.zero;
    if (!_isDisposed) {
      _positionController.add(_position);
    }
    onPlayingChanged?.call(false);
  }

  @override
  Future<void> seek(Duration position, {bool exact = false}) async {
    if (_isDisposed) return;
    _position = position;
    if (!_isDisposed) {
      _positionController.add(_position);
    }
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
  }

  double get rate => _rate;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  double get volume => _volume;

  @override
  Future<void> setLooping(bool looping) async {
    _looping = looping;
  }

  bool get looping => _looping;

  @override
  Future<void> setAudioTrack(AudioTrackOption track) async {}

  @override
  Future<void> setSubtitleTrack(SubtitleTrackOption track) async {}

  @override
  Future<Uint8List?> screenshot({String? format}) async => null;

  @override
  Future<Map<String, Object?>> getDiagnosticsInfo() async => {
    'engine': 'HeadlessPlayerEngine',
    'width': _dimension.width,
    'height': _dimension.height,
    'position': _position.inMilliseconds,
    'duration': _duration.inMilliseconds,
  };

  @override
  Widget buildVideoView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    TextStyle? subtitleStyle,
    double? subtitleBottomPadding,
    bool pauseUponEnteringBackgroundMode = false,
    bool resumeUponEnteringForegroundMode = true,
  }) {
    return const SizedBox.expand(
      key: Key('headless_video_placeholder'),
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Headless Video Placeholder',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _state.value = EnginePlaybackState.idle;
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _dimensionController.close();
    await _errorController.close();
    _state.dispose();
  }
}

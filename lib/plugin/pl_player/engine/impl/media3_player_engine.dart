import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pilipalaz/plugin/pl_player/engine/player_engine_interface.dart';

/// Android 原生 Media3 (ExoPlayer) 播放器引擎实现
class Media3PlayerEngine implements IPlayerEngine {
  static const MethodChannel _channel = MethodChannel(
    'io.github.gxwane.pilipalaz/media3',
  );
  static const EventChannel _eventChannel = EventChannel(
    'io.github.gxwane.pilipalaz/media3_events',
  );

  int? _textureId;
  final ValueNotifier<EnginePlaybackState> _playbackState =
      ValueNotifier<EnginePlaybackState>(EnginePlaybackState.idle);

  VideoDimension _dimension = VideoDimension.zero;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  bool _isPlaying = false;
  bool _isCompleted = false;
  bool _isDisposed = false;

  StreamSubscription<dynamic>? _eventSub;

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

  int? get textureId => _textureId;

  @override
  Future<void> initialize() async {
    if (_isDisposed) return;
    try {
      final int? id = await _channel.invokeMethod<int>('create');
      _textureId = id;
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        _onNativeEvent,
        onError: (err) {
          _errorController.add(
            EngineError(
              code: EngineErrorCode.unknown,
              message: err.toString(),
              cause: err,
            ),
          );
        },
      );
      _playbackState.value = EnginePlaybackState.ready;
    } catch (e) {
      debugPrint('Media3PlayerEngine.initialize error: $e');
      _playbackState.value = EnginePlaybackState.error;
    }
  }

  void _onNativeEvent(dynamic event) {
    if (_isDisposed || event is! Map) return;
    final String type = event['event'] as String? ?? '';

    switch (type) {
      case 'playbackUpdate':
        final int posMs = (event['position'] as num?)?.toInt() ?? 0;
        final int bufMs = (event['buffered'] as num?)?.toInt() ?? 0;
        final int durMs = (event['duration'] as num?)?.toInt() ?? 0;
        final bool playing = event['isPlaying'] as bool? ?? false;

        _position = Duration(milliseconds: posMs);
        _bufferedPosition = Duration(milliseconds: bufMs);
        _duration = Duration(milliseconds: durMs);
        _isPlaying = playing;

        _positionController.add(_position);
        _bufferedPositionController.add(_bufferedPosition);
        _durationController.add(_duration);
        break;

      case 'stateChanged':
        final String state = event['state'] as String? ?? '';
        switch (state) {
          case 'idle':
            _playbackState.value = EnginePlaybackState.idle;
            _isPlaying = false;
            break;
          case 'buffering':
            _playbackState.value = EnginePlaybackState.buffering;
            break;
          case 'ready':
            _playbackState.value = EnginePlaybackState.ready;
            break;
          case 'playing':
            _playbackState.value = EnginePlaybackState.playing;
            _isPlaying = true;
            _isCompleted = false;
            break;
          case 'paused':
            _playbackState.value = EnginePlaybackState.paused;
            _isPlaying = false;
            break;
          case 'completed':
            _playbackState.value = EnginePlaybackState.completed;
            _isCompleted = true;
            _isPlaying = false;
            break;
        }
        break;

      case 'videoSizeChanged':
        final int width = (event['width'] as num?)?.toInt() ?? 0;
        final int height = (event['height'] as num?)?.toInt() ?? 0;
        if (_dimension.width != width || _dimension.height != height) {
          _dimension = VideoDimension(width, height);
          _dimensionController.add(_dimension);
        }
        break;

      case 'error':
        final String errorCode = event['errorCode'] as String? ?? 'unknown';
        final String errorMsg = event['errorMessage'] as String? ?? '';
        final EngineErrorCode code = errorCode == 'tokenExpiredOrForbidden'
            ? EngineErrorCode.tokenExpiredOrForbidden
            : EngineErrorCode.unknown;

        _playbackState.value = EnginePlaybackState.error;
        _errorController.add(
          EngineError(code: code, message: errorMsg, cause: event),
        );
        break;
    }
  }

  @override
  Future<void> open(PlayerMediaItem item, {bool autoPlay = true}) async {
    if (_isDisposed) return;
    if (_textureId == null) {
      await initialize();
    }
    _playbackState.value = EnginePlaybackState.loading;
    _position = item.startPosition ?? Duration.zero;

    try {
      await _channel.invokeMethod<void>('open', {
        'videoUrl': item.videoUri.toString(),
        'audioUrl': item.audioUri?.toString(),
        'headers': item.httpHeaders,
        'startPositionMs': item.startPosition?.inMilliseconds,
        'autoPlay': autoPlay,
      });
      _playbackState.value = autoPlay
          ? EnginePlaybackState.playing
          : EnginePlaybackState.ready;
      _isPlaying = autoPlay;
    } catch (e) {
      debugPrint('Media3PlayerEngine.open error: $e');
      _playbackState.value = EnginePlaybackState.error;
    }
  }

  @override
  ValueListenable<EnginePlaybackState> get playbackState => _playbackState;

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
  bool get isPlaying => _isPlaying;

  @override
  bool get isCompleted => _isCompleted;

  @override
  Future<void> play() async {
    if (_isDisposed) return;
    _playbackState.value = EnginePlaybackState.playing;
    _isPlaying = true;
    _isCompleted = false;
    await _channel.invokeMethod<void>('play');
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    _playbackState.value = EnginePlaybackState.paused;
    _isPlaying = false;
    await _channel.invokeMethod<void>('pause');
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) return;
    await _channel.invokeMethod<void>('stop');
    _isPlaying = false;
    _playbackState.value = EnginePlaybackState.idle;
  }

  @override
  Future<void> seek(Duration position, {bool exact = false}) async {
    if (_isDisposed) return;
    await _channel.invokeMethod<void>('seekTo', {
      'positionMs': position.inMilliseconds,
    });
    _position = position;
    _positionController.add(_position);
  }

  @override
  Future<void> setRate(double rate) async {
    if (_isDisposed) return;
    await _channel.invokeMethod<void>('setPlaybackSpeed', {'speed': rate});
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    await _channel.invokeMethod<void>('setVolume', {'volume': volume});
  }

  @override
  Future<void> setLooping(bool looping) async {
    if (_isDisposed) return;
    await _channel.invokeMethod<void>('setLooping', {'looping': looping});
  }

  @override
  Future<void> setAudioTrack(AudioTrackOption track) async {}

  @override
  Future<void> setSubtitleTrack(SubtitleTrackOption track) async {}

  @override
  Future<Uint8List?> screenshot({String? format}) async => null;

  @override
  Future<Map<String, Object?>> getDiagnosticsInfo() async {
    return {
      'engine': 'Media3PlayerEngine',
      'textureId': _textureId,
      'width': _dimension.width,
      'height': _dimension.height,
      'position': _position.inMilliseconds,
      'duration': _duration.inMilliseconds,
      'buffered': _bufferedPosition.inMilliseconds,
      'playing': _isPlaying,
    };
  }

  @override
  Widget buildVideoView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    TextStyle? subtitleStyle,
    double? subtitleBottomPadding,
    bool pauseUponEnteringBackgroundMode = false,
    bool resumeUponEnteringForegroundMode = true,
  }) {
    final int? texId = _textureId;
    if (texId == null) {
      return SizedBox.expand(
        key: key,
        child: const ColoredBox(color: Colors.black),
      );
    }

    return StreamBuilder<VideoDimension>(
      key: key,
      stream: dimensionStream,
      initialData: _dimension,
      builder: (BuildContext context, AsyncSnapshot<VideoDimension> snapshot) {
        final VideoDimension dimension = snapshot.data ?? _dimension;
        Widget videoWidget = Texture(textureId: texId);
        if (dimension.hasSize) {
          videoWidget = ClipRect(
            child: FittedBox(
              fit: fit,
              child: SizedBox(
                width: dimension.width.toDouble(),
                height: dimension.height.toDouble(),
                child: videoWidget,
              ),
            ),
          );
        }

        return Container(
          color: Colors.black,
          child: Center(child: videoWidget),
        );
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await _eventSub?.cancel();
    _eventSub = null;

    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}

    _textureId = null;
    _playbackState.value = EnginePlaybackState.idle;

    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _dimensionController.close();
    await _errorController.close();
    _playbackState.dispose();
  }
}

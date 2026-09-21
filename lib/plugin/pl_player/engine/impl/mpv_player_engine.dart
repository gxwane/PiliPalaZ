import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pilipalaz/plugin/pl_player/engine/player_engine_interface.dart';
import 'package:pilipalaz/plugin/pl_player/external_audio_command.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/player_buffer_policy.dart';
import 'package:universal_platform/universal_platform.dart';

/// 基于 media_kit (libmpv) 的播放器引擎实现
class MpvPlayerEngine implements IPlayerEngine {
  Player? _player;
  VideoController? _videoController;

  final ValueNotifier<EnginePlaybackState> _playbackState =
      ValueNotifier<EnginePlaybackState>(EnginePlaybackState.idle);

  VideoDimension _dimension = VideoDimension.zero;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;

  bool _isDisposed = false;
  final List<StreamSubscription> _subscriptions = [];

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

  // 配置项
  final PlayerBufferPolicy? bufferPolicy;
  final bool enableHardwareAcceleration;
  final String? hwdec;
  final String videoSync;
  final bool useOpenSLES;

  MpvPlayerEngine({
    Player? existingPlayer,
    VideoController? existingVideoController,
    this.bufferPolicy,
    this.enableHardwareAcceleration = true,
    this.hwdec,
    this.videoSync = 'audio',
    this.useOpenSLES = false,
  }) : _player = existingPlayer,
       _videoController = existingVideoController;

  Player? get player => _player;
  VideoController? get videoController => _videoController;

  @override
  Future<void> initialize() async {
    if (_isDisposed) return;
    if (_player == null) {
      final int bufferSize = bufferPolicy?.bufferSize ?? (32 * 1024 * 1024);
      _player = Player(
        configuration: PlayerConfiguration(
          bufferSize: bufferSize,
          logLevel: MPVLogLevel.v,
        ),
      );
    }
    _attachPlayerListeners(_player!);
    await _applyNativeProperties(_player!);
    await _ensureVideoController();
    _playbackState.value = EnginePlaybackState.ready;
  }

  void _attachPlayerListeners(Player player) {
    _subscriptions.add(
      player.stream.playing.listen((playing) {
        if (_isDisposed) return;
        if (playing) {
          _playbackState.value = EnginePlaybackState.playing;
        } else if (_playbackState.value != EnginePlaybackState.completed &&
            _playbackState.value != EnginePlaybackState.idle) {
          _playbackState.value = EnginePlaybackState.paused;
        }
      }),
    );

    _subscriptions.add(
      player.stream.buffering.listen((buffering) {
        if (_isDisposed) return;
        if (buffering) {
          _playbackState.value = EnginePlaybackState.buffering;
        } else if (_player?.state.playing == true) {
          _playbackState.value = EnginePlaybackState.playing;
        }
      }),
    );

    _subscriptions.add(
      player.stream.completed.listen((completed) {
        if (_isDisposed) return;
        if (completed) {
          _playbackState.value = EnginePlaybackState.completed;
        }
      }),
    );

    _subscriptions.add(
      player.stream.position.listen((pos) {
        if (_isDisposed) return;
        _position = pos;
        _positionController.add(pos);
      }),
    );

    _subscriptions.add(
      player.stream.duration.listen((dur) {
        if (_isDisposed) return;
        _duration = dur;
        _durationController.add(dur);
      }),
    );

    _subscriptions.add(
      player.stream.buffer.listen((buf) {
        if (_isDisposed) return;
        _bufferedPosition = buf;
        _bufferedPositionController.add(buf);
      }),
    );

    _subscriptions.add(
      player.stream.width.listen((w) {
        if (_isDisposed) return;
        final h = _player?.state.height ?? _dimension.height;
        _updateDimension(w ?? 0, h);
      }),
    );

    _subscriptions.add(
      player.stream.height.listen((h) {
        if (_isDisposed) return;
        final w = _player?.state.width ?? _dimension.width;
        _updateDimension(w, h ?? 0);
      }),
    );

    _subscriptions.add(
      player.stream.error.listen((err) {
        if (_isDisposed) return;
        final String msg = err.toString();
        final EngineErrorCode code = msg.contains('403')
            ? EngineErrorCode.tokenExpiredOrForbidden
            : EngineErrorCode.unknown;
        _errorController.add(EngineError(code: code, message: msg, cause: err));
      }),
    );
  }

  void _updateDimension(int w, int h) {
    if (_dimension.width != w || _dimension.height != h) {
      _dimension = VideoDimension(w, h);
      _dimensionController.add(_dimension);
    }
  }

  Future<void> _applyNativeProperties(Player player) async {
    final NativePlayer pp = player.platform as NativePlayer;
    if (bufferPolicy != null) {
      await _applyDemuxerBufferProperties(pp, bufferPolicy!);
    }
    await pp.setProperty('af', 'scaletempo2=max-speed=8');
    if (Platform.isAndroid) {
      await pp.setProperty('volume-max', '100');
      final String ao = useOpenSLES
          ? 'opensles,audiotrack'
          : 'audiotrack,opensles';
      await pp.setProperty('ao', ao);
    }
    await pp.setProperty('video-sync', videoSync);
    await pp.setProperty('force-seekable', 'yes');
    await player.setAudioTrack(AudioTrack.auto());
  }

  Future<void> _applyDemuxerBufferProperties(
    NativePlayer pp,
    PlayerBufferPolicy policy,
  ) {
    return Future.wait([
      pp.setProperty('demuxer-max-bytes', policy.demuxerMaxBytes.toString()),
      pp.setProperty(
        'demuxer-max-back-bytes',
        policy.demuxerMaxBackBytes.toString(),
      ),
      pp.setProperty(
        'demuxer-readahead-secs',
        policy.demuxerReadaheadSecs.toString(),
      ),
      pp.setProperty(
        'demuxer-hysteresis-secs',
        policy.demuxerHysteresisSecs.toString(),
      ),
      pp.setProperty('cache-pause-wait', policy.cachePauseWait.toString()),
      pp.setProperty('network-timeout', policy.networkTimeout.toString()),
      pp.setProperty('stream-lavf-o', defaultStreamLavfOptions),
    ]);
  }

  Future<void> _ensureVideoController() async {
    if (_videoController == null && _player != null) {
      final String? effectiveHwdec = enableHardwareAcceleration
          ? (Platform.isAndroid && (hwdec == null || hwdec == 'auto')
                ? 'auto-safe'
                : hwdec)
          : null;
      _videoController = VideoController(
        _player!,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: enableHardwareAcceleration,
          androidAttachSurfaceAfterVideoParameters: false,
          hwdec: effectiveHwdec,
        ),
      );
    }
  }

  @override
  Future<void> open(PlayerMediaItem item, {bool autoPlay = true}) async {
    if (_isDisposed) return;
    if (_player == null) {
      await initialize();
    }
    final Player player = _player!;
    final NativePlayer pp = player.platform as NativePlayer;

    _playbackState.value = EnginePlaybackState.loading;

    // 挂载外置音频轨
    final String? audioUrl = item.audioUri?.toString();
    await pp.command(
      buildExternalAudioCommand(
        audioUrl,
        isWindows: UniversalPlatform.isWindows,
      ),
    );

    // 打开媒体源
    final String mediaUrl = item.type == DataSourceType.asset
        ? (item.videoUri.toString().startsWith('asset://')
              ? item.videoUri.toString()
              : 'asset://${item.videoUri}')
        : item.videoUri.toString();

    await player.open(
      Media(mediaUrl, httpHeaders: item.httpHeaders, start: item.startPosition),
      play: autoPlay,
    );

    _playbackState.value = autoPlay
        ? EnginePlaybackState.playing
        : EnginePlaybackState.ready;
  }

  @override
  ValueListenable<EnginePlaybackState> get playbackState => _playbackState;

  @override
  VideoDimension get currentDimension => _dimension;

  @override
  Duration get currentPosition => _player?.state.position ?? _position;

  @override
  Duration get currentDuration => _player?.state.duration ?? _duration;

  @override
  Duration get currentBufferedPosition =>
      _player?.state.buffer ?? _bufferedPosition;

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
  bool get isPlaying => _player?.state.playing ?? false;

  @override
  bool get isCompleted => _player?.state.completed ?? false;

  @override
  Future<void> play() async {
    if (_isDisposed) return;
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    await _player?.pause();
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) return;
    await _player?.stop();
    _playbackState.value = EnginePlaybackState.idle;
  }

  @override
  Future<void> seek(Duration position, {bool exact = false}) async {
    if (_isDisposed) return;
    await _player?.seek(position);
  }

  @override
  Future<void> setRate(double rate) async {
    if (_isDisposed) return;
    await _player?.setRate(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    if (volume.isNaN || volume.isInfinite) return;
    await _player?.setVolume((volume * 100.0).clamp(0.0, 100.0));
  }

  @override
  Future<void> setLooping(bool looping) async {
    if (_isDisposed) return;
    await _player?.setPlaylistMode(
      looping ? PlaylistMode.loop : PlaylistMode.none,
    );
  }

  @override
  Future<void> setAudioTrack(AudioTrackOption track) async {
    if (_isDisposed) return;
    await _player?.setAudioTrack(AudioTrack.auto());
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrackOption track) async {
    if (_isDisposed) return;
    if (track == SubtitleTrackOption.off) {
      await _player?.setSubtitleTrack(SubtitleTrack.no());
    } else if (track.file != null) {
      await _player?.setSubtitleTrack(SubtitleTrack.uri(track.file!.path));
    }
  }

  @override
  Future<Uint8List?> screenshot({String? format}) async {
    if (_isDisposed || _player == null) return null;
    return await _player!.screenshot(format: format ?? 'image/jpeg');
  }

  @override
  Future<Map<String, Object?>> getDiagnosticsInfo() async {
    return {
      'engine': 'MpvPlayerEngine',
      'width': _dimension.width,
      'height': _dimension.height,
      'position': currentPosition.inMilliseconds,
      'duration': currentDuration.inMilliseconds,
      'buffered': currentBufferedPosition.inMilliseconds,
      'playing': isPlaying,
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
    final VideoController? vc = _videoController;
    if (vc == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }

    return Video(
      key: key,
      controller: vc,
      controls: NoVideoControls,
      fit: fit,
      pauseUponEnteringBackgroundMode: pauseUponEnteringBackgroundMode,
      resumeUponEnteringForegroundMode: resumeUponEnteringForegroundMode,
      subtitleViewConfiguration: SubtitleViewConfiguration(
        style:
            subtitleStyle ??
            const TextStyle(
              height: 1.4,
              fontSize: 24,
              letterSpacing: 0.2,
              wordSpacing: 0.2,
              color: Color(0xffffffff),
              backgroundColor: Color(0xaa000000),
            ),
        padding: EdgeInsets.only(bottom: subtitleBottomPadding ?? 24.0),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _playbackState.value = EnginePlaybackState.idle;

    if (_player != null) {
      final Player player = _player!;
      _player = null;
      _videoController = null;

      try {
        final dynamic platform = player.platform;
        final dynamic releaseList = platform.release;
        if (releaseList is List) {
          final List<dynamic> callbacks = List<dynamic>.from(releaseList);
          releaseList.clear();
          for (final callback in callbacks) {
            try {
              await callback();
            } catch (_) {}
          }
        }
        await player.dispose();
      } catch (e) {
        debugPrint('MpvPlayerEngine.dispose error: $e');
      }
    }

    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _dimensionController.close();
    await _errorController.close();
    _playbackState.dispose();
  }
}

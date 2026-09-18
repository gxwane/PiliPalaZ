import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';

/// 统一媒体播放条目
class PlayerMediaItem {
  final Uri videoUri;
  final Uri? audioUri;
  final DataSourceType type;
  final Map<String, String>? httpHeaders;
  final Duration? startPosition;
  final bool isLive;
  final File? offlineSubtitleFile;

  const PlayerMediaItem({
    required this.videoUri,
    this.audioUri,
    this.type = DataSourceType.network,
    this.httpHeaders,
    this.startPosition,
    this.isLive = false,
    this.offlineSubtitleFile,
  });

  /// 从既有 DataSource 构造 PlayerMediaItem
  factory PlayerMediaItem.fromDataSource(
    DataSource source, {
    Duration? startPosition,
    bool isLive = false,
  }) {
    final Uri vUri = source.type == DataSourceType.file
        ? Uri.file(source.file!.path)
        : Uri.parse(source.videoSource ?? '');
    final Uri? aUri =
        (source.audioSource != null && source.audioSource!.isNotEmpty)
        ? Uri.parse(source.audioSource!)
        : null;

    return PlayerMediaItem(
      videoUri: vUri,
      audioUri: aUri,
      type: source.type,
      httpHeaders: source.httpHeaders,
      startPosition: startPosition,
      isLive: isLive,
      offlineSubtitleFile: source.offlineSubtitleFile,
    );
  }
}

/// 视频画面几何尺寸
class VideoDimension {
  final int width;
  final int height;

  const VideoDimension(this.width, this.height);

  static const VideoDimension zero = VideoDimension(0, 0);

  bool get hasSize => width > 0 && height > 0;

  double get aspectRatio => hasSize ? (width / height) : (16 / 9);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoDimension &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;

  @override
  String toString() => '${width}x$height';
}

/// 引擎底层状态机枚举
enum EnginePlaybackState {
  idle,
  loading,
  buffering,
  ready,
  playing,
  paused,
  completed,
  error,
}

/// 引擎错误码
enum EngineErrorCode {
  unknown,
  tokenExpiredOrForbidden,
  networkError,
  sourceNotFound,
  codecError,
}

/// 引擎异常封装
class EngineError {
  final EngineErrorCode code;
  final String message;
  final Object? cause;

  const EngineError({required this.code, required this.message, this.cause});

  @override
  String toString() => 'EngineError($code, $message, cause: $cause)';
}

/// 音轨选择项
class AudioTrackOption {
  final String id;
  final String label;
  final String? language;

  const AudioTrackOption({
    required this.id,
    required this.label,
    this.language,
  });

  static const AudioTrackOption auto = AudioTrackOption(
    id: 'auto',
    label: 'Auto',
  );
}

/// 字幕选择项
class SubtitleTrackOption {
  final String id;
  final String label;
  final String? language;
  final File? file;

  const SubtitleTrackOption({
    required this.id,
    required this.label,
    this.language,
    this.file,
  });

  static const SubtitleTrackOption off = SubtitleTrackOption(
    id: 'off',
    label: 'Off',
  );
}

/// 统一播放器内核抽象契约
abstract class IPlayerEngine implements PlaybackEngine {
  /// 初始化引擎资源
  Future<void> initialize();

  /// 打开媒体源
  Future<void> open(PlayerMediaItem item, {bool autoPlay = true});

  /// 状态与同步属性
  ValueListenable<EnginePlaybackState> get playbackState;
  VideoDimension get currentDimension;
  Duration get currentPosition;
  Duration get currentDuration;
  Duration get currentBufferedPosition;

  /// 响应式时钟与事件流
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<VideoDimension> get dimensionStream;
  Stream<EngineError> get errorStream;

  /// PlaybackEngine 契约方法
  @override
  bool get isPlaying;
  @override
  bool get isCompleted;
  @override
  Future<void> play();
  @override
  Future<void> pause();

  /// 控制指令
  Future<void> stop();
  Future<void> seek(Duration position, {bool exact = false});
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setLooping(bool looping);

  /// 轨道控制
  Future<void> setAudioTrack(AudioTrackOption track);
  Future<void> setSubtitleTrack(SubtitleTrackOption track);

  /// 诊断与画面抓取
  Future<Uint8List?> screenshot({String? format});
  Future<Map<String, Object?>> getDiagnosticsInfo();

  /// 统一视图构建工厂
  Widget buildVideoView({
    Key? key,
    BoxFit fit = BoxFit.contain,
    TextStyle? subtitleStyle,
    double? subtitleBottomPadding,
    bool pauseUponEnteringBackgroundMode = false,
    bool resumeUponEnteringForegroundMode = true,
  });

  /// 释放引擎资源
  Future<void> dispose();
}

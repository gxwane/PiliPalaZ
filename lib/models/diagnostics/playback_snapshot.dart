/// 播放统计与排障信息数据快照模型
class PlaybackSnapshot {
  /// 内核与管线信息
  final String engineName;
  final String rendererType;
  final String hwdec;
  final String audioOutput;

  /// 视频流规格
  final String videoQuality;
  final String videoCodec;
  final String resolution;
  final String frameRate;
  final String videoBitrate;

  /// 音频流规格
  final String audioQuality;
  final String audioCodec;
  final String audioBitrate;

  /// 播放与缓冲健康度
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double playbackSpeed;
  final String playbackState;

  /// 网络与元数据
  final String bvid;
  final int cid;
  final String cdnHost;
  final String sourceType;

  const PlaybackSnapshot({
    required this.engineName,
    required this.rendererType,
    required this.hwdec,
    required this.audioOutput,
    required this.videoQuality,
    required this.videoCodec,
    required this.resolution,
    required this.frameRate,
    required this.videoBitrate,
    required this.audioQuality,
    required this.audioCodec,
    required this.audioBitrate,
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.playbackSpeed,
    required this.playbackState,
    required this.bvid,
    required this.cid,
    required this.cdnHost,
    required this.sourceType,
  });

  String get formattedPosition => _formatDuration(position);
  String get formattedDuration => _formatDuration(duration);
  String get formattedBuffered => _formatDuration(bufferedPosition);

  int get bufferPercent => duration.inMilliseconds > 0
      ? ((bufferedPosition.inMilliseconds / duration.inMilliseconds) * 100)
            .clamp(0, 100)
            .toInt()
      : 0;

  /// 格式化为用于 GitHub Issue 或反馈贴的 Markdown 文本
  String toMarkdown() {
    return '''
### PiliPalaZ 播放统计与排障信息
- **播放内核**: $engineName | 渲染: $rendererType | 硬解: $hwdec | 音频输出: $audioOutput
- **视频流**: $videoQuality ($resolution @ $frameRate) | 编码: $videoCodec | 码率: $videoBitrate
- **音频流**: $audioQuality | 编码: $audioCodec | 码率: $audioBitrate
- **播放进度**: $formattedPosition / $formattedDuration | 缓冲: $formattedBuffered ($bufferPercent%) | 倍速: ${playbackSpeed.toStringAsFixed(1)}x | 状态: $playbackState
- **网络与标识**: BVID: $bvid | CID: $cid | CDN: $cdnHost | 来源: $sourceType
'''
        .trim();
  }

  static String _formatDuration(Duration d) {
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    final int seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

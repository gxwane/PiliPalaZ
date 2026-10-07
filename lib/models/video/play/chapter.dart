import 'dart:math';

import 'package:flutter/foundation.dart';
import 'subtitle.dart';

/// 视频分段章节模型（对应 B 站 view_points 字段）
@immutable
class VideoChapter {
  final int from;
  final int to;
  final String title;
  final String? imgUrl;

  const VideoChapter({
    required this.from,
    required this.to,
    required this.title,
    this.imgUrl,
  });

  int get durationSeconds => max(0, to - from);

  /// 检查给定秒数是否落入当前章节
  /// 若 [isLast] 为 true，则右侧边界闭合（包含 to）；否则为左闭右开 [from, to)
  bool contains(int second, {bool isLast = false}) {
    if (isLast) {
      return second >= from && second <= to;
    }
    return second >= from && second < to;
  }

  /// 从 B 站 view_points 原始条目反序列化
  factory VideoChapter.fromJson(Map<String, dynamic> json) {
    int parseSec(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) {
        final d = double.tryParse(val);
        if (d != null) return d.toInt();
      }
      return 0;
    }

    final rawFrom = max(0, parseSec(json['from']));
    final rawTo = max(0, parseSec(json['to']));
    final minSec = min(rawFrom, rawTo);
    final maxSec = max(rawFrom, rawTo);

    final rawTitle =
        json['content']?.toString() ?? json['title']?.toString() ?? '';

    return VideoChapter(
      from: minSec,
      to: maxSec,
      title: rawTitle,
      imgUrl: json['imgUrl']?.toString(),
    );
  }

  /// 提取章节间的分段切分点（用于进度条间隙绘制）
  /// 仅返回处于 (0, totalDurationSeconds) 内部且严格升序的切分点
  static List<Duration> resolveChapterSplitPoints(
    List<VideoChapter> chapters, {
    required int totalDurationSeconds,
  }) {
    if (chapters.length <= 1 || totalDurationSeconds <= 0) {
      return const <Duration>[];
    }

    final points = <int>{};
    for (int i = 0; i < chapters.length; i++) {
      final c = chapters[i];
      if (c.from > 0 && c.from < totalDurationSeconds) {
        points.add(c.from);
      }
      if (c.to > 0 && c.to < totalDurationSeconds) {
        points.add(c.to);
      }
    }

    final sorted = points.toList()..sort();
    return sorted.map((sec) => Duration(seconds: sec)).toList(growable: false);
  }

  /// 序列化为 JSON Map
  Map<String, dynamic> toJson() => <String, dynamic>{
    'from': from,
    'to': to,
    'title': title,
    if (imgUrl != null) 'imgUrl': imgUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoChapter &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          title == other.title &&
          imgUrl == other.imgUrl;

  @override
  int get hashCode => Object.hash(from, to, title, imgUrl);

  @override
  String toString() => 'VideoChapter($from-$to: $title)';
}

/// 聚合视频播放器元数据（字幕 + 章节）
@immutable
class VideoPlayerMetadata {
  final List<VideoSubtitleSource> subtitles;
  final List<VideoChapter> chapters;

  const VideoPlayerMetadata({
    this.subtitles = const <VideoSubtitleSource>[],
    this.chapters = const <VideoChapter>[],
  });
}

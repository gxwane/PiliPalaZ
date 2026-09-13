import 'package:pilipalaz/models/bangumi/info.dart' as pgc;
import 'package:pilipalaz/models/model_hot_video_item.dart';
import 'package:pilipalaz/models/video_detail_res.dart' as ugc;

enum PlayQueueSourceType {
  part, // 单视频分 P
  ugcSeason, // UGC 视频合集
  pgcEpisode, // PGC 影视番剧
  watchLater, // 稍后再看
  related, // 相关视频连播
  custom, // 用户自定义/手动入队
}

extension PlayQueueSourceTypeExtension on PlayQueueSourceType {
  String get label {
    switch (this) {
      case PlayQueueSourceType.part:
        return '分P列表';
      case PlayQueueSourceType.ugcSeason:
        return '合集列表';
      case PlayQueueSourceType.pgcEpisode:
        return '剧集列表';
      case PlayQueueSourceType.watchLater:
        return '稍后再看';
      case PlayQueueSourceType.related:
        return '相关推荐';
      case PlayQueueSourceType.custom:
        return '自定义队列';
    }
  }
}

class PlayQueueItem {
  final String id;
  final String bvid;
  final int cid;
  final int? aid;
  final int? epId;
  final int? seasonId;
  final String title;
  final String? cover;
  final int duration;
  final String? author;
  final String? badge;
  final PlayQueueSourceType sourceType;
  final dynamic rawData;

  const PlayQueueItem({
    required this.id,
    required this.bvid,
    required this.cid,
    this.aid,
    this.epId,
    this.seasonId,
    required this.title,
    this.cover,
    this.duration = 0,
    this.author,
    this.badge,
    required this.sourceType,
    this.rawData,
  });

  factory PlayQueueItem.fromPart(
    ugc.Part part, {
    required String bvid,
    required int aid,
    String? cover,
    String? author,
  }) {
    final int resolvedCid = part.cid ?? 0;
    return PlayQueueItem(
      id: 'part_${bvid}_$resolvedCid',
      bvid: bvid,
      cid: resolvedCid,
      aid: aid,
      title: (part.pagePart != null && part.pagePart!.isNotEmpty)
          ? part.pagePart!
          : 'P${part.page ?? 1}',
      cover: cover ?? part.firstFrame,
      duration: part.duration ?? 0,
      author: author,
      badge: part.badge,
      sourceType: PlayQueueSourceType.part,
      rawData: part,
    );
  }

  factory PlayQueueItem.fromUgcEpisode(
    ugc.EpisodeItem item, {
    String? cover,
    String? author,
  }) {
    final String resolvedBvid = item.bvid ?? '';
    final int resolvedCid = item.cid ?? item.page?.cid ?? 0;
    final String resolvedTitle = item.title?.isNotEmpty == true
        ? (item.longTitle?.isNotEmpty == true
              ? '${item.title} ${item.longTitle}'
              : item.title!)
        : (item.page?.pagePart ?? '第${item.id ?? 1}话');

    return PlayQueueItem(
      id: 'ugc_${resolvedBvid}_$resolvedCid',
      bvid: resolvedBvid,
      cid: resolvedCid,
      aid: item.aid,
      seasonId: item.seasonId,
      title: resolvedTitle,
      cover: cover ?? item.page?.firstFrame,
      duration: item.page?.duration ?? 0,
      author: author,
      badge: item.badge,
      sourceType: PlayQueueSourceType.ugcSeason,
      rawData: item,
    );
  }

  factory PlayQueueItem.fromPgcEpisode(
    pgc.EpisodeItem item, {
    int? seasonId,
    String? cover,
  }) {
    final String resolvedBvid = item.bvid ?? '';
    final int resolvedCid = item.cid ?? 0;
    final int resolvedEpId = item.epId ?? 0;
    final String resolvedTitle = item.longTitle?.isNotEmpty == true
        ? '第${item.title ?? ''}话 ${item.longTitle}'
        : (item.title?.isNotEmpty == true
              ? item.title!
              : (item.shareCopy ?? '第$resolvedEpId集'));

    return PlayQueueItem(
      id: 'pgc_${resolvedEpId}_${resolvedBvid}_$resolvedCid',
      bvid: resolvedBvid,
      cid: resolvedCid,
      aid: item.aid,
      epId: resolvedEpId,
      seasonId: seasonId,
      title: resolvedTitle,
      cover: item.cover ?? cover,
      duration: (item.duration != null) ? (item.duration! ~/ 1000) : 0,
      badge: item.badge,
      sourceType: PlayQueueSourceType.pgcEpisode,
      rawData: item,
    );
  }

  factory PlayQueueItem.fromHotVideoItem(
    HotVideoItemModel item, {
    PlayQueueSourceType sourceType = PlayQueueSourceType.watchLater,
  }) {
    final String resolvedBvid = item.bvid ?? '';
    final int resolvedCid = item.cid ?? 0;
    final int? resolvedAid = item.aid;

    return PlayQueueItem(
      id: '${sourceType.name}_${resolvedBvid}_$resolvedCid',
      bvid: resolvedBvid,
      cid: resolvedCid,
      aid: resolvedAid,
      title: item.title ?? '',
      cover: item.pic,
      duration: item.duration ?? 0,
      author: item.owner?.name,
      sourceType: sourceType,
      rawData: item,
    );
  }

  PlayQueueItem copyWith({
    String? id,
    String? bvid,
    int? cid,
    int? aid,
    int? epId,
    int? seasonId,
    String? title,
    String? cover,
    int? duration,
    String? author,
    String? badge,
    PlayQueueSourceType? sourceType,
    dynamic rawData,
  }) {
    return PlayQueueItem(
      id: id ?? this.id,
      bvid: bvid ?? this.bvid,
      cid: cid ?? this.cid,
      aid: aid ?? this.aid,
      epId: epId ?? this.epId,
      seasonId: seasonId ?? this.seasonId,
      title: title ?? this.title,
      cover: cover ?? this.cover,
      duration: duration ?? this.duration,
      author: author ?? this.author,
      badge: badge ?? this.badge,
      sourceType: sourceType ?? this.sourceType,
      rawData: rawData ?? this.rawData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayQueueItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

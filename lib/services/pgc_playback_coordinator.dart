import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../http/pgc.dart';
import '../http/api_result.dart';
import '../models/bangumi/info.dart';
import '../models/common/pgc_type.dart';
import '../models/common/search_type.dart';
import '../models/common/video_source_type.dart';
import '../utils/utils.dart';

class PgcEpisodeNotFoundException implements Exception {
  const PgcEpisodeNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PgcEpisodeSelector {
  static EpisodeItem select({
    required List<EpisodeItem> episodes,
    int? explicitEpId,
    int? progressEpId,
  }) {
    if (episodes.isEmpty) {
      throw const PgcEpisodeNotFoundException('该影视内容暂无可播放剧集');
    }
    if (explicitEpId != null) {
      for (final EpisodeItem episode in episodes) {
        if (episode.epId == explicitEpId) return episode;
      }
      throw const PgcEpisodeNotFoundException('指定剧集不存在或已下架');
    }
    if (progressEpId != null) {
      for (final EpisodeItem episode in episodes) {
        if (episode.epId == progressEpId) return episode;
      }
    }
    return episodes.first;
  }
}

class PgcEpisodeNavigator {
  static int? nextIndex({
    required int episodeCount,
    required int currentIndex,
    required bool cycle,
  }) {
    if (episodeCount <= 0 || currentIndex < 0 || currentIndex >= episodeCount) {
      return null;
    }
    final int next = currentIndex + 1;
    if (next < episodeCount) return next;
    return cycle ? 0 : null;
  }
}

class PgcPlaybackCoordinator {
  static Future<bool> open({
    int? seasonId,
    int? epId,
    String? pic,
    String? heroTag,
  }) async {
    if (seasonId == null && epId == null) {
      SmartDialog.showToast('缺少影视剧集信息');
      return false;
    }
    SmartDialog.showLoading(msg: '获取中...');
    final result = await PgcApi.instance.infoWithFollowStatus(
      seasonId: seasonId,
      epId: epId,
    );
    await SmartDialog.dismiss();
    if (result case final ApiFailure<PgcInfoBundle> failure) {
      SmartDialog.showToast(failure.message);
      return false;
    }

    final BangumiInfoModel info =
        (result as ApiSuccess<PgcInfoBundle>).data.detail;
    try {
      final EpisodeItem episode = PgcEpisodeSelector.select(
        episodes: info.episodes ?? const <EpisodeItem>[],
        explicitEpId: epId,
        progressEpId: info.userStatus?.progress?.lastEpId,
      );
      if (episode.epId == null ||
          episode.cid == null ||
          episode.bvid?.isNotEmpty != true) {
        throw const PgcEpisodeNotFoundException('该剧集的播放信息不完整');
      }
      final PgcCatalogType catalogType = PgcCatalogTypeCode.fromApiValue(
        info.type ?? info.showSeasonType,
      );
      final SearchType searchType =
          catalogType.followGroup == PgcFollowGroup.bangumi
          ? SearchType.media_bangumi
          : SearchType.media_ft;
      final String resolvedHeroTag = heroTag ?? Utils.makeHeroTag(episode.cid!);
      await Get.toNamed<dynamic>(
        '/video?bvid=${episode.bvid}&cid=${episode.cid}'
        '&seasonId=${info.seasonId ?? seasonId}'
        '&epId=${episode.epId}',
        arguments: <String, dynamic>{
          'pic': pic?.isNotEmpty == true ? pic : episode.cover,
          'heroTag': resolvedHeroTag,
          'videoType': searchType,
          'sourceType': VideoSourceType.pgc,
          'bangumiItem': info,
        },
      );
      return true;
    } on PgcEpisodeNotFoundException catch (error) {
      SmartDialog.showToast(error.message);
      return false;
    }
  }
}

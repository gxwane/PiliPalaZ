import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/introduction/bangumi/controller.dart';
import 'package:pilipalaz/utils/storage.dart';

class BangumiEpisodeCatalogView extends StatefulWidget {
  const BangumiEpisodeCatalogView({super.key, required this.heroTag});

  final String heroTag;

  @override
  State<BangumiEpisodeCatalogView> createState() =>
      _BangumiEpisodeCatalogViewState();
}

class _BangumiEpisodeCatalogViewState extends State<BangumiEpisodeCatalogView> {
  final ScrollController _scrollController = ScrollController();
  late final BangumiIntroController _bangumiIntroCtr;
  late final VideoDetailController _videoDetailCtr;

  @override
  void initState() {
    super.initState();
    _bangumiIntroCtr = Get.find<BangumiIntroController>(tag: widget.heroTag);
    _videoDetailCtr = Get.find<VideoDetailController>(tag: widget.heroTag);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveEpisode();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveEpisode() {
    if (!mounted || !_scrollController.hasClients) return;
    final episodes = _bangumiIntroCtr.bangumiDetail.value.episodes;
    if (episodes == null || episodes.isEmpty) return;

    final int currentCid = _videoDetailCtr.cid.value;
    final int index = episodes.indexWhere((e) => e.cid == currentCid);
    if (index > 0) {
      final double targetOffset = (index * 72.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleEpisodeTap(EpisodeItem episode) {
    if (episode.badge == '会员') {
      try {
        final dynamic userInfo = GStorage.userInfo.get('userInfoCache');
        int vipStatus = 0;
        if (userInfo != null) {
          vipStatus = userInfo.vipStatus ?? 0;
        }
        if (vipStatus != 1) {
          SmartDialog.showToast('需要大会员');
          return;
        }
      } catch (_) {}
    }

    _bangumiIntroCtr.changeSeasonOrbangu(
      episode.bvid,
      episode.cid,
      episode.aid,
      episode.epId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Obx(() {
      final detail = _bangumiIntroCtr.bangumiDetail.value;
      final episodes = detail.episodes ?? const <EpisodeItem>[];
      final currentCid = _videoDetailCtr.cid.value;
      final isMovie = detail.type == 2;

      if (episodes.isEmpty) {
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );
      }

      final seasons = detail.seasons;
      final bool hasMultipleSeasons = seasons != null && seasons.length > 1;

      return CustomScrollView(
        controller: _scrollController,
        cacheExtent: 3500,
        slivers: [
          if (hasMultipleSeasons)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: seasons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final season = seasons[index];
                    final seasonTitle =
                        (season['season_title'] ??
                                season['title'] ??
                                '第${index + 1}季')
                            .toString();
                    final seasonId = season['season_id'];
                    final isCurrentSeason = detail.seasonId == seasonId;

                    return FilterChip(
                      selected: isCurrentSeason,
                      label: Text(
                        seasonTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrentSeason
                              ? primaryColor
                              : theme.colorScheme.onSurface,
                          fontWeight: isCurrentSeason
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onSelected: (_) {
                        if (!isCurrentSeason && seasonId != null) {
                          _bangumiIntroCtr.seasonId = seasonId;
                          _bangumiIntroCtr.queryBangumiIntro();
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    isMovie ? '正片片目' : '剧集选集',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMovie
                        ? '共 ${episodes.length} 部'
                        : '共 ${episodes.length} 话',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList.separated(
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final bool isCurrent = episode.cid == currentCid;
                final title = episode.title ?? '第${index + 1}话';
                final longTitle = episode.longTitle;
                final badge = episode.badge;

                return Material(
                  color: isCurrent
                      ? primaryColor.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _handleEpisodeTap(episode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          if (isCurrent) ...[
                            Image.asset(
                              'assets/images/live.png',
                              color: primaryColor,
                              height: 12,
                              semanticLabel: '正在播放：',
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isCurrent
                                        ? primaryColor
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (longTitle != null &&
                                    longTitle.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    longTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCurrent
                                          ? primaryColor.withValues(alpha: 0.85)
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (badge != null && badge.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            if (badge == '会员')
                              Image.asset(
                                'assets/images/big-vip.png',
                                height: 16,
                                semanticLabel: '大会员',
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

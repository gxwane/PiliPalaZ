import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/index.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/season_sheet.dart';

class SeasonPanel extends StatefulWidget {
  const SeasonPanel({
    super.key,
    required this.ugcSeason,
    this.cid,
    this.bvid,
    required this.changeFuc,
    required this.heroTag,
  });

  final UgcSeason ugcSeason;
  final int? cid;
  final String? bvid;
  final Function changeFuc;
  final String heroTag;

  @override
  State<SeasonPanel> createState() => _SeasonPanelState();
}

class _SeasonPanelState extends State<SeasonPanel> {
  late int cid;
  StreamSubscription<int>? _cidSub;

  @override
  void initState() {
    super.initState();
    cid = widget.cid ?? 0;
    if (Get.isRegistered<VideoDetailController>(tag: widget.heroTag)) {
      final videoDetailController = Get.find<VideoDetailController>(
        tag: widget.heroTag,
      );
      _cidSub = videoDetailController.cid.listen((int p0) {
        if (!mounted) return;
        setState(() {
          cid = p0;
        });
      });
    }
  }

  @override
  void didUpdateWidget(SeasonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cid != null &&
        widget.cid != oldWidget.cid &&
        widget.cid != cid) {
      cid = widget.cid!;
    }
  }

  @override
  void dispose() {
    _cidSub?.cancel();
    super.dispose();
  }

  (SectionItem, int, int) _resolveActivePosition(List<SectionItem> sections) {
    if (cid != 0) {
      for (int sIdx = 0; sIdx < sections.length; sIdx++) {
        final episodes = sections[sIdx].episodes ?? <EpisodeItem>[];
        for (int epIdx = 0; epIdx < episodes.length; epIdx++) {
          final ep = episodes[epIdx];
          if (ep.cid == cid || ep.page?.cid == cid) {
            return (sections[sIdx], epIdx, sIdx);
          }
        }
      }
    }
    if (widget.bvid != null && widget.bvid!.isNotEmpty) {
      for (int sIdx = 0; sIdx < sections.length; sIdx++) {
        final episodes = sections[sIdx].episodes ?? <EpisodeItem>[];
        for (int epIdx = 0; epIdx < episodes.length; epIdx++) {
          final ep = episodes[epIdx];
          if (ep.bvid == widget.bvid) {
            return (sections[sIdx], epIdx, sIdx);
          }
        }
      }
    }
    return (sections.first, -1, 0);
  }

  String _formatCardTitle(
    List<SectionItem> sections,
    SectionItem activeSection,
  ) {
    if (sections.length <= 1) {
      return '合集：${widget.ugcSeason.title ?? activeSection.title ?? ''}';
    }
    final seasonTitle = widget.ugcSeason.title ?? '';
    final secTitle = activeSection.title?.trim() ?? '';
    if (secTitle.isEmpty) {
      return seasonTitle.isNotEmpty ? '合集：$seasonTitle' : '合集';
    }
    if (seasonTitle.isEmpty || secTitle.contains(seasonTitle)) {
      return '合集：$secTitle';
    }
    return '合集：$seasonTitle · $secTitle';
  }

  void _openSeasonListSheet(BuildContext context) {
    SeasonListSheet(
      ugcSeason: widget.ugcSeason,
      currentCid: cid,
      currentBvid: widget.bvid,
      changeFucCall: widget.changeFuc,
      context: context,
    ).buildShowBottomSheet();
  }

  @override
  Widget build(BuildContext context) {
    final List<SectionItem> sections =
        widget.ugcSeason.sections ?? <SectionItem>[];
    if (sections.isEmpty) {
      return const SizedBox();
    }

    final (activeSection, activeEpIndex, _) = _resolveActivePosition(sections);
    final String cardTitle = _formatCardTitle(sections, activeSection);
    final List<EpisodeItem> activeEpisodes =
        activeSection.episodes ?? <EpisodeItem>[];
    final bool isPlayingHere = activeEpIndex != -1;

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 2, right: 2, bottom: 2),
      child: Material(
        color: Theme.of(context).colorScheme.onInverseSurface,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => _openSeasonListSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    cardTitle,
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 15),
                if (isPlayingHere) ...[
                  Image.asset(
                    'assets/images/live.png',
                    color: Theme.of(context).colorScheme.primary,
                    height: 12,
                    semanticLabel: "正在播放：",
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${activeEpIndex + 1}/${activeEpisodes.length}',
                    style: Theme.of(context).textTheme.labelMedium,
                    semanticsLabel:
                        '第${activeEpIndex + 1}集，共${activeEpisodes.length}集',
                  ),
                ] else ...[
                  Text(
                    '共${activeEpisodes.length}集',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    semanticsLabel: '共${activeEpisodes.length}集',
                  ),
                ],
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_outlined,
                  size: 13,
                  semanticLabel: '查看',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

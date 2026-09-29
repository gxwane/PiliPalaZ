import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/list_sheet.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/index.dart';

class SeasonPanel extends StatefulWidget {
  const SeasonPanel({
    super.key,
    required this.ugcSeason,
    this.cid,
    required this.changeFuc,
    required this.heroTag,
  });
  final UgcSeason ugcSeason;
  final int? cid;
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

  Widget _buildSectionCard(
    BuildContext context,
    SectionItem section,
    int index,
    bool isMultiSection,
  ) {
    final List<EpisodeItem> episodesList = section.episodes ?? <EpisodeItem>[];
    final int currentIdx = episodesList.indexWhere(
      (EpisodeItem e) => e.cid == cid,
    );
    final bool isPlayingHere = currentIdx != -1;

    String title;
    if (!isMultiSection) {
      title = '合集：${widget.ugcSeason.title ?? section.title ?? ''}';
    } else {
      final seasonTitle = widget.ugcSeason.title ?? '';
      final secTitle = section.title?.trim() ?? '';
      if (secTitle.isEmpty) {
        title = seasonTitle.isNotEmpty
            ? '合集：$seasonTitle (${index + 1})'
            : '合集 (${index + 1})';
      } else if (seasonTitle.isEmpty || secTitle.contains(seasonTitle)) {
        title = '合集：$secTitle';
      } else {
        title = '合集：$seasonTitle · $secTitle';
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 2, right: 2, bottom: 2),
      child: Material(
        color: Theme.of(context).colorScheme.onInverseSurface,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () {
            ListSheet(
              episodes: episodesList,
              currentCid: cid,
              changeFucCall: widget.changeFuc,
              context: context,
            ).buildShowBottomSheet();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
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
                    '${currentIdx + 1}/${episodesList.length}',
                    style: Theme.of(context).textTheme.labelMedium,
                    semanticsLabel:
                        '第${currentIdx + 1}集，共${episodesList.length}集',
                  ),
                ] else ...[
                  Text(
                    '共${episodesList.length}集',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    semanticsLabel: '共${episodesList.length}集',
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

  @override
  Widget build(BuildContext context) {
    final List<SectionItem> sections =
        widget.ugcSeason.sections ?? <SectionItem>[];
    if (sections.isEmpty) {
      return const SizedBox();
    }

    if (sections.length == 1) {
      return _buildSectionCard(context, sections.first, 0, false);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < sections.length; i++)
          _buildSectionCard(context, sections[i], i, true),
      ],
    );
  }
}

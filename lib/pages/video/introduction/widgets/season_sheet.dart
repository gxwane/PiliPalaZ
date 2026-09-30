import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pilipalaz/common/widgets/my_dialog.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class SeasonListSheet {
  SeasonListSheet({
    required this.ugcSeason,
    required this.currentCid,
    this.currentBvid,
    required this.changeFucCall,
    required this.context,
  });

  final UgcSeason ugcSeason;
  final int currentCid;
  final String? currentBvid;
  final Function changeFucCall;
  final BuildContext context;

  void buildShowBottomSheet() {
    MyDialog.showCorner(
      context,
      SeasonSheetContent(
        ugcSeason: ugcSeason,
        currentCid: currentCid,
        currentBvid: currentBvid,
        changeFucCall: changeFucCall,
      ),
    );
  }
}

class SeasonSheetContent extends StatefulWidget {
  const SeasonSheetContent({
    super.key,
    required this.ugcSeason,
    required this.currentCid,
    this.currentBvid,
    required this.changeFucCall,
  });

  final UgcSeason ugcSeason;
  final int currentCid;
  final String? currentBvid;
  final Function changeFucCall;

  @override
  State<SeasonSheetContent> createState() => _SeasonSheetContentState();
}

class _SeasonSheetContentState extends State<SeasonSheetContent> {
  ItemScrollController itemScrollController = ItemScrollController();
  late int selectedSectionIndex;
  bool reverse = false;

  bool _isEpisodeMatch(EpisodeItem episode) {
    if (widget.currentCid != 0) {
      return episode.cid == widget.currentCid ||
          episode.page?.cid == widget.currentCid;
    }
    if (widget.currentBvid != null && widget.currentBvid!.isNotEmpty) {
      return episode.bvid == widget.currentBvid;
    }
    return false;
  }

  int _resolveInitialSectionIndex() {
    final sections = widget.ugcSeason.sections ?? <SectionItem>[];
    for (int i = 0; i < sections.length; i++) {
      final eps = sections[i].episodes ?? <EpisodeItem>[];
      if (eps.any(_isEpisodeMatch)) {
        return i;
      }
    }
    return 0;
  }

  int _calculateTotalEpisodes(List<SectionItem> sections) {
    int total = 0;
    for (final s in sections) {
      total += s.episodes?.length ?? 0;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    selectedSectionIndex = _resolveInitialSectionIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentPlayingIfPresent();
    });
  }

  void _scrollToCurrentPlayingIfPresent() {
    final sections = widget.ugcSeason.sections ?? <SectionItem>[];
    if (selectedSectionIndex < 0 || selectedSectionIndex >= sections.length) {
      return;
    }
    final currentEpisodes =
        sections[selectedSectionIndex].episodes ?? <EpisodeItem>[];
    final targetIndex = currentEpisodes.indexWhere(_isEpisodeMatch);
    if (targetIndex >= 0 &&
        targetIndex < currentEpisodes.length &&
        itemScrollController.isAttached) {
      itemScrollController.jumpTo(index: targetIndex);
    }
  }

  void _selectSection(int index) {
    if (selectedSectionIndex == index) return;
    setState(() {
      selectedSectionIndex = index;
      itemScrollController = ItemScrollController();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentPlayingIfPresent();
    });
  }

  void _onEpisodeTap(EpisodeItem episode, String title) {
    if (episode.badge != null && episode.badge == "会员") {
      dynamic userInfo = GStorage.userInfo.get('userInfoCache');
      int vipStatus = 0;
      if (userInfo != null) {
        vipStatus = userInfo.vipStatus;
      }
      if (vipStatus != 1) {
        SmartDialog.showToast('需要大会员');
        return;
      }
    }
    SmartDialog.showToast('切换到：$title');
    Get.back();
    widget.changeFucCall(
      episode.bvid,
      episode.cid ?? episode.page?.cid,
      episode.aid,
    );
  }

  Widget _buildEpisodeListItem(
    BuildContext context,
    EpisodeItem episode,
    int index,
    int totalCount,
  ) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool isCurrentIndex = _isEpisodeMatch(episode);

    late String title;
    if (episode.longTitle != null && episode.longTitle!.isNotEmpty) {
      title = "第${episode.title ?? '${index + 1}'}话  ${episode.longTitle!}";
    } else {
      title = episode.title ?? '第${index + 1}话';
    }

    return ListTile(
      onTap: () => _onEpisodeTap(episode, title),
      selected: isCurrentIndex,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isCurrentIndex
                    ? primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              semanticsLabel: isCurrentIndex ? "正在播放：$title" : title,
            ),
          ),
          if (episode.badge != null && episode.badge!.isNotEmpty) ...[
            const SizedBox(width: 10),
            if (episode.badge == '会员')
              Image.asset(
                'assets/images/big-vip.png',
                height: 20,
                semanticLabel: "大会员",
              )
            else
              Text(episode.badge!),
            const SizedBox(width: 10),
          ],
          if (episode.longTitle == null || episode.longTitle!.isEmpty) ...[
            const SizedBox(width: 10),
            Text(
              '${index + 1}/$totalCount',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTabs(BuildContext context, List<SectionItem> sections) {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = sections[index];
          final isSelected = index == selectedSectionIndex;
          final bool hasPlaying = (section.episodes ?? <EpisodeItem>[]).any(
            _isEpisodeMatch,
          );
          final label =
              '${section.title ?? '分卷'} (${section.episodes?.length ?? 0})';

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPlaying) ...[
                  Image.asset(
                    'assets/images/live.png',
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    height: 11,
                    semanticLabel: '当前播放分卷',
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => _selectSection(index),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<SectionItem> sections =
        widget.ugcSeason.sections ?? <SectionItem>[];
    final int totalEpisodes = _calculateTotalEpisodes(sections);
    final SectionItem? currentSection =
        sections.isNotEmpty && selectedSectionIndex < sections.length
        ? sections[selectedSectionIndex]
        : null;
    final List<EpisodeItem> episodes =
        currentSection?.episodes ?? <EpisodeItem>[];

    return Container(
      height: 520,
      width: min(Get.width, 500),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.only(top: 3, bottom: 10),
      child: Column(
        children: [
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sections.length > 1
                        ? '合集（共$totalEpisodes集）'
                        : '合集（$totalEpisodes）',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '跳至顶部',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(Icons.vertical_align_top),
                  onPressed: () {
                    if (episodes.isEmpty || !itemScrollController.isAttached) {
                      return;
                    }
                    itemScrollController.scrollTo(
                      index: !reverse ? 0 : episodes.length - 1,
                      duration: const Duration(milliseconds: 200),
                    );
                  },
                ),
                IconButton(
                  tooltip: '跳至底部',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(Icons.vertical_align_bottom),
                  onPressed: () {
                    if (episodes.isEmpty || !itemScrollController.isAttached) {
                      return;
                    }
                    itemScrollController.scrollTo(
                      index: !reverse ? episodes.length - 1 : 0,
                      duration: const Duration(milliseconds: 200),
                    );
                  },
                ),
                IconButton(
                  tooltip: '反序',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Icon(
                    !reverse ? MdiIcons.sortAscending : MdiIcons.sortDescending,
                  ),
                  onPressed: () {
                    setState(() {
                      reverse = !reverse;
                    });
                  },
                ),
                IconButton(
                  tooltip: '关闭',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: Get.back,
                ),
              ],
            ),
          ),
          if (sections.length > 1) _buildSectionTabs(context, sections),
          Divider(
            height: 1,
            indent: 10,
            endIndent: 20,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 1),
          Expanded(
            child: Material(
              child: ScrollablePositionedList.separated(
                key: ValueKey<String>(
                  'season_section_${currentSection?.id ?? 0}_$selectedSectionIndex',
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                reverse: reverse,
                itemCount: episodes.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildEpisodeListItem(
                    context,
                    episodes[index],
                    index,
                    episodes.length,
                  );
                },
                itemScrollController: itemScrollController,
                separatorBuilder: (_, index) => Divider(
                  indent: 18,
                  endIndent: 25,
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/badge.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/services/pgc_playback_coordinator.dart';
import 'package:pilipalaz/utils/utils.dart';

import '../../../utils/grid.dart';

Widget searchBangumiPanel(BuildContext context, ctr, list) {
  TextStyle style = TextStyle(
    fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
  );
  return CustomScrollView(
    cacheExtent: 3500,
    controller: ctr.scrollController,
    slivers: [
      SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          mainAxisSpacing: StyleString.safeSpace,
          crossAxisSpacing: StyleString.safeSpace,
          maxCrossAxisExtent: Grid.maxRowWidth * 2,
          mainAxisExtent: 160,
        ),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          var i = list![index];
          return InkWell(
            onTap: () => PgcPlaybackCoordinator.open(seasonId: i.seasonId),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                StyleString.safeSpace,
                StyleString.safeSpace,
                StyleString.safeSpace,
                2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      NetworkImgLayer(width: 111, height: 148, src: i.cover),
                      PBadge(
                        text: i.seasonTypeName ?? '影视',
                        top: 6.0,
                        right: 4.0,
                        bottom: null,
                        left: null,
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            children: [
                              for (var i in i.title) ...[
                                TextSpan(
                                  text: i['text'],
                                  style: TextStyle(
                                    fontSize: MediaQuery.textScalerOf(context)
                                        .scale(
                                          Theme.of(
                                            context,
                                          ).textTheme.titleSmall!.fontSize!,
                                        ),
                                    fontWeight: FontWeight.bold,
                                    color: i['type'] == 'em'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (i.mediaScore?['score'] != null)
                          Text('评分:${i.mediaScore['score']}', style: style),
                        Row(
                          children: [
                            Text(i.areas, style: style),
                            const SizedBox(width: 3),
                            const Text('·'),
                            const SizedBox(width: 3),
                            Text(
                              Utils.dateFormat(i.pubtime).toString(),
                              style: style,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(i.styles, style: style),
                            const SizedBox(width: 3),
                            const Text('·'),
                            const SizedBox(width: 3),
                            Text(i.indexShow, style: style),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () => PgcPlaybackCoordinator.open(
                              seasonId: i.seasonId,
                            ),
                            child: const Text('观看'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: list.length),
      ),
    ],
  );
}

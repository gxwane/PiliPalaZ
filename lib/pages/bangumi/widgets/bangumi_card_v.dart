import 'package:flutter/material.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/badge.dart';
import 'package:pilipalaz/models/bangumi/list.dart';
import 'package:pilipalaz/services/pgc_playback_coordinator.dart';
import 'package:pilipalaz/services/pgc_vip_entitlement_resolver.dart';
import 'package:pilipalaz/utils/utils.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends StatelessWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.longPress,
    this.longPressEnd,
    this.onTap,
    this.vipEntitlement,
  });

  final BangumiListItemModel bangumiItem;
  final Function()? longPress;
  final Function()? longPressEnd;
  final VoidCallback? onTap;
  final PgcVipEntitlement? vipEntitlement;

  @override
  Widget build(BuildContext context) {
    final String title = bangumiItem.title?.trim().isNotEmpty == true
        ? bangumiItem.title!
        : '未命名影视';
    final String heroTag = Utils.makeHeroTag(
      bangumiItem.mediaId ?? bangumiItem.seasonId ?? title.hashCode,
    );
    final String? overlayText = _overlayText(bangumiItem);
    final String? displayBadge = _displayBadge(bangumiItem, vipEntitlement);
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      margin: EdgeInsets.zero,
      child: GestureDetector(
        onLongPress: longPress,
        onLongPressEnd: longPressEnd == null ? null : (_) => longPressEnd!(),
        child: InkWell(
          onTap:
              onTap ??
              () => PgcPlaybackCoordinator.open(
                seasonId: bangumiItem.seasonId,
                heroTag: heroTag,
                pic: bangumiItem.cover,
              ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: StyleString.imgRadius,
                  topRight: StyleString.imgRadius,
                  bottomLeft: StyleString.imgRadius,
                  bottomRight: StyleString.imgRadius,
                ),
                child: AspectRatio(
                  aspectRatio: 0.65,
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) {
                      final double maxWidth = boxConstraints.maxWidth;
                      final double maxHeight = boxConstraints.maxHeight;
                      return Stack(
                        children: [
                          Hero(
                            tag: heroTag,
                            child: NetworkImgLayer(
                              src: bangumiItem.cover,
                              width: maxWidth,
                              height: maxHeight,
                            ),
                          ),
                          if (displayBadge != null)
                            PBadge(
                              text: displayBadge,
                              top: 6,
                              right: 6,
                              bottom: null,
                              left: null,
                            ),
                          if (overlayText != null)
                            PBadge(
                              text: overlayText,
                              top: null,
                              right: null,
                              bottom: 6,
                              left: 6,
                              type: 'gray',
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              BangumiContent(bangumiItem: bangumiItem, title: title),
            ],
          ),
        ),
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({
    super.key,
    required this.bangumiItem,
    required this.title,
  });

  final BangumiListItemModel bangumiItem;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        // 多列
        padding: const EdgeInsets.fromLTRB(4, 5, 0, 3),
        // 单列
        // padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            if (bangumiItem.indexShow?.isNotEmpty == true)
              Text(
                bangumiItem.indexShow!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            if (bangumiItem.indexShow?.isNotEmpty != true &&
                bangumiItem.subTitle?.isNotEmpty == true)
              Text(
                bangumiItem.subTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String? _overlayText(BangumiListItemModel item) {
  final String score = item.score?.trim() ?? '';
  if (score.isNotEmpty) {
    return score.endsWith('分') ? score : '$score分';
  }
  final String order = item.order?.trim() ?? '';
  return order.isEmpty ? null : order;
}

String? _displayBadge(
  BangumiListItemModel item,
  PgcVipEntitlement? vipEntitlement,
) {
  final String badge = item.badge?.trim() ?? '';
  if (badge.isEmpty) return null;
  final bool isVipCatalogBadge = item.badgeType == 0 && badge.contains('会员');
  if (isVipCatalogBadge && vipEntitlement == PgcVipEntitlement.unrestricted) {
    return null;
  }
  return badge;
}

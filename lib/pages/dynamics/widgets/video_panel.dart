// 视频or合集
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/badge.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/utils/utils.dart';

import '../../../common/widgets/my_dialog.dart';
import '../../../common/widgets/overlay_pop.dart';
import 'additional_panel.dart';
import 'rich_node_panel.dart';

Widget videoSeasonWidget(
  item,
  context,
  type,
  source, {
  floor = 1,
  String? heroTag,
}) {
  TextStyle authorStyle = TextStyle(
    color: Theme.of(context).colorScheme.primary,
  );
  // type archive  ugcSeason
  // archive 视频/显示发布人
  // ugcSeason 合集/不显示发布人

  // floor 1 2
  // 1 投稿视频 铺满 borderRadius 0
  // 2 转发视频 铺满 borderRadius 6
  Map<dynamic, dynamic> dynamicProperty = {
    'ugcSeason': item.modules.moduleDynamic.major.ugcSeason,
    'archive': item.modules.moduleDynamic.major.archive,
    'pgc': item.modules.moduleDynamic.major.pgc,
  };
  dynamic content = dynamicProperty[type];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      if (floor == 2) ...[
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: item.modules.moduleAuthor.type == null
                    ? '@${item.modules.moduleAuthor.name}'
                    : item.modules.moduleAuthor.name,
                style: authorStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => Get.toNamed(
                    '/member?mid=${item.modules.moduleAuthor.mid}',
                    arguments: {'face': item.modules.moduleAuthor.face},
                  ),
              ),
              const WidgetSpan(child: SizedBox(width: 6)),
              TextSpan(
                text: item.modules.moduleAuthor.pubTs != null
                    ? Utils.dateFormat(item.modules.moduleAuthor.pubTs)
                    : item.modules.moduleAuthor.pubTime,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: Theme.of(context).textTheme.labelSmall!.fontSize,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
      ],
      // const SizedBox(height: 4),
      /// fix #话题跟content重复
      // if (item.modules.moduleDynamic.topic != null) ...[
      //   Padding(
      //     padding: floor == 2
      //         ? EdgeInsets.zero
      //         : const EdgeInsets.only(left: 12, right: 12),
      //     child: GestureDetector(
      //       child: Text(
      //         '#${item.modules.moduleDynamic.topic.name}',
      //         style: authorStyle,
      //       ),
      //     ),
      //   ),
      //   const SizedBox(height: 6),
      // ],
      if (floor == 2 && item.modules.moduleDynamic.desc != null) ...[
        Text.rich(
          richNode(item, context)!,
          maxLines: source == 'detail' ? 999 : 6,
          overflow: TextOverflow.fade,
        ),
        const SizedBox(height: 6),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: StyleString.safeSpace),
        child: LayoutBuilder(
          builder: (context, box) {
            double width = box.maxWidth;
            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () {
                    // 弹窗显示封面
                    MyDialog.show(context, OverlayPop(videoItem: content));
                  },
                  child: Hero(
                    tag: heroTag ?? _getHeroTag(item, content.bvid),
                    child: NetworkImgLayer(
                      type: null,
                      width: width,
                      height: width / StyleString.aspectRatio,
                      src: content.cover,
                      semanticsLabel: content.title,
                    ),
                  ),
                ),
                if (content.badge != null && type == 'pgc')
                  PBadge(
                    text: content.badge['text'],
                    top: 8.0,
                    right: 10.0,
                    bottom: null,
                    left: null,
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Colors.transparent, Colors.black54],
                      ),
                      borderRadius: BorderRadius.circular(
                        StyleString.imgRadius.x,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: Theme.of(
                              context,
                            ).textTheme.labelMedium!.fontSize,
                            color: Colors.white,
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (content.durationText != null) ...[
                                  TextSpan(
                                    text: content.durationText,
                                    semanticsLabel:
                                        '时长${Utils.durationReadFormat(content.durationText)}',
                                  ),
                                  const WidgetSpan(child: SizedBox(width: 6)),
                                ],
                                TextSpan(text: '${content.stat.play}次围观'),
                                const WidgetSpan(child: SizedBox(width: 6)),
                                TextSpan(text: '${content.stat.danmu}条弹幕'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Image.asset(
                          'assets/images/play.png',
                          width: 50,
                          height: 50,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: floor == 1
            ? const EdgeInsets.only(left: 12, right: 12)
            : EdgeInsets.zero,
        child: Text(
          content.title,
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (item?.modules?.moduleDynamic?.additional != null)
        addWidget(
          item,
          context,
          item.modules.moduleDynamic.additional.type,
          floor: floor,
        ),
    ],
  );
}

String _getHeroTag(dynamic item, String? bvid) {
  try {
    if (item.idStr != null) {
      return '${item.idStr}-$bvid';
    }
  } catch (_) {}
  return Utils.makeHeroTag(bvid);
}

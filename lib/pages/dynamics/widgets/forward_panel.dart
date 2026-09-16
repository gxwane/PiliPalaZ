// 转发
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/utils/utils.dart';

import '../../../common/widgets/badge.dart';
import '../../../common/widgets/hero_tag_generator.dart';
import '../../../common/widgets/network_img_layer.dart';
import '../../../models/dynamics/result.dart';
import '../../preview/view.dart';
import 'additional_panel.dart';
import 'article_panel.dart';
import 'live_panel.dart';
import 'live_rcmd_panel.dart';
import 'pic_panel.dart';
import 'rich_node_panel.dart';
import 'video_panel.dart';

InlineSpan picsNodes(List<OpusPicsModel> pics) {
  List<InlineSpan> spanChildren = [];
  int len = pics.length;
  List<String> picList = [];

  if (len == 1) {
    OpusPicsModel pictureItem = pics.first;
    picList.add(pictureItem.url!);

    /// 图片上方的空白间隔
    // spanChildren.add(const TextSpan(text: '\n'));
    spanChildren.add(
      WidgetSpan(
        child: LayoutBuilder(
          builder: (context, BoxConstraints box) {
            double maxWidth = box.maxWidth.truncateToDouble();
            double maxHeight = box.maxWidth * 0.6; // 设置最大高度
            double height =
                maxWidth *
                0.5 *
                (pictureItem.height != null && pictureItem.width != null
                    ? pictureItem.height! / pictureItem.width!
                    : 1);
            return Semantics(
              label: '图片1,共1张',
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    useSafeArea: false,
                    context: context,
                    builder: (context) {
                      return ImagePreview(initialPage: 0, imgList: picList);
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.only(top: 4),
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  width: box.maxWidth / 2,
                  height: height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: NetworkImgLayer(
                          src: pictureItem.url,
                          width: maxWidth / 2,
                          height: height,
                        ),
                      ),
                      height > Get.size.height * 0.9
                          ? const PBadge(text: '长图', right: 8, bottom: 8)
                          : const SizedBox(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  if (len > 1) {
    List<Widget> list = [];
    for (var i = 0; i < len; i++) {
      picList.add(pics[i].url!);
      list.add(
        LayoutBuilder(
          builder: (context, BoxConstraints box) {
            double maxWidth = box.maxWidth.truncateToDouble();
            return Semantics(
              label: '图片${i + 1},共$len张',
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    useSafeArea: false,
                    context: context,
                    builder: (context) {
                      return ImagePreview(initialPage: i, imgList: picList);
                    },
                  );
                },
                child: NetworkImgLayer(
                  src: pics[i].url,
                  width: maxWidth,
                  height: maxWidth,
                  origAspectRatio:
                      pics[i].width!.toInt() / pics[i].height!.toInt(),
                ),
              ),
            );
          },
        ),
      );
    }
    spanChildren.add(
      WidgetSpan(
        child: LayoutBuilder(
          builder: (context, BoxConstraints box) {
            double maxWidth = box.maxWidth.truncateToDouble();
            double crossCount = len < 3 ? 2 : 3;
            double height =
                maxWidth /
                    crossCount *
                    (len % crossCount == 0
                        ? len ~/ crossCount
                        : len ~/ crossCount + 1) +
                6;
            return Container(
              padding: const EdgeInsets.only(top: 6),
              height: height,
              child: GridView.count(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossCount.toInt(),
                mainAxisSpacing: 4.0,
                crossAxisSpacing: 4.0,
                childAspectRatio: 1,
                children: list,
              ),
            );
          },
        ),
      ),
    );
  }
  return TextSpan(children: spanChildren);
}

Widget forWard(item, context, ctr, source, {floor = 1, String? heroTag}) {
  TextStyle authorStyle = TextStyle(
    color: Theme.of(context).colorScheme.primary,
  );

  List<OpusPicsModel> pics = [];

  bool hasPics =
      item.modules.moduleDynamic.major != null &&
      item.modules.moduleDynamic.major.opus != null &&
      item.modules.moduleDynamic.major.opus.pics.isNotEmpty;
  if (hasPics) {
    pics = item.modules.moduleDynamic.major.opus.pics;
  }
  InlineSpan? richNodes = richNode(item, context);
  // print(item.type);
  switch (item.type) {
    // 图文
    case 'DYNAMIC_TYPE_DRAW':
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (floor == 2) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '@${item.modules.moduleAuthor.name}',
                    style: authorStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Get.toNamed(
                        '/member?mid=${item.modules.moduleAuthor.mid}',
                        arguments: {'face': item.modules.moduleAuthor.face},
                      ),
                  ),
                  const WidgetSpan(child: SizedBox(width: 6)),
                  TextSpan(
                    text: Utils.dateFormat(item.modules.moduleAuthor.pubTs),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: Theme.of(
                        context,
                      ).textTheme.labelSmall!.fontSize,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

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
            // ],
            if (richNodes != null)
              Text.rich(
                richNodes,
                // 被转发状态(floor=2) 隐藏
                maxLines: source == 'detail' && floor != 2 ? 999 : 6,
                overflow: TextOverflow.fade,
              ),
            if (hasPics) ...[
              Text.rich(
                picsNodes(pics),
                // semanticsLabel: '动态图片',
              ),
            ],
            const SizedBox(height: 4),
          ],
          Padding(
            padding: floor == 2
                ? EdgeInsets.zero
                : const EdgeInsets.only(left: 12, right: 12),
            child: picWidget(item, context),
          ),

          /// 附加内容 商品信息、直播预约等等
          if (item.modules.moduleDynamic.additional != null)
            addWidget(
              item,
              context,
              item.modules.moduleDynamic.additional.type,
              floor: floor,
            ),
        ],
      );
    // 视频
    case 'DYNAMIC_TYPE_AV':
      return videoSeasonWidget(
        item,
        context,
        'archive',
        source,
        floor: floor,
        heroTag: heroTag,
      );
    // 文章
    case 'DYNAMIC_TYPE_ARTICLE':
      return Container(
        padding: const EdgeInsets.only(
          left: 10,
          top: 12,
          right: 10,
          bottom: 10,
        ),
        color: Theme.of(context).dividerColor.withOpacity(0.08),
        child: articlePanel(item, context, floor: floor),
      );
    // 转发
    case 'DYNAMIC_TYPE_FORWARD':
      return HeroTagGenerator(
        builder: (context, innerHeroTag) {
          return InkWell(
            onTap: () =>
                ctr.pushDetail(item.orig, floor + 1, heroTag: innerHeroTag),
            child: Container(
              padding: const EdgeInsets.only(
                left: 15,
                top: 10,
                right: 15,
                bottom: 8,
              ),
              color: Theme.of(context).dividerColor.withOpacity(0.08),
              child: forWard(
                item.orig,
                context,
                ctr,
                source,
                floor: floor + 1,
                heroTag: innerHeroTag,
              ),
            ),
          );
        },
      );
    // 直播
    case 'DYNAMIC_TYPE_LIVE_RCMD':
      return liveRcmdPanel(item, context, floor: floor, heroTag: heroTag);
    // 直播
    case 'DYNAMIC_TYPE_LIVE':
      return livePanel(item, context, floor: floor);
    // 合集
    case 'DYNAMIC_TYPE_UGC_SEASON':
      return videoSeasonWidget(
        item,
        context,
        'ugcSeason',
        source,
        heroTag: heroTag,
      );
    case 'DYNAMIC_TYPE_WORD':
      InlineSpan? richNodes = richNode(item, context);
      return floor == 2
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '@${item.modules.moduleAuthor.name}',
                        style: authorStyle,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Get.toNamed(
                            '/member?mid=${item.modules.moduleAuthor.mid}',
                            arguments: {'face': item.modules.moduleAuthor.face},
                          ),
                      ),
                      const WidgetSpan(child: SizedBox(width: 6)),
                      TextSpan(
                        text: Utils.dateFormat(item.modules.moduleAuthor.pubTs),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: Theme.of(
                            context,
                          ).textTheme.labelSmall!.fontSize,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (richNodes != null)
                  Text.rich(
                    richNodes,
                    // 被转发状态(floor=2) 隐藏
                    maxLines: source == 'detail' && floor != 2 ? 999 : 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.modules?.moduleDynamic?.additional != null)
                  addWidget(
                    item,
                    context,
                    item.modules.moduleDynamic.additional.type,
                    floor: floor,
                  ),
              ],
            )
          : item.modules.moduleDynamic.additional != null
          ? addWidget(
              item,
              context,
              item.modules.moduleDynamic.additional.type,
              floor: floor,
            )
          : const SizedBox(height: 0);
    case 'DYNAMIC_TYPE_PGC':
      return videoSeasonWidget(
        item,
        context,
        'pgc',
        source,
        floor: floor,
        heroTag: heroTag,
      );
    case 'DYNAMIC_TYPE_PGC_UNION':
      return videoSeasonWidget(
        item,
        context,
        'pgc',
        source,
        floor: floor,
        heroTag: heroTag,
      );
    // 直播结束
    case 'DYNAMIC_TYPE_NONE':
      return Row(
        children: [
          const FaIcon(FontAwesomeIcons.ghost, size: 14),
          const SizedBox(width: 4),
          Text(item.modules.moduleDynamic.major.none.tips),
        ],
      );
    // 课堂
    case 'DYNAMIC_TYPE_COURSES_SEASON':
      return Row(
        children: [
          Expanded(
            child: Text(
              "课堂💪：${item.modules.moduleDynamic.major.courses['title']}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    case 'DYNAMIC_TYPE_COMMON_SQUARE':
      debugPrint('commonSquare: ${item.modules.moduleDynamic.major}');
      return GestureDetector(
        onTap: () => Get.toNamed(
          '/webview',
          parameters: {
            'url': item.modules.moduleDynamic.major.common.jumpUrl,
            'type': 'url',
            'pageTitle': item.modules.moduleDynamic.major.common.title ?? "",
          },
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            NetworkImgLayer(
              src: item.modules.moduleDynamic.major.common.cover ?? "",
              width: 50,
              height: 50,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.modules.moduleDynamic.major.common.title ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    item.modules.moduleDynamic.major.common.desc ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    default:
      return const SizedBox(
        width: double.infinity,
        child: Text('🙏 暂未支持的类型，请联系开发者反馈 '),
      );
  }
}

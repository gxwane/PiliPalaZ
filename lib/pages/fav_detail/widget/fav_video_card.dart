import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/stat/danmu.dart';
import 'package:pilipalaz/common/widgets/stat/view.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/services/pgc_playback_coordinator.dart';
import 'package:pilipalaz/utils/id_utils.dart';
import 'package:pilipalaz/utils/utils.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import '../../../common/widgets/badge.dart';

// 收藏视频卡片 - 水平布局
class FavVideoCardH extends StatelessWidget {
  final dynamic videoItem;
  final Function? callFn;
  final int? searchType;

  const FavVideoCardH({
    super.key,
    required this.videoItem,
    this.callFn,
    this.searchType,
  });

  @override
  Widget build(BuildContext context) {
    int id = videoItem.id;
    String bvid = videoItem.bvid ?? IdUtils.av2bv(id);
    String heroTag = Utils.makeHeroTag(id);
    return InkWell(
      onTap: () async {
        if (videoItem.ogv != null) {
          await PgcPlaybackCoordinator.open(
            seasonId: videoItem.ogv['season_id'],
            epId: int.tryParse(videoItem.epId?.toString() ?? ''),
            pic: videoItem.pic,
            heroTag: heroTag,
          );
          return;
        }
        String? epId;
        if (videoItem.page == 0 || videoItem.page > 1) {
          var result = await VideoHttp.videoIntro(bvid: bvid);
          if (result['status']) {
            epId = result['data'].epId?.toString();
          } else {
            SmartDialog.showToast(result['msg']);
          }
        }

        Map<String, String> parameters = {
          'bvid': bvid,
          'cid': videoItem.cid.toString(),
          'epId': epId ?? '',
        };
        // if (seasonId != null) {
        //   parameters['seasonId'] = seasonId.toString();
        // }
        Get.toNamed(
          '/video',
          parameters: parameters,
          arguments: {'videoItem': videoItem, 'heroTag': heroTag},
        );
      },
      child: LayoutBuilder(
        builder: (context, boxConstraints) {
          double width =
              (boxConstraints.maxWidth - StyleString.cardSpace * 6) / 2;
          return SizedBox(
            height: width / StyleString.aspectRatio,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: StyleString.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) {
                      double maxWidth = boxConstraints.maxWidth;
                      double maxHeight = boxConstraints.maxHeight;
                      return Stack(
                        children: [
                          Hero(
                            tag: heroTag,
                            child: NetworkImgLayer(
                              src: videoItem.pic,
                              width: maxWidth,
                              height: maxHeight,
                            ),
                          ),
                          PBadge(
                            text: Utils.timeFormat(videoItem.duration!),
                            right: 6.0,
                            bottom: 6.0,
                            type: 'gray',
                          ),
                          if (videoItem.ogv != null) ...[
                            PBadge(
                              text: videoItem.ogv['type_name'],
                              top: 6.0,
                              right: 6.0,
                              bottom: null,
                              left: null,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                VideoContent(
                  videoItem: videoItem,
                  callFn: callFn,
                  searchType: searchType,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VideoContent extends StatelessWidget {
  final dynamic videoItem;
  final Function? callFn;
  final int? searchType;
  const VideoContent({
    super.key,
    required this.videoItem,
    this.callFn,
    this.searchType,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 6, 0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  videoItem.title,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (videoItem.ogv != null) ...[
                  Text(
                    videoItem.intro,
                    style: TextStyle(
                      fontSize: Theme.of(
                        context,
                      ).textTheme.labelMedium!.fontSize,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  "${Utils.dateFormat(videoItem.pubdate!, formatType: 'day')} ${videoItem.owner.name}",
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      StatView(theme: 'gray', view: videoItem.cntInfo['play']),
                      const SizedBox(width: 8),
                      StatDanMu(
                        theme: 'gray',
                        danmu: videoItem.cntInfo['danmaku'],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
            if (searchType != 1)
              Positioned(
                right: 0,
                bottom: -6,
                width: 28,
                height: 28,
                child: IconButton(
                  tooltip: '取消收藏',
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    showDialog(
                      context: Get.context!,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('提示'),
                          content: const Text('要取消收藏吗?'),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: Text(
                                '取消',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await callFn!();
                                Get.back();
                              },
                              child: const Text('确定取消'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: Icon(
                    Icons.clear_outlined,
                    color: Theme.of(context).colorScheme.outline,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

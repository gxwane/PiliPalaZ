import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/badge.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/common/widgets/stat/view.dart';
import 'package:pilipalaz/http/search.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/utils/utils.dart';

class MemberSeriesItem extends StatelessWidget {
  final dynamic seriesItem;

  const MemberSeriesItem({
    super.key,
    required this.seriesItem,
  });

  @override
  Widget build(BuildContext context) {
    String heroTag = Utils.makeHeroTag(seriesItem.aid);
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          final cidResult = await SearchHttp.ab2c(
            aid: seriesItem.aid,
            bvid: seriesItem.bvid,
          );
          if (cidResult case ApiFailure<int>(:final message)) {
            SmartDialog.showToast(message);
            return;
          }
          final cid = (cidResult as ApiSuccess<int>).data;
          Get.toNamed('/video?bvid=${seriesItem.bvid}&cid=$cid',
              arguments: {'videoItem': seriesItem, 'heroTag': heroTag});
        },
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: StyleString.aspectRatio,
              child: LayoutBuilder(builder: (context, boxConstraints) {
                double maxWidth = boxConstraints.maxWidth;
                double maxHeight = boxConstraints.maxHeight;
                return Stack(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: NetworkImgLayer(
                        src: seriesItem.pic,
                        width: maxWidth,
                        height: maxHeight,
                      ),
                    ),
                    if (seriesItem.pubdate != null)
                      PBadge(
                        bottom: 6,
                        right: 6,
                        type: 'gray',
                        text: Utils.CustomStamp_str(
                            timestamp: seriesItem.pubdate, date: 'YY-MM-DD'),
                      )
                  ],
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 6, 0, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seriesItem.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatView(
                        view: seriesItem.view,
                        theme: 'gray',
                      ),
                      const Spacer(),
                      Text(
                        Utils.CustomStamp_str(
                            timestamp: seriesItem.pubdate, date: 'YY-MM-DD'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 6)
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

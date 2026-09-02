import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/skeleton/video_card_h.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/common/widgets/video_card_h.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/model_hot_video_item.dart';
import '../../../../common/constants.dart';
import '../../../../utils/grid.dart';
import 'controller.dart';

class RelatedVideoPanel extends StatefulWidget {
  const RelatedVideoPanel({super.key, required this.heroTag});
  final String heroTag;
  @override
  State<RelatedVideoPanel> createState() => _RelatedVideoPanelState();
}

class _RelatedVideoPanelState extends State<RelatedVideoPanel>
    with AutomaticKeepAliveClientMixin {
  late RelatedController _relatedController;
  late Future<ApiResult<List<HotVideoItemModel>>> _futureBuilder;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _relatedController = Get.put(RelatedController(), tag: widget.heroTag);
    _futureBuilder = _relatedController.queryRelatedVideo();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SliverPadding(
      padding: const EdgeInsets.all(StyleString.safeSpace),
      sliver: FutureBuilder<ApiResult<List<HotVideoItemModel>>>(
        future: _futureBuilder,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<ApiResult<List<HotVideoItemModel>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.data == null) {
                  return const SliverToBoxAdapter(child: SizedBox());
                }
                final result = snapshot.data!;
                if (result is ApiSuccess<List<HotVideoItemModel>>) {
                  RxList relatedVideoList = _relatedController.relatedVideoList;
                  // 请求成功
                  return Obx(
                    () => SliverGrid(
                      gridDelegate: SliverGridDelegateWithExtentAndRatio(
                        mainAxisSpacing: StyleString.safeSpace,
                        crossAxisSpacing: StyleString.safeSpace,
                        maxCrossAxisExtent: Grid.maxRowWidth * 2,
                        childAspectRatio: StyleString.aspectRatio * 2.4,
                        mainAxisExtent: 0,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index == relatedVideoList.length) {
                          return SizedBox(
                            height: MediaQuery.of(context).padding.bottom,
                          );
                        } else {
                          return Material(
                            child: VideoCardH(
                              videoItem: relatedVideoList[index],
                              showPubdate: true,
                            ),
                          );
                        }
                      }, childCount: relatedVideoList.length + 1),
                    ),
                  );
                } else {
                  // 请求错误
                  return HttpError(
                    errMsg:
                        (result as ApiFailure<List<HotVideoItemModel>>).message,
                    fn: () {
                      setState(() {
                        _futureBuilder = _relatedController.queryRelatedVideo();
                      });
                    },
                  );
                }
              } else {
                // 骨架屏
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithExtentAndRatio(
                    mainAxisSpacing: StyleString.safeSpace,
                    crossAxisSpacing: StyleString.safeSpace,
                    maxCrossAxisExtent: Grid.maxRowWidth * 2,
                    childAspectRatio: StyleString.aspectRatio * 2.4,
                    mainAxisExtent: 0,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return const VideoCardHSkeleton();
                  }, childCount: 5),
                );
              }
            },
      ),
    );
  }
}

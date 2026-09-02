import 'dart:async';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/skeleton/video_card_v.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/pages/home/index.dart';
import 'package:pilipalaz/pages/main/index.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/live/item.dart';

import '../../utils/grid.dart';
import 'controller.dart';
import 'widgets/live_item.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage>
    with AutomaticKeepAliveClientMixin {
  final LiveController _liveController = Get.put(LiveController());
  late Future<ApiResult<List<LiveItemModel>>> _futureBuilderFuture;
  late ScrollController scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = _liveController.queryLiveList('init');
    scrollController = _liveController.scrollController;
    StreamController<bool> mainStream =
        Get.find<MainController>().bottomBarStream;
    StreamController<bool> searchBarStream =
        Get.find<HomeController>().searchBarStream;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          EasyThrottle.throttle('liveList', const Duration(milliseconds: 200),
              () {
            _liveController.onLoad();
          });
        }

        final ScrollDirection direction =
            scrollController.position.userScrollDirection;
        if (direction == ScrollDirection.forward) {
          mainStream.add(true);
          searchBarStream.add(true);
        } else if (direction == ScrollDirection.reverse) {
          mainStream.add(false);
          searchBarStream.add(false);
        }
      },
    );
  }

  @override
  void dispose() {
    scrollController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.only(
          left: StyleString.cardSpace, right: StyleString.cardSpace),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(StyleString.imgRadius),
      ),
      child: RefreshIndicator(
        displacement: 10.0,
        edgeOffset: 10.0,
        onRefresh: () async {
          return await _liveController.onRefresh();
        },
        child: CustomScrollView(
          cacheExtent: 3500,
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _liveController.scrollController,
          slivers: [
            SliverPadding(
              // 单列布局 EdgeInsets.zero
              padding:
                  const EdgeInsets.fromLTRB(0, StyleString.cardSpace, 0, 0),
              sliver: FutureBuilder<ApiResult<List<LiveItemModel>>>(
                future: _futureBuilderFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.data == null) {
                      return const SliverToBoxAdapter(child: SizedBox());
                    }
                    final result = snapshot.data;
                    if (result is ApiSuccess<List<LiveItemModel>>) {
                      return SliverLayoutBuilder(
                          builder: (context, boxConstraints) {
                        return Obx(() => contentGrid(
                            _liveController, _liveController.liveList));
                      });
                    } else {
                      return HttpError(
                        errMsg:
                            (result as ApiFailure<List<LiveItemModel>>).message,
                        fn: () {
                          setState(() {
                            _futureBuilderFuture =
                                _liveController.queryLiveList('init');
                          });
                        },
                      );
                    }
                  } else {
                    return contentGrid(_liveController, []);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget contentGrid(ctr, liveList) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithExtentAndRatio(
        mainAxisSpacing: StyleString.cardSpace,
        crossAxisSpacing: StyleString.cardSpace,
        maxCrossAxisExtent: Grid.maxRowWidth,
        childAspectRatio: StyleString.aspectRatio,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(80),
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return liveList!.isNotEmpty
              ? LiveCardV(liveItem: liveList[index])
              : const VideoCardVSkeleton();
        },
        childCount: liveList!.isNotEmpty ? liveList!.length : 10,
      ),
    );
  }
}

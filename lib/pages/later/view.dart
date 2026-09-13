import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/common/skeleton/video_card_h.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/common/widgets/no_data.dart';
import 'package:pilipalaz/common/widgets/video_card_h.dart';
import 'package:pilipalaz/pages/later/index.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/search.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/utils/utils.dart';

import '../../common/constants.dart';
import '../../utils/grid.dart';

class LaterPage extends StatefulWidget {
  const LaterPage({super.key});

  @override
  State<LaterPage> createState() => _LaterPageState();
}

class _LaterPageState extends State<LaterPage> {
  final LaterController _laterController = Get.put(LaterController());
  Future<ApiResult<WatchLaterData>>? _futureBuilderFuture;

  @override
  void initState() {
    _futureBuilderFuture = _laterController.queryLaterList();
    super.initState();
  }

  Future<void> _playWatchLaterItem(int index) async {
    if (_laterController.laterList.isEmpty) return;
    final item = _laterController.laterList[index];
    final int? aid = item.aid;
    final String? bvid = item.bvid;
    if (aid == null || bvid == null || bvid.isEmpty) return;
    final String heroTag = Utils.makeHeroTag(aid);
    try {
      final cidResult = item.cid == null
          ? await SearchHttp.ab2c(aid: aid, bvid: bvid)
          : ApiSuccess<int>(item.cid as int);
      if (cidResult case ApiFailure<int>(:final message)) {
        SmartDialog.showToast(message);
        return;
      }
      final cid = (cidResult as ApiSuccess<int>).data;
      Get.toNamed(
        '/video?bvid=$bvid&cid=$cid',
        arguments: {
          'videoItem': item,
          'heroTag': heroTag,
          'watchLaterList': _laterController.laterList.toList(),
          'watchLaterIndex': index,
        },
      );
    } catch (err) {
      SmartDialog.showToast(err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Obx(
          () => _laterController.laterList.isNotEmpty
              ? Text(
                  '稍后再看 (${_laterController.laterList.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                )
              : Text('稍后再看', style: Theme.of(context).textTheme.titleMedium),
        ),
        actions: [
          Obx(
            () => _laterController.laterList.isNotEmpty
                ? TextButton.icon(
                    onPressed: () => _playWatchLaterItem(0),
                    icon: const Icon(Icons.play_circle_outline, size: 20),
                    label: const Text('播放全部'),
                  )
                : const SizedBox(),
          ),
          Obx(
            () => _laterController.laterList.isNotEmpty
                ? TextButton(
                    onPressed: () => _laterController.toViewDel(context),
                    child: const Text('移除已看'),
                  )
                : const SizedBox(),
          ),
          Obx(
            () => _laterController.laterList.isNotEmpty
                ? IconButton(
                    tooltip: '一键清空',
                    onPressed: () => _laterController.toViewClear(context),
                    icon: Icon(
                      Icons.clear_all_outlined,
                      size: 21,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        cacheExtent: 3500,
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _laterController.scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: StyleString.safeSpace,
            ),
            sliver: FutureBuilder<ApiResult<WatchLaterData>>(
              future: _futureBuilderFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  final result = snapshot.data;
                  if (result is ApiSuccess<WatchLaterData>) {
                    return Obx(
                      () =>
                          _laterController.laterList.isNotEmpty &&
                              !_laterController.isLoading.value
                          ? SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithExtentAndRatio(
                                    mainAxisSpacing: StyleString.safeSpace,
                                    crossAxisSpacing: StyleString.safeSpace,
                                    maxCrossAxisExtent: Grid.maxRowWidth * 2,
                                    childAspectRatio:
                                        StyleString.aspectRatio * 2.4,
                                    mainAxisExtent: 0,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                var videoItem =
                                    _laterController.laterList[index];
                                return VideoCardH(
                                  videoItem: videoItem,
                                  source: 'later',
                                  onTap: () => _playWatchLaterItem(index),
                                  longPress: () => _laterController.toViewDel(
                                    context,
                                    aid: videoItem.aid,
                                  ),
                                );
                              }, childCount: _laterController.laterList.length),
                            )
                          : _laterController.isLoading.value
                          ? const SliverToBoxAdapter(
                              child: Center(child: Text('加载中')),
                            )
                          : const NoData(),
                    );
                  } else {
                    return HttpError(
                      errMsg:
                          (result as ApiFailure<WatchLaterData>?)?.message ??
                          '稍后再看加载失败',
                      fn: () => setState(() {
                        _futureBuilderFuture = _laterController
                            .queryLaterList();
                      }),
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
                    }, childCount: 10),
                  );
                }
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
          ),
        ],
      ),
    );
  }
}

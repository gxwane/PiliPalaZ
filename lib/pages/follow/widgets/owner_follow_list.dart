import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/common/widgets/no_data.dart';
import 'package:pilipalaz/http/member.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/follow/result.dart';
import 'package:pilipalaz/models/member/tags.dart';
import 'package:pilipalaz/pages/follow/index.dart';
import 'follow_item.dart';

class OwnerFollowList extends StatefulWidget {
  final FollowController ctr;
  final MemberTagItemModel? tagItem;
  const OwnerFollowList({super.key, required this.ctr, this.tagItem});

  @override
  State<OwnerFollowList> createState() => _OwnerFollowListState();
}

class _OwnerFollowListState extends State<OwnerFollowList>
    with AutomaticKeepAliveClientMixin {
  late int? mid;
  late Future<ApiResult<List<FollowItemModel>>> _futureBuilderFuture;
  final ScrollController scrollController = ScrollController();
  int pn = 1;
  int ps = 20;
  late MemberTagItemModel tagItem;
  RxList<FollowItemModel> followList = <FollowItemModel>[].obs;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    mid = widget.ctr.mid;
    tagItem = widget.tagItem!;
    _futureBuilderFuture = followUpGroup('init');
    scrollController.addListener(() async {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        EasyThrottle.throttle('follow', const Duration(seconds: 1), () {
          followUpGroup('onLoad');
        });
      }
    });
  }

  // 获取分组下up
  Future<ApiResult<List<FollowItemModel>>> followUpGroup(String type) async {
    if (type == 'init') {
      pn = 1;
    }
    var res = await MemberHttp.followUpGroup(mid, tagItem.tagid, pn, ps);
    if (res case ApiSuccess<List<FollowItemModel>>(:final data)) {
      if (data.isNotEmpty) {
        if (type == 'init') {
          followList.value = data;
        } else {
          followList.addAll(data);
        }
        pn += 1;
      }
    }
    return res;
  }

  @override
  void dispose() {
    scrollController.removeListener(() {});
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      displacement: 10.0,
      edgeOffset: 10.0,
      onRefresh: () async => await followUpGroup('init'),
      child: FutureBuilder(
        future: _futureBuilderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final result = snapshot.data;
            if (result is ApiSuccess<List<FollowItemModel>>) {
              return Obx(
                () => followList.isNotEmpty
                    ? ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: scrollController,
                        itemCount: followList.length + 1,
                        itemBuilder: (BuildContext context, int index) {
                          if (index == followList.length) {
                            return Container(
                              height:
                                  MediaQuery.of(context).padding.bottom + 60,
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).padding.bottom,
                              ),
                            );
                          } else {
                            return FollowItem(
                              item: followList[index],
                              ctr: widget.ctr,
                            );
                          }
                        },
                      )
                    : const CustomScrollView(slivers: [NoData()]),
              );
            } else {
              return CustomScrollView(
                slivers: [
                  HttpError(
                    errMsg: result is ApiFailure<List<FollowItemModel>>
                        ? result.message
                        : '关注分组加载失败',
                    fn: () => widget.ctr.queryFollowings('init'),
                  ),
                ],
              );
            }
          } else {
            // 骨架屏
            return const SizedBox();
          }
        },
      ),
    );
  }
}

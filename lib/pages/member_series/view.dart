import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/member/seasons.dart';
import '../../utils/grid.dart';
import 'controller.dart';
import 'widgets/item.dart';

class MemberSeriesPage extends StatefulWidget {
  const MemberSeriesPage({super.key});

  @override
  State<MemberSeriesPage> createState() => _MemberSeriesPageState();
}

class _MemberSeriesPageState extends State<MemberSeriesPage> {
  final MemberSeriesController _memberSeriesController = Get.put(
    MemberSeriesController(),
  );
  late Future<ApiResult<MemberSeriesList>> _futureBuilderFuture;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = _memberSeriesController.getSeriesDetail('init');
    scrollController = _memberSeriesController.scrollController;
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        EasyThrottle.throttle(
          'member_archives',
          const Duration(milliseconds: 500),
          () {
            _memberSeriesController.onLoad();
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Obx(
          () => Text(
            'Ta的视频合集(${_memberSeriesController.page.value?["total"]})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // title: Text('Ta的专栏', style: Theme.of(context).textTheme.titleMedium),
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          left: StyleString.safeSpace,
          right: StyleString.safeSpace,
        ),
        child: SingleChildScrollView(
          controller: _memberSeriesController.scrollController,
          child: FutureBuilder<ApiResult<MemberSeriesList>>(
            future: _futureBuilderFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.data != null) {
                  final result = snapshot.data!;
                  List list = _memberSeriesController.seriesList;
                  if (result is ApiSuccess<MemberSeriesList>) {
                    return Obx(
                      () => list.isNotEmpty
                          ? LayoutBuilder(
                              builder: (context, boxConstraints) {
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithExtentAndRatio(
                                        mainAxisSpacing: StyleString.cardSpace,
                                        crossAxisSpacing: StyleString.cardSpace,
                                        maxCrossAxisExtent: Grid.maxRowWidth,
                                        childAspectRatio: 0.94,
                                        mainAxisExtent: 0,
                                      ),
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount:
                                      _memberSeriesController.seriesList.length,
                                  itemBuilder: (context, i) {
                                    return MemberSeriesItem(
                                      seriesItem:
                                          _memberSeriesController.seriesList[i],
                                    );
                                  },
                                );
                              },
                            )
                          : const Text('暂无数据'),
                    );
                  } else {
                    return Text(
                      (result as ApiFailure<MemberSeriesList>).message,
                    );
                  }
                } else {
                  return const Text('返回异常');
                }
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }
}

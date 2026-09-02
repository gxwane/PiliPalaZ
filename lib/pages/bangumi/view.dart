import 'dart:async';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/bangumi/list.dart';
import 'package:pilipalaz/models/common/pgc_type.dart';
import 'package:pilipalaz/pages/home/index.dart';
import 'package:pilipalaz/pages/main/index.dart';
import 'package:pilipalaz/services/pgc_playback_coordinator.dart';

import 'controller.dart';
import 'widgets/bangumi_card_v.dart';
import 'widgets/pgc_center_sections.dart';

class BangumiPage extends StatefulWidget {
  const BangumiPage({super.key});

  @override
  State<BangumiPage> createState() => _BangumiPageState();
}

class _BangumiPageState extends State<BangumiPage>
    with AutomaticKeepAliveClientMixin {
  final BangumiController _bangumiController = Get.put(BangumiController());
  late Future<ApiResult<BangumiListDataModel>> _catalogFuture;
  late Future<ApiResult<BangumiListDataModel>?> _followFuture;
  late final ScrollController scrollController;
  late final VoidCallback _scrollListener;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController = _bangumiController.scrollController;
    _catalogFuture = _bangumiController.queryBangumiListFeed();
    _followFuture = _bangumiController.queryBangumiFollow();
    _scrollListener = _handleScroll;
    scrollController.addListener(_scrollListener);
  }

  void _handleScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      EasyThrottle.throttle(
        'pgc-load-more',
        const Duration(seconds: 1),
        _bangumiController.onLoad,
      );
    }

    final StreamController<bool> mainStream =
        Get.find<MainController>().bottomBarStream;
    final StreamController<bool> searchBarStream =
        Get.find<HomeController>().searchBarStream;
    final ScrollDirection direction =
        scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.forward) {
      mainStream.add(true);
      searchBarStream.add(true);
    } else if (direction == ScrollDirection.reverse) {
      mainStream.add(false);
      searchBarStream.add(false);
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  Future<void> _refresh() async {
    final Future<ApiResult<BangumiListDataModel>> catalogFuture =
        _bangumiController.queryBangumiListFeed();
    final Future<ApiResult<BangumiListDataModel>?> followFuture =
        _bangumiController.queryBangumiFollow();
    setState(() {
      _catalogFuture = catalogFuture;
      _followFuture = followFuture;
    });
    await Future.wait<Object?>(<Future<Object?>>[catalogFuture, followFuture]);
  }

  Future<void> _selectCatalog(PgcCatalogType value) async {
    if (_bangumiController.catalogType.value == value) return;
    final PgcFollowGroup previousGroup =
        _bangumiController.catalogType.value.followGroup;
    await _bangumiController.selectCatalog(value);
    if (!mounted) return;

    final Future<ApiResult<BangumiListDataModel>> catalogFuture =
        _bangumiController.queryBangumiListFeed();
    final bool followGroupChanged = previousGroup != value.followGroup;
    final Future<ApiResult<BangumiListDataModel>?>? followFuture =
        followGroupChanged ? _bangumiController.queryBangumiFollow() : null;
    setState(() {
      _catalogFuture = catalogFuture;
      if (followFuture != null) _followFuture = followFuture;
    });
  }

  Future<void> _selectOrder(PgcCatalogOrder value) async {
    if (_bangumiController.catalogOrder.value == value) return;
    await _bangumiController.selectOrder(value);
    if (!mounted) return;
    setState(() {
      _catalogFuture = _bangumiController.queryBangumiListFeed();
    });
  }

  void _retryFollow() {
    setState(() {
      _followFuture = _bangumiController.queryBangumiFollow();
    });
  }

  void _retryCatalog() {
    setState(() {
      _catalogFuture = _bangumiController.queryBangumiListFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: <Widget>[
        Obx(
          () => PgcCategoryBar(
            selectedType: _bangumiController.catalogType.value,
            onSelected: _selectCatalog,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            displacement: 10,
            edgeOffset: 10,
            onRefresh: _refresh,
            child: CustomScrollView(
              cacheExtent: 3500,
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildContinueSection()),
                SliverToBoxAdapter(
                  child: Obx(
                    () => PgcCatalogSectionHeader(
                      title: '${_bangumiController.catalogType.value.label}精选',
                      selectedOrder: _bangumiController.catalogOrder.value,
                      followGroup:
                          _bangumiController.catalogType.value.followGroup,
                      onOrderSelected: _selectOrder,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: pgcPageHorizontalPadding,
                  ),
                  sliver: FutureBuilder<ApiResult<BangumiListDataModel>>(
                    future: _catalogFuture,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<ApiResult<BangumiListDataModel>>
                          snapshot,
                        ) {
                          final List<BangumiListItemModel> items =
                              _bangumiController.bangumiList.toList(
                                growable: false,
                              );
                          final bool waiting =
                              snapshot.connectionState != ConnectionState.done;
                          final result = snapshot.data;
                          if (!waiting &&
                              result is ApiFailure<BangumiListDataModel>) {
                            return HttpError(
                              errMsg: result.message,
                              fn: _retryCatalog,
                            );
                          }
                          return _contentGrid(items, refreshing: waiting);
                        },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueSection() {
    return Obx(() {
      if (!_bangumiController.userLogin.value) {
        return const SizedBox.shrink();
      }
      final PgcCatalogType catalogType = _bangumiController.catalogType.value;
      return FutureBuilder<ApiResult<BangumiListDataModel>?>(
        future: _followFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<ApiResult<BangumiListDataModel>?> snapshot,
            ) {
              final List<BangumiListItemModel> items = _bangumiController
                  .bangumiFollowList
                  .toList(growable: false);
              final bool waiting =
                  snapshot.connectionState != ConnectionState.done;
              String? errorMessage;
              final result = snapshot.data;
              if (!waiting && result is ApiFailure<BangumiListDataModel>) {
                errorMessage = result.message;
              }
              return PgcContinueSection(
                title: catalogType.continueSectionLabel,
                scopeLabel: catalogType.followGroup.continueScopeLabel,
                items: items,
                loading: waiting,
                errorMessage: errorMessage,
                onRetry: _retryFollow,
                onTap: (BangumiListItemModel item) {
                  PgcPlaybackCoordinator.open(
                    seasonId: item.seasonId,
                    pic: item.cover,
                  );
                },
              );
            },
      );
    });
  }

  Widget _contentGrid(
    List<BangumiListItemModel> items, {
    required bool refreshing,
  }) {
    final bool showSkeleton = items.isEmpty;
    const double crossAxisSpacing = 10;
    const double posterAspectRatio = 0.65;
    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final int crossAxisCount = pgcPosterColumnCount(viewportWidth);
    final double gridWidth = viewportWidth - pgcPageHorizontalPadding * 2;
    final double posterWidth =
        (gridWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisExtent:
            posterWidth / posterAspectRatio +
            MediaQuery.textScalerOf(context).scale(54),
      ),
      delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
        if (showSkeleton) return const PgcPosterSkeleton();
        return AnimatedOpacity(
          opacity: refreshing ? 0.45 : 1,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: refreshing,
            child: Obx(
              () => BangumiCardV(
                bangumiItem: items[index],
                vipEntitlement: _bangumiController.vipEntitlementFor(
                  items[index],
                ),
              ),
            ),
          ),
        );
      }, childCount: showSkeleton ? 9 : items.length),
    );
  }
}

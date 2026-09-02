import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/badge.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/pgc.dart';
import 'package:pilipalaz/common/widgets/stat/danmu.dart';
import 'package:pilipalaz/common/widgets/stat/view.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/pages/bangumi/widgets/bangumi_panel.dart';
import 'package:pilipalaz/pages/video/index.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/action_item.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/action_row_item.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/fav_panel.dart';
import 'package:pilipalaz/utils/feed_back.dart';

import 'package:pilipalaz/utils/utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../../../common/widgets/my_dialog.dart';
import 'controller.dart';
import '../widgets/bangumi_intro_detail.dart';

class BangumiIntroPanel extends StatefulWidget {
  final int? cid;
  final String heroTag;
  const BangumiIntroPanel({super.key, this.cid, required this.heroTag});

  @override
  State<BangumiIntroPanel> createState() => _BangumiIntroPanelState();
}

class _BangumiIntroPanelState extends State<BangumiIntroPanel>
    with AutomaticKeepAliveClientMixin {
  late BangumiIntroController bangumiIntroController;
  late VideoDetailController videoDetailCtr;
  BangumiInfoModel? bangumiDetail;
  late Future<ApiResult<PgcInfoBundle>> _futureBuilderFuture;
  late int cid;
  late String heroTag;

  // 添加页面缓存
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // heroTag = Get.arguments['heroTag'];
    heroTag = widget.heroTag;
    bangumiIntroController = Get.put(BangumiIntroController(), tag: heroTag);
    videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);
    cid = widget.cid ?? videoDetailCtr.cid.value;
    bangumiIntroController.bangumiDetail.listen((BangumiInfoModel value) {
      bangumiDetail = value;
    });
    _futureBuilderFuture = bangumiIntroController.queryBangumiIntro();
    videoDetailCtr.cid.listen((int p0) {
      cid = p0;
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<ApiResult<PgcInfoBundle>>(
      future: _futureBuilderFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<ApiResult<PgcInfoBundle>> snapshot,
          ) {
            if (snapshot.connectionState != ConnectionState.done) {
              return BangumiInfo(
                loadingStatus: true,
                bangumiDetail: bangumiDetail,
                cid: cid,
              );
            }
            final result = snapshot.data;
            if (result case ApiSuccess<PgcInfoBundle>(:final data)) {
              return BangumiInfo(
                loadingStatus: false,
                bangumiDetail: data.detail,
                cid: cid,
              );
            }
            final message = result is ApiFailure<PgcInfoBundle>
                ? result.message
                : '影视内容加载失败';
            return HttpError(
              errMsg: message,
              fn: () {
                setState(() {
                  _futureBuilderFuture = bangumiIntroController
                      .queryBangumiIntro();
                });
              },
            );
          },
    );
  }
}

class BangumiInfo extends StatefulWidget {
  const BangumiInfo({
    super.key,
    this.loadingStatus = false,
    this.bangumiDetail,
    this.cid,
  });

  final bool loadingStatus;
  final BangumiInfoModel? bangumiDetail;
  final int? cid;

  @override
  State<BangumiInfo> createState() => _BangumiInfoState();
}

class _BangumiInfoState extends State<BangumiInfo> {
  String heroTag = Get.arguments['heroTag'];
  late final BangumiIntroController bangumiIntroController;
  late final VideoDetailController videoDetailCtr;
  late final BangumiInfoModel? bangumiItem;
  int? cid;
  bool isProcessing = false;
  void Function()? handleState(Future Function() action) {
    return isProcessing
        ? null
        : () async {
            setState(() => isProcessing = true);
            try {
              await action();
            } finally {
              if (mounted) setState(() => isProcessing = false);
            }
          };
  }

  @override
  void initState() {
    super.initState();
    bangumiIntroController = Get.put(BangumiIntroController(), tag: heroTag);
    videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);
    bangumiItem = bangumiIntroController.bangumiItem;
    cid = widget.cid ?? videoDetailCtr.cid.value;
    videoDetailCtr.cid.listen((p0) {
      cid = p0;
      if (!mounted) return;
      setState(() {});
    });
  }

  // 收藏
  void showFavBottomSheet() {
    if (bangumiIntroController.userInfo?.mid == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FavPanel(ctr: bangumiIntroController);
      },
    );
  }

  // 视频介绍
  void showIntroDetail(BangumiInfoModel detail) {
    feedBack();
    MyDialog.showCorner(context, BangumiIntroDetail(bangumiDetail: detail));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final BangumiInfoModel? displayData = widget.loadingStatus
        ? bangumiItem
        : widget.bangumiDetail;
    final List<EpisodeItem> episodes =
        displayData?.episodes ?? const <EpisodeItem>[];
    return SliverPadding(
      padding: EdgeInsets.only(
        left: StyleString.safeSpace,
        right: StyleString.safeSpace,
        top: isLandscape ? 10 : 20,
      ),
      sliver: SliverToBoxAdapter(
        child: displayData != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          NetworkImgLayer(
                            width: isLandscape ? 160 : 105,
                            height: isLandscape ? 105 : 160,
                            src: displayData.cover ?? '',
                            semanticsLabel: '封面',
                          ),
                          if (displayData.rating?['score'] != null)
                            PBadge(
                              text: '评分 ${displayData.rating!['score']}',
                              top: null,
                              right: 6,
                              bottom: 6,
                              left: null,
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => showIntroDetail(displayData),
                          child: SizedBox(
                            height: isLandscape ? 103 : 158,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayData.title ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: Obx(
                                        () => PgcFollowButton(
                                          followed: bangumiIntroController
                                              .hasFollow
                                              .value,
                                          updating: bangumiIntroController
                                              .isFollowUpdating
                                              .value,
                                          actionLabel: bangumiIntroController
                                              .followActionLabel,
                                          onPressed: () =>
                                              bangumiIntroController
                                                  .toggleFollow(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    StatView(
                                      theme: 'gray',
                                      view: displayData.stat?['views'] ?? 0,
                                      size: 'medium',
                                    ),
                                    const SizedBox(width: 6),
                                    StatDanMu(
                                      theme: 'gray',
                                      danmu: displayData.stat?['danmakus'] ?? 0,
                                      size: 'medium',
                                    ),
                                    if (isLandscape) ...[
                                      const SizedBox(width: 6),
                                      AreasAndPubTime(data: displayData, t: t),
                                      const SizedBox(width: 6),
                                      NewEpDesc(data: displayData, t: t),
                                    ],
                                  ],
                                ),
                                SizedBox(height: isLandscape ? 2 : 6),
                                if (!isLandscape)
                                  AreasAndPubTime(data: displayData, t: t),
                                if (!isLandscape)
                                  NewEpDesc(data: displayData, t: t),
                                const Spacer(),
                                Text(
                                  '简介：${displayData.evaluate ?? ''}',
                                  maxLines: isLandscape ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 点赞收藏转发 布局样式1
                  // SingleChildScrollView(
                  //   padding: const EdgeInsets.only(top: 7, bottom: 7),
                  //   scrollDirection: Axis.horizontal,
                  //   child: actionRow(
                  //     context,
                  //     bangumiIntroController,
                  //     videoDetailCtr,
                  //   ),
                  // ),
                  // 点赞收藏转发 布局样式2
                  actionGrid(context, bangumiIntroController, displayData),
                  // 番剧分p
                  if (episodes.isNotEmpty) ...[
                    BangumiPanel(
                      pages: episodes,
                      cid: cid ?? episodes.first.cid,
                      changeFuc: bangumiIntroController.changeSeasonOrbangu,
                      isMovie: displayData.type == 2,
                    ),
                  ],
                ],
              )
            : const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
      ),
    );
  }

  Widget actionGrid(
    BuildContext context,
    bangumiIntroController,
    BangumiInfoModel displayData,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Material(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Obx(
                    () => ActionItem(
                      icon: const Icon(Icons.thumb_up_outlined),
                      selectIcon: const Icon(Icons.thumb_up),
                      onTap: handleState(
                        bangumiIntroController.actionLikeVideo,
                      ),
                      selectStatus: bangumiIntroController.hasLike.value,
                      loadingStatus: false,
                      semanticsLabel: '点赞',
                      text: Utils.numFormat(displayData.stat?['likes'] ?? 0),
                    ),
                  ),
                  Obx(
                    () => ActionItem(
                      icon: const Icon(Icons.offline_bolt_outlined),
                      selectIcon: const Icon(Icons.offline_bolt),
                      onTap: handleState(
                        bangumiIntroController.actionCoinVideo,
                      ),
                      selectStatus: bangumiIntroController.hasCoin.value,
                      loadingStatus: false,
                      semanticsLabel: '投币',
                      text: Utils.numFormat(displayData.stat?['coins'] ?? 0),
                    ),
                  ),
                  Obx(
                    () => ActionItem(
                      icon: Icon(MdiIcons.starPlusOutline),
                      selectIcon: Icon(MdiIcons.star),
                      onTap: () => showFavBottomSheet(),
                      selectStatus: bangumiIntroController.hasFav.value,
                      loadingStatus: false,
                      semanticsLabel: '收藏',
                      text: Utils.numFormat(displayData.stat?['favorite'] ?? 0),
                    ),
                  ),
                  ActionItem(
                    icon: Icon(MdiIcons.chatOutline),
                    selectIcon: Icon(MdiIcons.reply),
                    onTap: () => videoDetailCtr.tabCtr.animateTo(1),
                    selectStatus: false,
                    loadingStatus: false,
                    semanticsLabel: '评论',
                    text: Utils.numFormat(displayData.stat?['reply'] ?? 0),
                  ),
                  ActionItem(
                    icon: const Icon(Icons.share_outlined),
                    onTap: () => bangumiIntroController.actionShareVideo(),
                    selectStatus: false,
                    loadingStatus: false,
                    semanticsLabel: '转发',
                    text: Utils.numFormat(displayData.stat?['share'] ?? 0),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget actionRow(BuildContext context, videoIntroController, videoDetailCtr) {
    return Row(
      children: [
        Obx(
          () => ActionRowItem(
            icon: const FaIcon(FontAwesomeIcons.thumbsUp),
            onTap: handleState(videoIntroController.actionLikeVideo),
            selectStatus: videoIntroController.hasLike.value,
            loadingStatus: widget.loadingStatus,
            text: !widget.loadingStatus
                ? widget.bangumiDetail!.stat!['likes']!.toString()
                : '-',
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => ActionRowItem(
            icon: const FaIcon(FontAwesomeIcons.b),
            onTap: handleState(videoIntroController.actionCoinVideo),
            selectStatus: videoIntroController.hasCoin.value,
            loadingStatus: widget.loadingStatus,
            text: !widget.loadingStatus
                ? widget.bangumiDetail!.stat!['coins']!.toString()
                : '-',
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => ActionRowItem(
            icon: const FaIcon(FontAwesomeIcons.heart),
            onTap: () => showFavBottomSheet(),
            selectStatus: videoIntroController.hasFav.value,
            loadingStatus: widget.loadingStatus,
            text: !widget.loadingStatus
                ? widget.bangumiDetail!.stat!['favorite']!.toString()
                : '-',
          ),
        ),
        const SizedBox(width: 8),
        ActionRowItem(
          icon: const FaIcon(FontAwesomeIcons.comment),
          onTap: () {
            videoDetailCtr.tabCtr.animateTo(1);
          },
          selectStatus: false,
          loadingStatus: widget.loadingStatus,
          text: !widget.loadingStatus
              ? widget.bangumiDetail!.stat!['reply']!.toString()
              : '-',
        ),
        const SizedBox(width: 8),
        ActionRowItem(
          icon: const FaIcon(FontAwesomeIcons.share),
          onTap: () => videoIntroController.actionShareVideo(),
          selectStatus: false,
          loadingStatus: widget.loadingStatus,
          text: '转发',
        ),
      ],
    );
  }
}

class PgcFollowButton extends StatelessWidget {
  const PgcFollowButton({
    super.key,
    required this.followed,
    required this.updating,
    required this.actionLabel,
    required this.onPressed,
  });

  final bool? followed;
  final bool updating;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool busy = followed == null || updating;
    return IconButton(
      tooltip: busy
          ? '正在同步$actionLabel状态'
          : followed!
          ? '取消$actionLabel'
          : actionLabel,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        backgroundColor: WidgetStateProperty.resolveWith((_) {
          return theme.colorScheme.primaryContainer.withValues(alpha: 0.7);
        }),
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              followed!
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: followed!
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 22,
            ),
    );
  }
}

class AreasAndPubTime extends StatelessWidget {
  const AreasAndPubTime({super.key, required this.data, required this.t});

  final BangumiInfoModel data;
  final ThemeData t;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          data.areas?.isNotEmpty == true
              ? data.areas!.first['name']?.toString() ?? ''
              : '',
          style: TextStyle(fontSize: 12, color: t.colorScheme.outline),
        ),
        const SizedBox(width: 6),
        Text(
          data.publish?['pub_time_show']?.toString() ?? '',
          style: TextStyle(fontSize: 12, color: t.colorScheme.outline),
        ),
      ],
    );
  }
}

class NewEpDesc extends StatelessWidget {
  const NewEpDesc({super.key, required this.data, required this.t});

  final BangumiInfoModel data;
  final ThemeData t;

  @override
  Widget build(BuildContext context) {
    return Text(
      data.newEp?['desc']?.toString() ?? '',
      style: TextStyle(fontSize: 12, color: t.colorScheme.outline),
    );
  }
}

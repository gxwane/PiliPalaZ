import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/constants.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/http/pgc.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/models/common/pgc_type.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/models/common/video_source_type.dart';
import 'package:pilipalaz/models/user/fav_folder.dart';
import 'package:pilipalaz/pages/video/index.dart';
import 'package:pilipalaz/pages/video/playback_input.dart';
import 'package:pilipalaz/pages/video/reply/index.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipalaz/utils/feed_back.dart';
import 'package:pilipalaz/utils/id_utils.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/services/pgc_playback_coordinator.dart';

class BangumiIntroController extends GetxController {
  // 视频bvid
  String bvid = Get.parameters['bvid']!;
  var seasonId = Get.parameters['seasonId'] != null
      ? int.parse(Get.parameters['seasonId']!)
      : null;
  var epId = Get.parameters['epId'] != null
      ? int.tryParse(Get.parameters['epId']!)
      : null;
  String heroTag = Get.arguments['heroTag'];

  // 是否预渲染 骨架屏
  bool preRender = false;

  // 视频详情 上个页面传入
  Map? videoItem = {};
  BangumiInfoModel? bangumiItem;

  // 请求状态
  RxBool isLoading = false.obs;

  // 视频详情 请求返回
  Rx<BangumiInfoModel> bangumiDetail = BangumiInfoModel().obs;

  // 请求返回的信息
  String responseMsg = '请求异常';

  // up主粉丝数
  Map userStat = {'follower': '-'};

  // 是否点赞
  RxBool hasLike = false.obs;
  // 是否投币
  RxBool hasCoin = false.obs;
  // 是否收藏
  RxBool hasFav = false.obs;
  // 是否追番
  RxnBool hasFollow = RxnBool();
  RxBool isFollowUpdating = false.obs;
  Box userInfoCache = GStorage.userInfo;
  bool userLogin = false;
  Rx<FavFolderData> favFolderData = FavFolderData().obs;
  List addMediaIdsNew = [];
  List delMediaIdsNew = [];
  // 关注状态 默认未关注
  RxMap followStatus = {}.obs;
  int _tempThemeValue = -1;
  RxInt lastPlayCid = Get.parameters['cid'] != null
      ? int.tryParse(Get.parameters['cid']!)!.obs
      : 0.obs;
  var userInfo;

  PgcCatalogType get catalogType => PgcCatalogTypeCode.fromApiValue(
    bangumiDetail.value.type ?? bangumiItem?.type,
  );

  String get followActionLabel => catalogType.followActionLabel;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments.isNotEmpty as bool) {
      if (Get.arguments.containsKey('bangumiItem') as bool) {
        preRender = true;
        bangumiItem = Get.arguments['bangumiItem'];
        // bangumiItem!['pic'] = args.pic;
        // if (args.title is String) {
        //   videoItem!['title'] = args.title;
        // } else {
        //   String str = '';
        //   for (Map map in args.title) {
        //     str += map['text'];
        //   }
        //   videoItem!['title'] = str;
        // }
        // if (args.stat != null) {
        //   videoItem!['stat'] = args.stat;
        // }
        // videoItem!['pubdate'] = args.pubdate;
        // videoItem!['owner'] = args.owner;
      }
    }
    userInfo = userInfoCache.get('userInfoCache');
    userLogin = userInfo != null;
    hasFollow.value = userLogin ? bangumiItem?.followedState : false;
    bangumiDetail.listen((value) {
      final VideoDetailController videoDetailCtr =
          Get.find<VideoDetailController>(tag: heroTag);
      final cid = videoDetailCtr.cid.value;
      final current = value.episodes?.firstWhere(
        (element) => element.cid == cid,
      );

      videoPlayerServiceHandler.onVideoDetailChange(
        current?.longTitle ?? "",
        value.title ?? "",
        Duration(milliseconds: current?.duration ?? 0),
        value.cover ?? "",
      );
    });
  }

  void openVideoDetail() {
    Get.toNamed(
      '/video?bvid=$bvid&cid=${lastPlayCid.value}'
      '&seasonId=$seasonId&epId=$epId&resume=true',
      arguments: <String, dynamic>{
        'pic': bangumiDetail.value.cover ?? bangumiItem?.cover,
        'heroTag': heroTag,
        'videoType': catalogType.followGroup == PgcFollowGroup.bangumi
            ? SearchType.media_bangumi
            : SearchType.media_ft,
        'sourceType': VideoSourceType.pgc,
        'bangumiItem': bangumiDetail.value,
      },
    );
  }

  // 获取番剧简介&选集
  Future queryBangumiIntro() async {
    if (userLogin) {
      // 获取点赞状态
      queryHasLikeVideo();
      // 获取投币状态
      queryHasCoinVideo();
      // 获取收藏状态
      queryHasFavVideo();
    }
    Map<String, dynamic> result;
    String? followSyncError;
    if (bangumiItem != null) {
      result = <String, dynamic>{'status': true, 'data': bangumiItem};
      if (userLogin && bangumiItem!.followedState == null) {
        final int? resolvedSeasonId = bangumiItem!.seasonId ?? seasonId;
        if (resolvedSeasonId == null) {
          followSyncError = '缺少影视季度信息';
        } else {
          final Map<String, dynamic> statusResult = await PgcHttp.followStatus(
            seasonId: resolvedSeasonId,
          );
          if (statusResult['status'] == true) {
            bangumiItem!.applyFollowStatus(statusResult['data'] as UserStatus);
          } else {
            followSyncError = statusResult['msg']?.toString() ?? '追剧状态同步失败';
          }
        }
      }
    } else {
      result = await PgcHttp.infoWithFollowStatus(
        seasonId: seasonId,
        epId: epId,
      );
      followSyncError = result['followStatusError']?.toString();
    }
    if (result['status']) {
      _applyBangumiDetail(result['data'] as BangumiInfoModel);
      if (followSyncError != null) {
        SmartDialog.showToast('追剧状态同步失败，请稍后重试');
      }
    } else {
      SmartDialog.showToast(result['msg']);
    }
    return result;
  }

  void _applyBangumiDetail(BangumiInfoModel detail) {
    bangumiDetail.value = detail;
    final EpisodeItem selected = PgcEpisodeSelector.select(
      episodes: detail.episodes ?? const <EpisodeItem>[],
      explicitEpId: epId,
      progressEpId: detail.userStatus?.progress?.lastEpId,
    );
    epId = selected.epId;
    seasonId = detail.seasonId;
    hasFollow.value = userLogin ? detail.followedState : false;
  }

  // 获取点赞状态
  Future queryHasLikeVideo() async {
    var result = await VideoHttp.hasLikeVideo(bvid: bvid);
    // data	num	被点赞标志	0：未点赞  1：已点赞
    hasLike.value = result["data"] == 1 ? true : false;
  }

  // 获取投币状态
  Future queryHasCoinVideo() async {
    var result = await VideoHttp.hasCoinVideo(bvid: bvid);
    hasCoin.value = result["data"]['multiply'] == 0 ? false : true;
  }

  // 获取收藏状态
  Future queryHasFavVideo() async {
    var result = await VideoHttp.hasFavVideo(aid: IdUtils.bv2av(bvid));
    if (result['status']) {
      hasFav.value = result["data"]['favoured'];
    } else {
      hasFav.value = false;
    }
  }

  // （取消）点赞
  Future actionLikeVideo() async {
    var result = await VideoHttp.likeVideo(bvid: bvid, type: !hasLike.value);
    if (result['status']) {
      SmartDialog.showToast(!hasLike.value ? result['data']['toast'] : '取消赞');
      hasLike.value = !hasLike.value;
      bangumiDetail.value.stat!['likes'] =
          bangumiDetail.value.stat!['likes'] + (!hasLike.value ? 1 : -1);
      hasLike.refresh();
    } else {
      SmartDialog.showToast(result['msg']);
    }
  }

  // 投币
  Future actionCoinVideo() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择投币个数'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          content: StatefulBuilder(
            builder: (context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile(
                    value: 1,
                    title: const Text('1枚'),
                    groupValue: _tempThemeValue,
                    onChanged: (value) {
                      _tempThemeValue = value!;
                      Get.appUpdate();
                    },
                  ),
                  RadioListTile(
                    value: 2,
                    title: const Text('2枚'),
                    groupValue: _tempThemeValue,
                    onChanged: (value) {
                      _tempThemeValue = value!;
                      Get.appUpdate();
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                var res = await VideoHttp.coinVideo(
                  bvid: bvid,
                  multiply: _tempThemeValue,
                );
                if (res['status']) {
                  SmartDialog.showToast('投币成功');
                  hasCoin.value = true;
                  bangumiDetail.value.stat!['coins'] =
                      bangumiDetail.value.stat!['coins'] + _tempThemeValue;
                } else {
                  SmartDialog.showToast(res['msg']);
                }
                Get.back();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // （取消）收藏
  Future actionFavVideo() async {
    try {
      for (var i in favFolderData.value.list!.toList()) {
        if (i.favState == 1) {
          addMediaIdsNew.add(i.id);
        } else {
          delMediaIdsNew.add(i.id);
        }
      }
    } catch (_) {}
    var result = await VideoHttp.favVideo(
      aid: IdUtils.bv2av(bvid),
      addIds: addMediaIdsNew.join(','),
      delIds: delMediaIdsNew.join(','),
    );
    if (result['status']) {
      addMediaIdsNew = [];
      delMediaIdsNew = [];
      // 重新获取收藏状态
      queryHasFavVideo();
      SmartDialog.showToast('操作成功');
      Get.back();
    }
  }

  // 分享视频
  Future actionShareVideo() async {
    showDialog(
      context: Get.context!,
      builder: (context) {
        String videoUrl = '${HttpString.baseUrl}/video/$bvid';
        return AlertDialog(
          title: const Text('请选择'),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: videoUrl));
                SmartDialog.showToast('已复制');
                Get.back();
              },
              icon: const Icon(Icons.copy),
              label: const Text('复制链接'),
            ),
            TextButton.icon(
              onPressed: () {
                launchUrl(Uri.parse(videoUrl));
                Get.back();
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('其它app打开'),
            ),
            TextButton.icon(
              onPressed: () async {
                await SharePlus.instance.share(ShareParams(text: videoUrl));
                Get.back();
              },
              icon: const Icon(Icons.share),
              label: const Text('分享视频'),
            ),
          ],
        );
      },
    );
  }

  // 选择文件夹
  onChoose(bool checkValue, int index) {
    feedBack();
    List<FavFolderItemData> datalist = favFolderData.value.list!;
    for (var i = 0; i < datalist.length; i++) {
      if (i == index) {
        datalist[i].favState = checkValue == true ? 1 : 0;
        datalist[i].mediaCount = checkValue == true
            ? datalist[i].mediaCount! + 1
            : datalist[i].mediaCount! - 1;
      }
    }
    favFolderData.value.list = datalist;
    favFolderData.refresh();
  }

  // 修改分P或番剧分集
  Future<bool> changeSeasonOrbangu(bvid, cid, aid, [int? nextEpId]) async {
    // 重新获取视频资源
    VideoDetailController videoDetailCtr = Get.find<VideoDetailController>(
      tag: heroTag,
    );
    final String previousBvid = videoDetailCtr.bvid;
    final int previousCid = videoDetailCtr.cid.value;
    final int? previousEpId = videoDetailCtr.epId;
    final bool previousWasReady =
        videoDetailCtr.playbackLoadState.value == PlaybackLoadState.ready;
    videoDetailCtr.bvid = bvid;
    videoDetailCtr.cid.value = cid;
    videoDetailCtr.danmakuCid.value = cid;
    int? resolvedEpId = nextEpId;
    if (resolvedEpId == null) {
      for (final EpisodeItem item
          in bangumiDetail.value.episodes ?? const <EpisodeItem>[]) {
        if (item.cid == cid) {
          resolvedEpId = item.epId;
          break;
        }
      }
    }
    videoDetailCtr.epId = resolvedEpId;
    final Map result = await videoDetailCtr.queryVideoUrl(
      preserveCurrentOnFailure: previousWasReady,
    );
    if (result['status'] != true) {
      final String targetMessage = result['msg']?.toString() ?? '影视内容暂不可播放';
      videoDetailCtr.bvid = previousBvid;
      videoDetailCtr.cid.value = previousCid;
      videoDetailCtr.danmakuCid.value = previousCid;
      videoDetailCtr.epId = previousEpId;
      final Map restoreResult = await videoDetailCtr.queryVideoUrl(
        showPreviewNotice: false,
      );
      if (restoreResult['status'] == true) {
        videoDetailCtr.playbackError.value = '';
        SmartDialog.showNotify(
          msg: targetMessage,
          displayTime: const Duration(seconds: 4),
          notifyType: NotifyType.warning,
        );
      } else {
        videoDetailCtr.playbackError.value = '切换剧集失败，原剧集也未能恢复，请点击重试';
      }
      return false;
    }
    this.bvid = bvid;
    epId = videoDetailCtr.epId;
    lastPlayCid.value = cid;
    // 触发媒体通知更新
    bangumiDetail.refresh();
    // 重新请求评论
    try {
      /// 未渲染回复组件时可能异常
      VideoReplyController videoReplyCtr = Get.find<VideoReplyController>(
        tag: heroTag,
      );
      videoReplyCtr.aid = aid;
      videoReplyCtr.queryReplyList(type: 'init');
    } catch (_) {}
    return true;
  }

  // 切换追番状态
  Future toggleFollow() async {
    if (!userLogin) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    final bool? currentStatus = hasFollow.value;
    if (currentStatus == null || isFollowUpdating.value) return;
    final bool nextStatus = !currentStatus;
    isFollowUpdating.value = true;
    hasFollow.value = nextStatus;
    try {
      var result;
      if (currentStatus) {
        result = await VideoHttp.bangumiDel(
          seasonId: bangumiDetail.value.seasonId,
        );
      } else {
        result = await VideoHttp.bangumiAdd(
          seasonId: bangumiDetail.value.seasonId,
        );
      }
      if (result['status']) {
        _syncFollowedModels(nextStatus);
        SmartDialog.showToast(
          result['msg'] ??
              (currentStatus ? '已取消$followActionLabel' : '已$followActionLabel'),
        );
      } else {
        hasFollow.value = currentStatus;
        SmartDialog.showToast(result['msg']);
      }
    } catch (e) {
      hasFollow.value = currentStatus;
      SmartDialog.showToast('操作失败: $e');
    } finally {
      isFollowUpdating.value = false;
    }
  }

  void _syncFollowedModels(bool followed) {
    bangumiDetail.value.setFollowed(followed);
    bangumiDetail.refresh();
    if (bangumiItem != null && !identical(bangumiItem, bangumiDetail.value)) {
      bangumiItem!.setFollowed(followed);
    }
  }

  Future queryVideoInFolder() async {
    var result = await VideoHttp.videoInFolder(
      mid: userInfo.mid,
      rid: IdUtils.bv2av(bvid),
    );
    if (result['status']) {
      favFolderData.value = result['data'];
    }
    return result;
  }

  bool prevPlay() {
    late List episodes;
    if (bangumiDetail.value.episodes != null) {
      episodes = bangumiDetail.value.episodes!;
    }
    int currentIndex = episodes.indexWhere((e) => e.cid == lastPlayCid.value);
    int prevIndex = currentIndex - 1;
    PlayRepeat playRepeat = PlPlayerController.getInstance().playRepeat;
    if (prevIndex < 0) {
      if (playRepeat == PlayRepeat.listCycle) {
        prevIndex = episodes.length - 1;
      } else {
        return false;
      }
    }
    int cid = episodes[prevIndex].cid!;
    String bvid = episodes[prevIndex].bvid!;
    int aid = episodes[prevIndex].aid!;
    final int? nextEpId = episodes[prevIndex].epId;
    changeSeasonOrbangu(bvid, cid, aid, nextEpId);
    return true;
  }

  bool hasNextEpisode() {
    late List episodes;
    if (bangumiDetail.value.episodes == null) {
      return false;
    }
    episodes = bangumiDetail.value.episodes!;
    PlayRepeat playRepeat = PlPlayerController.getInstance().playRepeat;
    if (playRepeat == PlayRepeat.listCycle) {
      return true;
    }
    int currentIndex = episodes.indexWhere((e) => e.cid == lastPlayCid.value);
    return currentIndex < episodes.length - 1;
  }

  /// 列表循环或者顺序播放时，自动播放下一个；自动连播时，播放相关视频
  bool nextPlay() {
    late List<EpisodeItem> episodes;
    PlayRepeat playRepeat = PlPlayerController.getInstance().playRepeat;

    if (bangumiDetail.value.episodes != null) {
      episodes = bangumiDetail.value.episodes!;
    } else {
      if (playRepeat == PlayRepeat.autoPlayRelated) {
        return playRelated();
      }
    }
    if (episodes.isEmpty) return false;
    int currentIndex = episodes.indexWhere((e) => e.cid == lastPlayCid.value);
    final int? resolvedNextIndex = PgcEpisodeNavigator.nextIndex(
      episodeCount: episodes.length,
      currentIndex: currentIndex,
      cycle: playRepeat == PlayRepeat.listCycle,
    );
    if (resolvedNextIndex == null) {
      if (playRepeat == PlayRepeat.autoPlayRelated) {
        return playRelated();
      }
      return false;
    }
    final int nextIndex = resolvedNextIndex;
    int cid = episodes[nextIndex].cid!;
    String bvid = episodes[nextIndex].bvid!;
    int aid = episodes[nextIndex].aid!;
    final int? nextEpId = episodes[nextIndex].epId;
    changeSeasonOrbangu(bvid, cid, aid, nextEpId);
    return true;
  }

  void showPreviewEnded() {
    final EpisodeItem? current = bangumiDetail.value.episodes?.firstWhere(
      (EpisodeItem item) => item.cid == lastPlayCid.value,
      orElse: () => EpisodeItem(),
    );
    final String? officialUrl =
        current?.shareUrl ?? bangumiDetail.value.shareUrl;
    Get.dialog<void>(
      AlertDialog(
        title: const Text('试看已结束'),
        content: const Text('完整内容需要相应权益，可前往哔哩哔哩官方客户端继续观看。'),
        actions: <Widget>[
          TextButton(onPressed: Get.back, child: const Text('关闭')),
          if (officialUrl?.isNotEmpty == true)
            FilledButton(
              onPressed: () {
                Get.back();
                launchUrl(
                  Uri.parse(officialUrl!),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('前往官方'),
            ),
        ],
      ),
    );
  }

  bool playRelated() {
    SmartDialog.showToast('影视内容暂无相关视频');
    return false;
  }
}

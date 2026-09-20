import 'dart:async';

import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/constants.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/user_api.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/http/video_api.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/models/user/fav_folder.dart';
import 'package:pilipalaz/models/video/ai.dart';
import 'package:pilipalaz/models/user/stat.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/reply/index.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipalaz/utils/feed_back.dart';
import 'package:pilipalaz/utils/id_utils.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pilipalaz/pages/member/controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pilipalaz/services/service_locator.dart';

import '../../../../../http/search.dart';
import '../../../../../models/model_hot_video_item.dart' hide Stat;
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/models/common/play_queue_item.dart';
import '../../related/index.dart';

class VideoIntroController extends GetxController {
  // 统一播放队列控制器
  late final PlaybackQueueController playbackQueueController;

  // 视频bvid
  late String bvid;

  // 是否预渲染 骨架屏
  bool preRender = false;

  // 视频详情 上个页面传入
  Map? videoItem = {};

  // 请求状态
  RxBool isLoading = false.obs;

  // 视频详情 请求返回
  Rx<VideoDetailData> videoDetail = VideoDetailData().obs;

  // up主粉丝数
  Rx<UserStat> userStat = UserStat().obs;

  // 是否点赞
  RxBool hasLike = false.obs;
  // 是否点踩
  RxBool hasDislike = false.obs;
  // 是否投币
  RxBool hasCoin = false.obs;
  // 是否收藏
  RxBool hasFav = false.obs;
  Box userInfoCache = GStorage.userInfo;
  bool userLogin = false;
  Rx<FavFolderData> favFolderData = FavFolderData().obs;
  List addMediaIdsNew = [];
  List delMediaIdsNew = [];
  // 关注状态 默认未关注
  RxMap followStatus = {}.obs;

  RxInt lastPlayCid = 0.obs;
  var userInfo;

  // 同时观看
  bool isShowOnlineTotal = false;
  RxString total = '1'.obs;
  Timer? timer;
  bool isPaused = false;
  String heroTag = '';
  Rxn<ApiFailure<VideoDetailData>> videoIntroFailure =
      Rxn<ApiFailure<VideoDetailData>>();

  bool get isOffline {
    try {
      final ctr = Get.find<VideoDetailController>(tag: heroTag);
      return ctr.isOffline;
    } catch (_) {
      return Get.arguments is Map && Get.arguments['isOffline'] == true;
    }
  }

  @override
  void onInit() {
    super.onInit();
    userInfo = userInfoCache.get('userInfoCache');
    final args = Get.arguments;
    if (args is Map &&
        args['heroTag'] != null &&
        args['heroTag'].toString().isNotEmpty) {
      heroTag = args['heroTag'].toString();
    } else {
      final bvidParam = Get.parameters['bvid'];
      if (bvidParam != null && bvidParam.isNotEmpty) {
        heroTag = Utils.makeHeroTag(bvidParam);
      }
    }
    bvid = Get.parameters['bvid'] ?? '';
    if (args is Map && args.isNotEmpty) {
      if (args.containsKey('videoItem')) {
        preRender = true;
        var args = Get.arguments['videoItem'];
        var keys = Get.arguments.keys.toList();
        videoItem!['pic'] = args.pic;
        if (args.title is String) {
          videoItem!['title'] = args.title;
        } else {
          String str = '';
          for (Map map in args.title) {
            str += map['text'];
          }
          videoItem!['title'] = str;
        }
        videoItem!['stat'] = keys.contains('stat') ? args.stat : null;
        videoItem!['pubdate'] = keys.contains('pubdate') ? args.pubdate : null;
        videoItem!['owner'] = keys.contains('owner') ? args.owner : null;
      }
    }
    userLogin = userInfo != null;
    lastPlayCid.value = int.tryParse(Get.parameters['cid'] ?? '') ?? 0;
    isShowOnlineTotal = setting.get(
      SettingBoxKey.enableOnlineTotal,
      defaultValue: false,
    );
    try {
      playbackQueueController = Get.find<PlaybackQueueController>(tag: heroTag);
    } catch (_) {
      playbackQueueController = Get.put(
        PlaybackQueueController(heroTag: heroTag),
        tag: heroTag,
      );
    }

    if (Get.arguments is Map &&
        (Get.arguments as Map).containsKey('watchLaterList')) {
      final List<HotVideoItemModel> list =
          ((Get.arguments as Map)['watchLaterList'] as List)
              .cast<HotVideoItemModel>();
      final int initialIndex =
          (Get.arguments as Map)['watchLaterIndex'] as int? ?? 0;
      playbackQueueController.initFromWatchLater(
        items: list,
        initialIndex: initialIndex,
      );
    }

    playbackQueueController.onPlayItem = (PlayQueueItem item) async {
      int resolvedCid = item.cid;
      if (resolvedCid == 0) {
        final cidResult = await SearchHttp.ab2c(aid: item.aid, bvid: item.bvid);
        if (cidResult case ApiSuccess<int>(:final data)) {
          resolvedCid = data;
        } else {
          SmartDialog.showToast('获取视频信息失败');
          return false;
        }
      }
      await changeSeasonOrbangu(item.bvid, resolvedCid, item.aid);
      return true;
    };

    playbackQueueController.onRequestRelated = () async {
      try {
        final RelatedController relatedCtr = Get.find<RelatedController>(
          tag: heroTag,
        );
        if (relatedCtr.relatedVideoList.isEmpty) {
          final res = await relatedCtr.queryRelatedVideo();
          if (res is ApiSuccess<List<HotVideoItemModel>>) {
            return res.data;
          }
        }
        return relatedCtr.relatedVideoList.cast<HotVideoItemModel>().toList();
      } catch (_) {
        return [];
      }
    };

    if (!isOffline && isShowOnlineTotal) {
      queryOnlineTotal();
      startTimer(); // 在页面加载时启动定时器
    }
    queryVideoIntro();

    videoDetail.listen((value) {
      if ((value.pages?.length ?? 0) > 1) {
        final VideoDetailController videoDetailCtr =
            Get.find<VideoDetailController>(tag: heroTag);
        final cid = videoDetailCtr.cid.value;
        final current = value.pages?.firstWhereOrNull(
          (element) => element.cid == cid,
        );

        videoPlayerServiceHandler.onVideoDetailChange(
          current?.pagePart ?? "",
          value.title ?? "",
          Duration(seconds: current?.duration ?? 0),
          value.pic ?? "",
        );
      } else {
        videoPlayerServiceHandler.onVideoDetailChange(
          value.title ?? "",
          value.owner?.name ?? "",
          Duration(seconds: value.duration ?? 0),
          value.pic ?? "",
        );
      }
    });
  }

  void openVideoDetail() {
    // if (Get.previousRoute == '/video?bvid=$bvid&cid=${lastPlayCid.value}') {
    //   Get.back();
    //   return;
    // }

    VideoDetailController? videoDetailCtr;
    try {
      videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);
    } catch (_) {}
    print("videoDetailCtr: $videoDetailCtr");
    if (videoDetailCtr == null) {
      Get.toNamed(
        '/video?bvid=$bvid&cid=${lastPlayCid.value}&resume=true',
        arguments: {'heroTag': heroTag},
      );
      return;
    }
    videoDetailCtr.resumePlay = true;
    popRouteStackContinuously = '/video?bvid=$bvid&cid=${lastPlayCid.value}';
    Get.until((Route<dynamic> route) {
      print(route.settings.name);
      print(route.settings.arguments);
      print(route.settings.arguments.runtimeType);
      if (route.settings.arguments is Map) {
        String? heroTagCurr =
            (route.settings.arguments as Map<String, dynamic>)['heroTag'];
        if (heroTagCurr != null && heroTagCurr.isNotEmpty) {
          return heroTag == heroTagCurr;
        }
      }
      // String? args = route.settings.arguments?.toString();
      // if (args != null && args.isNotEmpty) {
      //   String? heroTagCurr =jsonDecode(args)['heroTag'];
      //   if (heroTagCurr != null && heroTagCurr.isNotEmpty) {
      //     return heroTag == heroTagCurr;
      //   }
      // }
      // return route.settings.arguments!.heroTag == heroTag || route.isFirst;
      return route.settings.name?.startsWith('/video?bvid=$bvid') == true ||
          route.isFirst;
    });
    popRouteStackContinuously = "";
  }

  bool _handleOfflineIntro() {
    VideoDetailController? videoDetailCtr;
    try {
      videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);
    } catch (_) {}

    final bool isOffline =
        videoDetailCtr?.isOffline ??
        (Get.arguments is Map ? Get.arguments['isOffline'] == true : false);
    if (!isOffline) return false;

    final DownloadTask? offlineTask =
        videoDetailCtr?.offlineTask ??
        (Get.arguments is Map
            ? Get.arguments['offlineTask'] as DownloadTask?
            : null);
    if (offlineTask == null) return false;

    final taskPart = Part(
      cid: offlineTask.cid,
      page: 1,
      pagePart: offlineTask.partTitle.isNotEmpty
          ? offlineTask.partTitle
          : offlineTask.title,
      duration: offlineTask.duration,
    );
    videoDetail.value = VideoDetailData(
      bvid: offlineTask.bvid,
      aid: offlineTask.aid,
      title: offlineTask.title,
      pic: offlineTask.cover,
      duration: offlineTask.duration,
      owner: Owner(name: offlineTask.ownerName),
      pages: [taskPart],
      desc: '',
      descV2: <DescV2>[],
      stat: Stat(
        view: 0,
        danmu: 0,
        reply: 0,
        favorite: 0,
        coin: 0,
        share: 0,
        like: 0,
      ),
    );
    lastPlayCid.value = offlineTask.cid;
    playbackQueueController.initFromPages(
      pages: [taskPart],
      bvid: offlineTask.bvid,
      aid: offlineTask.aid ?? IdUtils.bv2av(offlineTask.bvid),
      currentCid: offlineTask.cid,
      cover: offlineTask.cover,
      author: offlineTask.ownerName,
    );
    return true;
  }

  // 获取视频简介&分p
  Future<void> queryVideoIntro() async {
    videoIntroFailure.value = null;
    if (_handleOfflineIntro()) return;
    final result = await VideoApi.instance.detail(bvid: bvid);
    if (result case ApiSuccess<VideoDetailData>(:final data)) {
      videoDetail.value = data;
      if (videoDetail.value.pages != null &&
          videoDetail.value.pages!.isNotEmpty &&
          lastPlayCid.value == 0) {
        lastPlayCid.value = videoDetail.value.pages!.first.cid!;
      }
      if (playbackQueueController.isExternalQueue.value) {
        playbackQueueController.syncCurrent(bvid: bvid, cid: lastPlayCid.value);
      } else if (videoDetail.value.pages != null &&
          videoDetail.value.pages!.length > 1) {
        playbackQueueController.initFromPages(
          pages: videoDetail.value.pages!,
          bvid: bvid,
          aid: IdUtils.bv2av(bvid),
          currentCid: lastPlayCid.value,
          cover: videoDetail.value.pic,
          author: videoDetail.value.owner?.name,
        );
      } else if (videoDetail.value.ugcSeason != null) {
        playbackQueueController.initFromUgcSeason(
          ugcSeason: videoDetail.value.ugcSeason!,
          currentCid: lastPlayCid.value,
        );
      } else {
        playbackQueueController.initFromPages(
          pages:
              videoDetail.value.pages ??
              [
                Part(
                  cid: lastPlayCid.value,
                  page: 1,
                  pagePart: videoDetail.value.title,
                  duration: videoDetail.value.duration,
                ),
              ],
          bvid: bvid,
          aid: IdUtils.bv2av(bvid),
          currentCid: lastPlayCid.value,
          cover: videoDetail.value.pic,
          author: videoDetail.value.owner?.name,
        );
      }
      // 获取到粉丝数再返回
      await queryUserStat();
    } else {
      final failure = result as ApiFailure<VideoDetailData>;
      videoIntroFailure.value = failure;
      SmartDialog.showToast(failure.message);
    }
    if (userLogin) {
      // 获取点赞状态
      queryHasLikeVideo();
      // 获取投币状态
      queryHasCoinVideo();
      // 获取收藏状态
      queryHasFavVideo();
      //
      queryFollowStatus();
    }
  }

  // 获取up主粉丝数
  Future queryUserStat() async {
    final mid = videoDetail.value.owner?.mid;
    if (mid == null) {
      userStat.value = UserStat();
      return;
    }
    final result = await UserApi.instance.stat(mid: mid);
    if (result case ApiSuccess<UserStat>(:final data)) {
      userStat.value = data;
      userStat.refresh();
    }
  }

  // 获取点赞状态
  Future queryHasLikeVideo() async {
    var result = await VideoHttp.hasLikeVideo(bvid: bvid);
    // data	num	被点赞标志	0：未点赞  1：已点赞  2：已点踩
    if (result case ApiSuccess<int>(:final data)) {
      hasLike.value = data == 1;
      hasDislike.value = data == 2;
    }
  }

  // 获取投币状态
  Future queryHasCoinVideo() async {
    var result = await VideoHttp.hasCoinVideo(bvid: bvid);
    if (result case ApiSuccess<VideoCoinState>(:final data)) {
      hasCoin.value = data.multiply != 0;
    }
  }

  // 获取收藏状态
  Future queryHasFavVideo() async {
    /// fix 延迟查询
    await Future.delayed(const Duration(milliseconds: 200));
    var result = await VideoHttp.hasFavVideo(aid: IdUtils.bv2av(bvid));
    if (result case ApiSuccess<VideoFavoriteState>(:final data)) {
      hasFav.value = data.favoured;
    } else {
      hasFav.value = false;
    }
  }

  // 一键三连
  Future actionOneThree() async {
    feedBack();
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    if (hasLike.value && hasCoin.value && hasFav.value) {
      // 已点赞、投币、收藏
      SmartDialog.showToast('已三连');
      return false;
    }
    var result = await VideoHttp.oneThree(bvid: bvid);
    if (result case ApiSuccess<VideoTripleState>(:final data)) {
      hasLike.value = data.liked;
      hasCoin.value = data.coined;
      hasFav.value = data.favoured;
      SmartDialog.showToast('三连成功');
    } else {
      SmartDialog.showToast((result as ApiFailure<VideoTripleState>).message);
    }
  }

  // （取消）点赞
  Future actionLikeVideo() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    var result = await VideoHttp.likeVideo(bvid: bvid, type: !hasLike.value);
    if (result case ApiSuccess<VideoActionData>(:final data)) {
      // hasLike.value = result["data"] == 1 ? true : false;
      if (!hasLike.value) {
        SmartDialog.showToast(data.toast ?? '点赞成功');
        hasLike.value = true;
        hasDislike.value = false;
        videoDetail.value.stat!.like = videoDetail.value.stat!.like! + 1;
      } else if (hasLike.value) {
        SmartDialog.showToast('取消赞');
        hasLike.value = false;
        videoDetail.value.stat!.like = videoDetail.value.stat!.like! - 1;
      }
      hasLike.refresh();
    } else {
      SmartDialog.showToast((result as ApiFailure<VideoActionData>).message);
    }
  }

  Future actionDislikeVideo() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    var result = await VideoHttp.dislikeVideo(
      bvid: bvid,
      type: !hasDislike.value,
    );
    if (result is ApiSuccess<void>) {
      // hasLike.value = result["data"] == 1 ? true : false;
      if (!hasDislike.value) {
        SmartDialog.showToast('点踩成功');
        hasDislike.value = true;
        hasLike.value = false;
      } else {
        SmartDialog.showToast('取消踩');
        hasDislike.value = false;
      }
      // hasDislike.refresh();
    } else {
      SmartDialog.showToast((result as ApiFailure<void>).message);
    }
  }

  // 投币
  Future actionCoinVideo() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    void coinVideo(int coin) async {
      var res = await VideoHttp.coinVideo(bvid: bvid, multiply: coin);
      if (res is ApiSuccess<void>) {
        SmartDialog.showToast('投币成功');
        hasCoin.value = true;
        videoDetail.value.stat!.coin = videoDetail.value.stat!.coin! + coin;
      } else {
        SmartDialog.showToast((res as ApiFailure<void>).message);
      }
    }

    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择投币个数'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                coinVideo(1);
                Get.back();
              },
              child: const Text('投 1 枚'),
            ),
            TextButton(
              onPressed: () async {
                coinVideo(2);
                Get.back();
              },
              child: const Text('投 2 枚'),
            ),
          ],
        );
      },
    );
  }

  // （取消）收藏
  Future actionFavVideo({type = 'choose'}) async {
    // 收藏至默认文件夹
    if (type == 'default') {
      SmartDialog.showLoading(msg: '请求中');
      await queryVideoInFolder();
      int defaultFolderId = favFolderData.value.list!.first.id!;
      int favStatus = favFolderData.value.list!.first.favState!;
      var result = await VideoHttp.favVideo(
        aid: IdUtils.bv2av(bvid),
        addIds: favStatus == 0 ? '$defaultFolderId' : '',
        delIds: favStatus == 1 ? '$defaultFolderId' : '',
      );
      SmartDialog.dismiss();
      if (result is ApiSuccess<void>) {
        // 重新获取收藏状态
        await queryHasFavVideo();
        SmartDialog.showToast('✅ 快速收藏/取消收藏成功');
      } else {
        SmartDialog.showToast((result as ApiFailure<void>).message);
      }
      return;
    }
    try {
      for (var i in favFolderData.value.list!.toList()) {
        if (i.favState == 1) {
          addMediaIdsNew.add(i.id);
        } else {
          delMediaIdsNew.add(i.id);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
    SmartDialog.showLoading(msg: '请求中');
    var result = await VideoHttp.favVideo(
      aid: IdUtils.bv2av(bvid),
      addIds: addMediaIdsNew.join(','),
      delIds: delMediaIdsNew.join(','),
    );
    SmartDialog.dismiss();
    if (result is ApiSuccess<void>) {
      addMediaIdsNew = [];
      delMediaIdsNew = [];
      Get.back();
      // 重新获取收藏状态
      await queryHasFavVideo();
      SmartDialog.showToast('操作成功');
    } else {
      SmartDialog.showToast((result as ApiFailure<void>).message);
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
                await SharePlus.instance.share(
                  ShareParams(
                    text:
                        '${videoDetail.value.title} '
                        'UP主: ${videoDetail.value.owner?.name ?? '未知'}'
                        ' - $videoUrl',
                  ),
                );
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

  Future<ApiResult<FavFolderData>> queryVideoInFolder() async {
    var result = await VideoHttp.videoInFolder(
      mid: userInfo.mid,
      rid: IdUtils.bv2av(bvid),
    );
    if (result case ApiSuccess<FavFolderData>(:final data)) {
      favFolderData.value = data;
    }
    return result;
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

  // 查询关注状态
  Future queryFollowStatus() async {
    final mid = videoDetail.value.owner?.mid;
    if (mid == null) {
      return;
    }
    var result = await VideoHttp.hasFollow(mid: mid);
    if (result case ApiSuccess<VideoFollowState>(:final data)) {
      followStatus.value = <String, dynamic>{'attribute': data.attribute};
    }
    return result;
  }

  // 关注/取关up
  Future actionRelationMod(BuildContext context) async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    feedBack();
    final int? mid = videoDetail.value.owner?.mid;
    if (mid == null) {
      SmartDialog.showToast('UP 主信息不完整');
      return;
    }
    final MemberController memberController = Get.put<MemberController>(
      MemberController(mid: mid),
      tag: mid.toString(),
    );
    await memberController.getInfo();
    if (context.mounted) await memberController.actionRelationMod(context);
    followStatus['attribute'] = memberController.attribute.value;
    followStatus.refresh();
    Get.delete<MemberController>(tag: mid.toString());
  }

  // 修改分P或番剧分集
  Future changeSeasonOrbangu(bvid, cid, aid) async {
    // 重新获取视频资源
    final VideoDetailController videoDetailCtr =
        Get.find<VideoDetailController>(tag: heroTag);
    videoDetailCtr.bvid = bvid;
    videoDetailCtr.oid.value = aid ?? IdUtils.bv2av(bvid);
    videoDetailCtr.cid.value = cid;
    videoDetailCtr.danmakuCid.value = cid;
    videoDetailCtr.queryVideoUrl();
    // 重新请求相关视频
    try {
      final RelatedController relatedCtr = Get.find<RelatedController>(
        tag: heroTag,
      );
      relatedCtr.bvid = bvid;
      relatedCtr.queryRelatedVideo();
    } catch (_) {}
    // 重新请求评论
    try {
      final VideoReplyController videoReplyCtr = Get.find<VideoReplyController>(
        tag: heroTag,
      );
      videoReplyCtr.aid = aid;
      videoReplyCtr.queryReplyList(type: 'init');
    } catch (_) {}
    this.bvid = bvid;
    lastPlayCid.value = cid;
    playbackQueueController.syncCurrent(bvid: bvid, cid: cid);
    queryVideoIntro();
  }

  void startTimer() {
    if (isOffline) return;
    const duration = Duration(seconds: 10); // 设置定时器间隔为10秒
    timer = Timer.periodic(duration, (Timer timer) {
      if (!isPaused) {
        queryOnlineTotal(); // 定时器回调函数，发起请求
      }
    });
  }

  // 查看同时在看人数
  Future queryOnlineTotal() async {
    if (isOffline) return;
    var result = await VideoHttp.onlineTotal(
      aid: IdUtils.bv2av(bvid),
      bvid: bvid,
      cid: lastPlayCid.value,
    );
    if (result case ApiSuccess<VideoOnlineTotal>(:final data)) {
      total.value = data.total;
    }
  }

  @override
  void onClose() {
    if (timer != null) {
      timer!.cancel(); // 销毁页面时取消定时器
    }
    super.onClose();
  }

  /// 播放上一个
  bool prevPlay() {
    if (!playbackQueueController.hasPrevious.value) {
      return false;
    }
    unawaited(playbackQueueController.playPrevious());
    return true;
  }

  // 是否有下一集（支持分p、合集、稍后再看与自动连播）
  bool hasNextEpisode() {
    return playbackQueueController.hasNext.value;
  }

  /// 列表循环或者顺序播放时，自动播放下一个
  bool nextPlay({bool autoTriggered = false}) {
    if (!playbackQueueController.hasNext.value &&
        PlPlayerController.getInstance().playRepeat != PlayRepeat.listCycle) {
      return false;
    }
    unawaited(playbackQueueController.playNext(autoTriggered: autoTriggered));
    return true;
  }

  bool playRelated() {
    late RelatedController relatedCtr;
    try {
      relatedCtr = Get.find<RelatedController>(tag: heroTag);
      if (relatedCtr.relatedVideoList.isEmpty) {
        SmartDialog.showToast('暂无相关视频，停止连播');
        return false;
      }
    } catch (_) {
      relatedCtr = Get.put(RelatedController(), tag: heroTag);
      relatedCtr.queryRelatedVideo().then((value) {
        if (value is ApiSuccess<List<HotVideoItemModel>>) {
          playRelated();
        }
      });
      return false;
    }

    final HotVideoItemModel relatedVideoItem = relatedCtr.relatedVideoList[0];
    if (PlPlayerController.getInstance().isFullScreen.value) {
      PlPlayerController.getInstance().toggleFullScreen(false);
    }
    try {
      if (relatedVideoItem.cid != null) {
        Get.offNamed(
          '/video?bvid=${relatedVideoItem.bvid}&cid=${relatedVideoItem.cid}',
          arguments: {'videoItem': relatedVideoItem, 'heroTag': heroTag},
        );
        // changeSeasonOrbangu(relatedVideoItem.bvid, relatedVideoItem.cid, relatedVideoItem.aid);
      } else {
        SearchHttp.ab2c(
          aid: relatedVideoItem.aid,
          bvid: relatedVideoItem.bvid,
        ).then((cidResult) {
          if (cidResult case ApiFailure<int>(:final message)) {
            SmartDialog.showToast(message);
            return;
          }
          final cid = (cidResult as ApiSuccess<int>).data;
          Get.offNamed(
            '/video?bvid=${relatedVideoItem.bvid}&cid=$cid',
            arguments: {'videoItem': relatedVideoItem, 'heroTag': heroTag},
          );
        });
      }
    } catch (err) {
      SmartDialog.showToast(err.toString());
    }
    return true;
  }

  // ai总结
  Future<ApiResult<AiConclusionModel>> aiConclusion() async {
    SmartDialog.showLoading(msg: '正在查询AI总结');
    final res = await VideoHttp.aiConclusion(
      bvid: bvid,
      cid: lastPlayCid.value,
      upMid: videoDetail.value.owner?.mid,
    );
    SmartDialog.dismiss();
    if (res is ApiFailure<AiConclusionModel>) {
      SmartDialog.showNotify(
        msg: "当前视频暂未生产AI视频总结",
        notifyType: NotifyType.warning,
        displayTime: const Duration(seconds: 1),
      );
    }
    return res;
  }
}

import 'package:pilipalaz/utils/extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/models/rcmd_video_item.dart';
import 'package:pilipalaz/pages/rcmd/refresh_merge.dart';
import 'package:pilipalaz/utils/storage.dart';

class RcmdController extends GetxController {
  final ScrollController scrollController = ScrollController();
  int _currentPage = 0;
  // RxList<RecVideoItemAppModel> appVideoList = <RecVideoItemAppModel>[].obs;
  // RxList<RecVideoItemModel> webVideoList = <RecVideoItemModel>[].obs;
  Box setting = GStorage.setting;
  RxInt crossAxisCount = 2.obs;
  final RxnInt lastSeenIndex = RxnInt();
  final RxList<RcmdVideoItem> videoList = <RcmdVideoItem>[].obs;
  late bool enableSaveLastData;
  late String defaultRcmdType = 'web';

  @override
  void onInit() {
    super.onInit();
    enableSaveLastData = setting.get(
      SettingBoxKey.enableSaveLastData,
      defaultValue: false,
    );
    defaultRcmdType = setting.get(
      SettingBoxKey.defaultRcmdType,
      defaultValue: 'web',
    );
  }

  // 获取推荐
  Future<Map<String, dynamic>> queryRcmdFeed(String type) async {
    if (type == 'onRefresh') {
      _currentPage = 0;
    }
    late final Map<String, dynamic> res;
    switch (defaultRcmdType) {
      case 'app':
      case 'notLogin':
        res = await VideoHttp.rcmdVideoListApp(
          loginStatus: defaultRcmdType != 'notLogin',
          freshIdx: _currentPage,
        );
        break;
      default: //'web'
        res = await VideoHttp.rcmdVideoList(freshIdx: _currentPage, ps: 20);
    }
    if (res['status']) {
      final videos = List<RcmdVideoItem>.from(res['data'] as Iterable);
      if (type == 'init') {
        lastSeenIndex.value = null;
        if (videoList.isNotEmpty) {
          videoList.addAll(videos);
        } else {
          videoList.assignAll(videos);
        }
      } else if (type == 'onRefresh') {
        final refreshMerge = mergeRcmdRefresh<RcmdVideoItem>(
          currentVideos: videoList,
          refreshedVideos: videos,
          preserveCurrent: enableSaveLastData,
        );
        videoList.assignAll(refreshMerge.videos);
        lastSeenIndex.value = refreshMerge.lastSeenIndex;
      } else if (type == 'onLoad') {
        videoList.addAll(videos);
      }
      _currentPage += 1;
      // 若videoList数量太小，可能会影响翻页，此时再次请求
      // 为避免请求到的数据太少时还在反复请求，要求本次返回数据大于1条才触发
      if (videos.length > 1 && videoList.length < 24) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (videoList.length < 24) queryRcmdFeed('onLoad');
        });
      }
      if (videos.length < 5) {
        SmartDialog.showToast("仅请求到${videos.length}条");
      }
    } else {
      SmartDialog.showToast("${res['msg']}，请尝试(重新)登录");
    }
    return res;
  }

  // 下拉刷新
  Future<Map<String, dynamic>> onRefresh() => queryRcmdFeed('onRefresh');

  // 上拉加载
  Future<Map<String, dynamic>> onLoad() => queryRcmdFeed('onLoad');

  // 返回顶部
  void animateToTop() {
    scrollController.animToTop();
  }
}

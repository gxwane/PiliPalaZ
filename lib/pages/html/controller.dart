import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/html.dart';
import 'package:pilipalaz/http/reply.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/video/reply/data.dart';
import 'package:pilipalaz/models/common/reply_sort_type.dart';
import 'package:pilipalaz/models/video/reply/item.dart';
import 'package:pilipalaz/utils/feed_back.dart';
import 'package:pilipalaz/utils/storage.dart';

class HtmlRenderController extends GetxController {
  late String id;
  late String dynamicType;
  late int type;
  RxInt oid = (-1).obs;
  late Map response;
  int? floor;
  String nextOffset = "";
  bool isLoadingMore = false;
  RxString noMore = ''.obs;
  RxList<ReplyItemModel> replyList = <ReplyItemModel>[].obs;
  RxInt acount = 0.obs;
  final ScrollController scrollController = ScrollController();

  late ReplySortType _sortType;
  late RxString sortTypeTitle;
  late RxString sortTypeLabel;
  Box setting = GStorage.setting;

  @override
  void onInit() {
    super.onInit();
    id = Get.parameters['id']!;
    dynamicType = Get.parameters['dynamicType']!;
    type = dynamicType == 'picture' ? 11 : 12;
    int defaultReplySortIndex =
        setting.get(SettingBoxKey.replySortType, defaultValue: 0) as int;
    if (defaultReplySortIndex == 2) {
      setting.put(SettingBoxKey.replySortType, 0);
      defaultReplySortIndex = 0;
    }
    _sortType = ReplySortType.values[defaultReplySortIndex];
    sortTypeLabel = _sortType.labels.obs;
    sortTypeTitle = _sortType.titles.obs;
  }

  // 请求动态内容
  Future reqHtml(id) async {
    late dynamic res;
    if (dynamicType == 'opus' || dynamicType == 'picture') {
      res = await HtmlHttp.reqHtml(id, dynamicType);
    } else {
      res = await HtmlHttp.reqReadHtml(id, dynamicType);
    }
    response = res;
    oid.value = res['commentId'];
    queryReplyList(reqType: 'init');
    return res;
  }

  // 请求评论
  Future queryReplyList({reqType = 'init'}) async {
    if (reqType == 'init') {
      nextOffset = "";
      noMore.value = "";
    }
    if (noMore.value == '没有更多了') return;
    var res = await ReplyHttp.replyList(
      oid: oid.value,
      nextOffset: nextOffset,
      type: type,
      sort: _sortType.index,
    );
    if (res case ApiSuccess<ReplyData>(:final data)) {
      List<ReplyItemModel> replies = data.replies ?? <ReplyItemModel>[];
      acount.value = data.cursor?.allCount ?? 0;
      nextOffset = data.cursor?.paginationReply?.nextOffset ?? "";
      if (replies.isNotEmpty) {
        noMore.value = '加载中...';
        if (data.cursor?.isEnd == true) {
          noMore.value = '没有更多了';
        }
      } else {
        noMore.value =
            nextOffset == "" && reqType == 'init' ? '还没有评论' : '没有更多了';
      }
      if (reqType == 'init') {
        // 添加置顶回复
        if (data.upper?.top != null) {
          bool flag = (data.topReplies ?? <ReplyItemModel>[]).any(
            (reply) => reply.rpid == data.upper!.top!.rpid,
          );
          if (!flag) {
            replies.insert(0, data.upper!.top!);
          }
        }
        replies.insertAll(0, data.topReplies ?? <ReplyItemModel>[]);
        replyList.value = replies;
      } else {
        replyList.addAll(replies);
      }
    } else {
      SmartDialog.showToast((res as ApiFailure<ReplyData>).message);
    }
    isLoadingMore = false;
    return res;
  }

  // 排序搜索评论
  queryBySort() {
    feedBack();
    switch (_sortType) {
      case ReplySortType.time:
        _sortType = ReplySortType.like;
        break;
      case ReplySortType.like:
        _sortType = ReplySortType.time;
        break;
    }
    sortTypeTitle.value = _sortType.titles;
    sortTypeLabel.value = _sortType.labels;
    nextOffset = "";
    replyList.clear();
    queryReplyList(reqType: 'init');
  }
}

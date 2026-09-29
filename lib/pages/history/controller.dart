import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/user/history.dart';
import 'package:pilipalaz/utils/storage.dart';

class HistoryController extends GetxController {
  final ScrollController scrollController = ScrollController();
  RxList<HisListItem> historyList = <HisListItem>[].obs;
  RxBool isLoadingMore = false.obs;
  RxBool pauseStatus = false.obs;
  Box localCache = GStorage.localCache;
  RxBool isLoading = false.obs;
  RxBool enableMultiple = false.obs;
  RxInt checkedCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    historyStatus();
  }

  Future<ApiResult<HistoryData>> queryHistoryList({type = 'init'}) async {
    int max = 0;
    int viewAt = 0;
    if (type == 'onload') {
      max = historyList.last.history!.oid!;
      viewAt = historyList.last.viewAt!;
    }
    isLoadingMore.value = true;
    var res = await UserHttp.historyList(max, viewAt);
    isLoadingMore.value = false;
    if (res case ApiSuccess<HistoryData>(:final data)) {
      if (type == 'onload') {
        historyList.addAll(data.list ?? <HisListItem>[]);
      } else {
        historyList.value = data.list ?? <HisListItem>[];
      }
    }
    return res;
  }

  Future onLoad() async {
    queryHistoryList(type: 'onload');
  }

  Future onRefresh() async {
    queryHistoryList(type: 'onRefresh');
  }

  // 暂停观看历史
  Future onPauseHistory(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(
            !pauseStatus.value ? '啊叻？你要暂停历史记录功能吗？' : '啊叻？要恢复历史记录功能吗？',
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                SmartDialog.showLoading(msg: '请求中');
                var res = await UserHttp.pauseHistory(!pauseStatus.value);
                SmartDialog.dismiss();
                if (res is ApiSuccess<void>) {
                  SmartDialog.showToast(
                    !pauseStatus.value ? '暂停观看历史' : '恢复观看历史',
                  );
                  pauseStatus.value = !pauseStatus.value;
                  localCache.put(LocalCacheKey.historyPause, pauseStatus.value);
                }
                Get.back();
              },
              child: Text(!pauseStatus.value ? '确认暂停' : '确认恢复'),
            ),
          ],
        );
      },
    );
  }

  // 观看历史暂停状态
  Future historyStatus() async {
    var res = await UserHttp.historyStatus();
    if (res case ApiSuccess<bool>(:final data)) {
      pauseStatus.value = data;
      localCache.put(LocalCacheKey.historyPause, data);
    } else {
      SmartDialog.showToast((res as ApiFailure<bool>).message);
    }
  }

  // 解析资源 kid 前缀标识（如 archive_xxx, live_xxx, article_xxx, pgc_xxx）
  static String resolveResourceKid(dynamic kid, String? business) {
    final String kidStr = kid.toString();
    if (kidStr.contains('_')) {
      return kidStr;
    }
    final String b = (business ?? 'archive').toLowerCase().trim();
    if (b.isEmpty) {
      return 'archive_$kidStr';
    }
    if (b == 'live') {
      return 'live_$kidStr';
    }
    if (b.contains('article')) {
      return 'article_$kidStr';
    }
    if (b == 'pgc') {
      return 'pgc_$kidStr';
    }
    return '${b}_$kidStr';
  }

  // 批量并发分块删除历史记录，保证 SmartDialog.dismiss 安全退出及原子批量刷新
  Future<int> _batchDeleteHistory(
    List<HisListItem> items, {
    String? loadingMsg,
  }) async {
    if (items.isEmpty) return 0;
    SmartDialog.showLoading(msg: loadingMsg ?? '请求中');
    final Set<dynamic> successfullyDeleted = <dynamic>{};
    try {
      const int chunkSize = 5;
      for (int i = 0; i < items.length; i += chunkSize) {
        final chunk = items.sublist(i, min(i + chunkSize, items.length));
        final results = await Future.wait(
          chunk.map((item) async {
            final String resKid = resolveResourceKid(
              item.kid,
              item.history?.business,
            );
            final res = await UserHttp.delHistory(resKid);
            if (res is ApiSuccess<void>) {
              return item.kid;
            }
            return null;
          }),
        );
        for (final k in results) {
          if (k != null) {
            successfullyDeleted.add(k);
          }
        }
      }
    } finally {
      SmartDialog.dismiss();
    }

    if (successfullyDeleted.isNotEmpty) {
      historyList.removeWhere((e) => successfullyDeleted.contains(e.kid));
      checkedCount.value = 0;
      enableMultiple.value = false;
      SmartDialog.showToast('已成功清理 ${successfullyDeleted.length} 条记录');
    } else {
      SmartDialog.showToast('清理失败，请重试');
    }
    return successfullyDeleted.length;
  }

  // 清空观看历史
  Future onClearHistory(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('啊叻？你要清空历史记录功能吗？'),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                SmartDialog.showLoading(msg: '请求中');
                ApiResult<void>? res;
                try {
                  res = await UserHttp.clearHistory();
                } finally {
                  SmartDialog.dismiss();
                }
                if (res is ApiSuccess<void>) {
                  SmartDialog.showToast('清空观看历史');
                  historyList.clear();
                } else if (res is ApiFailure<void>) {
                  SmartDialog.showToast(res.message);
                }
                Get.back();
              },
              child: const Text('确认清空'),
            ),
          ],
        );
      },
    );
  }

  // 删除某条历史记录
  Future delHistory(kid, business) async {
    final String resKid = resolveResourceKid(kid, business?.toString());
    var res = await UserHttp.delHistory(resKid);
    if (res is ApiSuccess<void>) {
      historyList.removeWhere((e) => e.kid == kid);
      SmartDialog.showToast('已删除');
    } else {
      SmartDialog.showToast((res as ApiFailure<void>).message);
    }
  }

  // 删除已看历史记录
  Future onDelHistory() async {
    final List<HisListItem> result = historyList
        .where((e) => e.progress == -1)
        .toList();
    if (result.isEmpty) {
      SmartDialog.showToast('暂无已看完的历史记录');
      return;
    }
    await _batchDeleteHistory(result, loadingMsg: '正在清理已看记录...');
  }

  // 删除选中的记录
  Future onDelCheckedHistory(BuildContext context) async {
    final List<HisListItem> result = historyList
        .where((e) => e.checked == true)
        .toList();
    if (result.isEmpty) {
      SmartDialog.showToast('未选择任何历史记录');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text('确认删除所选 ${result.length} 条历史记录吗？'),
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
                Get.back();
                await _batchDeleteHistory(result, loadingMsg: '正在删除所选记录...');
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }
}

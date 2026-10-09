import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:pilipalaz/http/danmaku.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';
import 'package:pilipalaz/services/download/offline_danmaku_service.dart';

import '../../utils/storage.dart';

class PlDanmakuController {
  final int cid;
  final bool isOffline;
  static int danmakuWeight = 0;
  static List<Map<String, dynamic>> danmakuFilter = [];
  // 按类型屏蔽弹幕转为滚动弹幕
  static bool convertToScrollDanmaku = true;
  PlDanmakuController(this.cid, {this.isOffline = false}) {
    refresh();
  }

  Map<int, List<DanmakuElem>> dmSegMap = {};
  // 已请求的段落标记
  List<bool> requestedSeg = [];
  bool _disposed = false;

  /// 本地已即时发射/渲染过的弹幕 ID 集合，避免帧监听二次重复渲染
  final Set<String> renderedLocalDanmakuIds = <String>{};

  /// 暂停状态下自发待发射的弹幕队列（起播瞬间即刻推流）
  final List<DanmakuElem> pendingLocalDanmakus = <DanmakuElem>[];

  bool get initiated => requestedSeg.isNotEmpty;

  static int segmentLength = 60 * 6 * 1000;

  static void refresh() {
    try {
      danmakuWeight = GStorage.setting.get(
        SettingBoxKey.danmakuWeight,
        defaultValue: 0,
      );
      danmakuFilter = GStorage.onlineCache
          .get(OnlineCacheKey.danmakuFilterRule, defaultValue: [])
          .map<Map<String, dynamic>>((e) {
            return Map<String, dynamic>.from(e);
          })
          .toList();
      convertToScrollDanmaku = GStorage.setting.get(
        SettingBoxKey.convertToScrollDanmaku,
        defaultValue: true,
      );
    } catch (_) {}
  }

  void initiate(
    int videoDuration,
    int progress, {
    File? offlineDanmakuFile,
  }) async {
    if (videoDuration <= 0) {
      return;
    }
    if (requestedSeg.isEmpty) {
      int segCount = (videoDuration / segmentLength).ceil();
      requestedSeg = List<bool>.generate(segCount, (index) => false);
    }
    if (isOffline) {
      if (offlineDanmakuFile != null && await offlineDanmakuFile.exists()) {
        await loadOfflineDanmaku(offlineDanmakuFile);
      }
      for (int i = 0; i < requestedSeg.length; i++) {
        requestedSeg[i] = true;
      }
      return;
    }
    if (offlineDanmakuFile != null && await offlineDanmakuFile.exists()) {
      final bool loaded = await loadOfflineDanmaku(offlineDanmakuFile);
      if (loaded) return;
    }
    queryDanmaku(calcSegment(progress));
  }

  /// 装载本地离线弹幕文件
  Future<bool> loadOfflineDanmaku(File danmakuFile) async {
    final DmSegMobileReply? reply =
        await OfflineDanmakuService.loadDanmakuFromFile(danmakuFile);
    if (reply == null || reply.elems.isEmpty) {
      return false;
    }
    for (final element in reply.elems) {
      final int pos = element.progress ~/ 100;
      dmSegMap[pos] ??= [];
      final int i = dmSegMap[pos]!.indexWhere((e) => element.weight > e.weight);
      if (i > 0) {
        dmSegMap[pos]!.insert(i, element);
      } else {
        dmSegMap[pos]!.add(element);
      }
    }
    for (int i = 0; i < requestedSeg.length; i++) {
      requestedSeg[i] = true;
    }
    return true;
  }

  /// 本地自发弹幕注入方法：写入分片 Map，保证重播与 Seek 可回溯
  DanmakuElem addLocalDanmaku({
    required String message,
    required int color,
    required int mode,
    required int progress,
    int fontsize = 25,
    bool markAsRendered = false,
  }) {
    final String localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final elem = DanmakuElem(
      idStr: localId,
      content: message,
      color: color,
      mode: mode,
      progress: progress,
      fontsize: fontsize,
      weight: 100, // 高权重确保不被权重过滤拦截
      ctime: Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    final int pos = progress ~/ 100;
    dmSegMap[pos] ??= [];
    dmSegMap[pos]!.insert(0, elem);

    if (markAsRendered) {
      renderedLocalDanmakuIds.add(localId);
    } else {
      pendingLocalDanmakus.add(elem);
    }
    return elem;
  }

  /// 消费并清空所有待发射的暂停自发弹幕，并将其标记为已渲染以防止随后的帧监听重复发射
  List<DanmakuElem> drainPendingLocalDanmakus() {
    if (pendingLocalDanmakus.isEmpty) return const [];
    final items = List<DanmakuElem>.from(pendingLocalDanmakus);
    pendingLocalDanmakus.clear();
    for (final e in items) {
      renderedLocalDanmakuIds.add(e.idStr);
    }
    return items;
  }

  void dispose() {
    _disposed = true;
    danmakuFilter.clear();
    dmSegMap.clear();
    requestedSeg.clear();
    renderedLocalDanmakuIds.clear();
    pendingLocalDanmakus.clear();
  }

  int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  void queryDanmaku(int segmentIndex) async {
    if (_disposed ||
        isOffline ||
        segmentIndex < 0 ||
        requestedSeg.length <= segmentIndex) {
      return;
    }
    assert(requestedSeg[segmentIndex] == false);
    requestedSeg[segmentIndex] = true;
    final result = await DanmakuApi.instance.queryDanmaku(
      cid: cid,
      segmentIndex: segmentIndex + 1,
    );
    if (_disposed) return;
    if (result case ApiFailure<DmSegMobileReply>()) {
      requestedSeg[segmentIndex] = false;
      return;
    }
    final reply = (result as ApiSuccess<DmSegMobileReply>).data;
    if (reply.elems.isNotEmpty) {
      for (var element in reply.elems) {
        int pos = element.progress ~/ 100; //每0.1秒存储一次
        dmSegMap[pos] ??= [];
        int i = dmSegMap[pos]!.indexWhere((e) => element.weight > e.weight);
        if (i > 0) {
          dmSegMap[pos]!.insert(i, element);
        } else {
          dmSegMap[pos]!.add(element);
        }
      }
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    int segmentIndex = calcSegment(progress);
    if (requestedSeg.length <= segmentIndex) {
      return <DanmakuElem>[];
    }
    if (!requestedSeg[segmentIndex]) {
      queryDanmaku(segmentIndex);
    }
    if (danmakuWeight == 0 && danmakuFilter.isEmpty) {
      return dmSegMap[progress ~/ 100];
    } else {
      return dmSegMap[progress ~/ 100]
          ?.where((element) => element.weight >= danmakuWeight)
          .where(filterDanmaku)
          .toList();
    }
  }

  bool filterDanmaku(DanmakuElem elem) {
    for (var filter in danmakuFilter) {
      switch (filter['type']) {
        case 0:
          if (elem.content.contains(filter['filter'])) {
            return false;
          }
          break;
        case 1:
          if (RegExp(filter['filter']).hasMatch(elem.content)) {
            return false;
          }
          break;
        case 2:
          if (elem.idStr == filter['filter']) {
            return false;
          }
          break;
      }
    }
    return true;
  }
}

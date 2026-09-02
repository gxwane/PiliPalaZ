import 'package:pilipalaz/http/danmaku.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';

import '../../utils/storage.dart';

class PlDanmakuController {
  final int cid;
  static int danmakuWeight = 0;
  static List<Map<String, dynamic>> danmakuFilter = [];
  // 按类型屏蔽弹幕转为滚动弹幕
  static bool convertToScrollDanmaku = true;
  PlDanmakuController(this.cid) {
    refresh();
  }

  Map<int, List<DanmakuElem>> dmSegMap = {};
  // 已请求的段落标记
  List<bool> requestedSeg = [];
  bool _disposed = false;

  bool get initiated => requestedSeg.isNotEmpty;

  static int segmentLength = 60 * 6 * 1000;

  static void refresh() {
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
  }

  void initiate(int videoDuration, int progress) {
    if (videoDuration <= 0) {
      return;
    }
    if (requestedSeg.isEmpty) {
      int segCount = (videoDuration / segmentLength).ceil();
      requestedSeg = List<bool>.generate(segCount, (index) => false);
    }
    queryDanmaku(calcSegment(progress));
  }

  void dispose() {
    _disposed = true;
    danmakuFilter.clear();
    dmSegMap.clear();
    requestedSeg.clear();
  }

  int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  void queryDanmaku(int segmentIndex) async {
    if (_disposed || segmentIndex < 0 || requestedSeg.length <= segmentIndex) {
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

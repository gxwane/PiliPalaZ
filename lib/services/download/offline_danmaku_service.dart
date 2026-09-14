/// 离线弹幕下载与持久化服务。
///
/// 批量拉取视频各段 Protobuf 弹幕并合并序列化为单一二进制文件。
library;

import 'dart:io';

import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/danmaku.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';

/// 弹幕段落拉取函数类型，便于依赖注入与测试。
typedef DanmakuFetcher =
    Future<ApiResult<DmSegMobileReply>> Function({
      required int cid,
      required int segmentIndex,
    });

/// 离线弹幕下载与装载服务。
class OfflineDanmakuService {
  OfflineDanmakuService({
    DanmakuApi? danmakuApi,
    DanmakuFetcher? danmakuFetcher,
  }) : _danmakuFetcher =
           danmakuFetcher ?? (danmakuApi ?? DanmakuApi.instance).queryDanmaku;

  final DanmakuFetcher _danmakuFetcher;

  /// 单段弹幕时长（毫秒）：6 分钟 = 360,000 毫秒。
  static const int segmentDurationMs = 60 * 6 * 1000;

  /// 计算指定时长（秒）对应的弹幕分段数。
  static int calculateSegmentCount(int durationSeconds) {
    if (durationSeconds <= 0) return 1;
    final int durationMs = durationSeconds * 1000;
    return (durationMs / segmentDurationMs).ceil().clamp(1, 1000);
  }

  /// 下载并持久化指定 cid 的全部弹幕数据。
  ///
  /// [duration] 视频时长（秒）。
  /// [targetFile] 本地目标文件（如 `.../danmaku.bin`）。
  ///
  /// 批量拉取全部段落，聚合为单一 [DmSegMobileReply]，
  /// 调用 `writeToBuffer()` 写入本地文件。
  Future<bool> downloadDanmaku({
    required int cid,
    required int duration,
    required File targetFile,
  }) async {
    try {
      final int segCount = calculateSegmentCount(duration);
      final List<DanmakuElem> allElems = <DanmakuElem>[];

      for (int i = 1; i <= segCount; i++) {
        final ApiResult<DmSegMobileReply> result = await _danmakuFetcher(
          cid: cid,
          segmentIndex: i,
        );

        if (result case ApiSuccess<DmSegMobileReply>(:final data)) {
          if (data.elems.isNotEmpty) {
            allElems.addAll(data.elems);
          }
        }
      }

      final DmSegMobileReply consolidated = DmSegMobileReply(elems: allElems);
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(consolidated.writeToBuffer(), flush: true);
      return true;
    } on Object {
      return false;
    }
  }

  /// 从本地二进制文件读取离线弹幕。
  ///
  /// 若文件不存在或损坏返回 `null`。
  static Future<DmSegMobileReply?> loadDanmakuFromFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final List<int> bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return DmSegMobileReply.fromBuffer(bytes);
    } on Object {
      return null;
    }
  }
}

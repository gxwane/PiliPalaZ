import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';
import 'package:pilipalaz/services/download/offline_danmaku_service.dart';

void main() {
  group('OfflineDanmakuService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('offline_dm_test_');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('calculateSegmentCount 正确计算分段并遵守 30 段上限', () {
      expect(OfflineDanmakuService.calculateSegmentCount(0), equals(1));
      expect(OfflineDanmakuService.calculateSegmentCount(-10), equals(1));
      expect(
        OfflineDanmakuService.calculateSegmentCount(360),
        equals(1),
      ); // 6 分钟
      expect(OfflineDanmakuService.calculateSegmentCount(361), equals(2));
      expect(
        OfflineDanmakuService.calculateSegmentCount(720),
        equals(2),
      ); // 12 分钟
      expect(
        OfflineDanmakuService.calculateSegmentCount(3600),
        equals(10),
      ); // 60 分钟
      expect(
        OfflineDanmakuService.calculateSegmentCount(50000),
        equals(30), // 超长视频被限制在 30 段
      );
    });

    test('downloadDanmaku 聚合多段弹幕并写入二进制文件，loadDanmakuFromFile 可正确还原', () async {
      final file = File('${tmpDir.path}/danmaku.bin');

      final service = OfflineDanmakuService(
        danmakuFetcher: ({required int cid, required int segmentIndex}) async {
          final elem = DanmakuElem(
            id: Int64(segmentIndex),
            progress: segmentIndex * 1000,
            content: '弹幕段落 $segmentIndex',
          );
          return ApiSuccess(DmSegMobileReply(elems: [elem]));
        },
      );

      final ok = await service.downloadDanmaku(
        cid: 12345,
        duration: 720, // 2 段
        targetFile: file,
      );

      expect(ok, isTrue);
      expect(file.existsSync(), isTrue);

      final loaded = await OfflineDanmakuService.loadDanmakuFromFile(file);
      expect(loaded, isNotNull);
      expect(loaded!.elems.length, equals(2));
      expect(loaded.elems[0].content, equals('弹幕段落 1'));
      expect(loaded.elems[1].content, equals('弹幕段落 2'));
    });

    test('downloadDanmaku 感知 CancelToken 取消并中止', () async {
      final file = File('${tmpDir.path}/danmaku_cancelled.bin');
      final cancelToken = CancelToken();

      final service = OfflineDanmakuService(
        danmakuFetcher: ({required int cid, required int segmentIndex}) async {
          cancelToken.cancel('user_paused');
          return ApiSuccess(DmSegMobileReply(elems: []));
        },
      );

      final ok = await service.downloadDanmaku(
        cid: 12345,
        duration: 720,
        targetFile: file,
        cancelToken: cancelToken,
      );

      expect(ok, isFalse);
    });

    test('downloadDanmaku 单段异常时平滑降级并继续聚合其余段落', () async {
      final file = File('${tmpDir.path}/danmaku_partial.bin');

      final service = OfflineDanmakuService(
        danmakuFetcher: ({required int cid, required int segmentIndex}) async {
          if (segmentIndex == 1) {
            throw Exception('network error on seg 1');
          }
          final elem = DanmakuElem(
            id: Int64(2),
            progress: 2000,
            content: '段落 2 成功',
          );
          return ApiSuccess(DmSegMobileReply(elems: [elem]));
        },
      );

      final ok = await service.downloadDanmaku(
        cid: 12345,
        duration: 720, // 2 段
        targetFile: file,
      );

      expect(ok, isTrue);
      final loaded = await OfflineDanmakuService.loadDanmakuFromFile(file);
      expect(loaded, isNotNull);
      expect(loaded!.elems.length, equals(1));
      expect(loaded.elems[0].content, equals('段落 2 成功'));
    });
  });
}

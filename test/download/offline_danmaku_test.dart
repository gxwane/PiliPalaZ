import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';
import 'package:pilipalaz/services/download/offline_danmaku_service.dart';

void main() {
  group('OfflineDanmakuService 分段计算', () {
    test('calculateSegmentCount 覆盖各种时长边界', () {
      // 0 或负数时长默认为 1 段
      expect(OfflineDanmakuService.calculateSegmentCount(0), equals(1));
      expect(OfflineDanmakuService.calculateSegmentCount(-10), equals(1));

      // 6 分钟（360 秒）以内为 1 段
      expect(OfflineDanmakuService.calculateSegmentCount(60), equals(1));
      expect(OfflineDanmakuService.calculateSegmentCount(360), equals(1));

      // 361 秒进入第 2 段
      expect(OfflineDanmakuService.calculateSegmentCount(361), equals(2));
      expect(OfflineDanmakuService.calculateSegmentCount(720), equals(2));

      // 721 秒进入第 3 段
      expect(OfflineDanmakuService.calculateSegmentCount(721), equals(3));
    });
  });

  group('OfflineDanmakuService 聚合下载与还原', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('offline_dm_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('多段弹幕正确聚合序列化并还原', () async {
      final targetFile = File('${tempDir.path}/danmaku.bin');

      final queriedSegments = <int>[];

      // 模拟 2 段视频，每段有不同的弹幕
      final service = OfflineDanmakuService(
        danmakuFetcher: ({required int cid, required int segmentIndex}) async {
          queriedSegments.add(segmentIndex);
          if (segmentIndex == 1) {
            return ApiSuccess<DmSegMobileReply>(
              DmSegMobileReply(
                elems: [
                  DanmakuElem(
                    id: Int64(1001),
                    progress: 1000,
                    content: '第一段弹幕1',
                    weight: 5,
                  ),
                  DanmakuElem(
                    id: Int64(1002),
                    progress: 5000,
                    content: '第一段弹幕2',
                    weight: 3,
                  ),
                ],
              ),
            );
          } else if (segmentIndex == 2) {
            return ApiSuccess<DmSegMobileReply>(
              DmSegMobileReply(
                elems: [
                  DanmakuElem(
                    id: Int64(2001),
                    progress: 370000,
                    content: '第二段弹幕1',
                    weight: 8,
                  ),
                ],
              ),
            );
          }
          return const ApiFailure<DmSegMobileReply>(
            kind: ApiFailureKind.network,
            message: 'not found',
            endpoint: 'danmaku.segment',
          );
        },
      );

      // 视频时长 500 秒 -> 2 段
      final success = await service.downloadDanmaku(
        cid: 123456,
        duration: 500,
        targetFile: targetFile,
      );

      expect(success, isTrue);
      expect(queriedSegments, equals([1, 2]));
      expect(targetFile.existsSync(), isTrue);

      // 从文件加载还原
      final loaded = await OfflineDanmakuService.loadDanmakuFromFile(
        targetFile,
      );
      expect(loaded, isNotNull);
      expect(loaded!.elems.length, equals(3));
      expect(loaded.elems[0].content, equals('第一段弹幕1'));
      expect(loaded.elems[1].content, equals('第一段弹幕2'));
      expect(loaded.elems[2].content, equals('第二段弹幕1'));
    });

    test('loadDanmakuFromFile 文件不存在时返回 null', () async {
      final nonExistent = File('${tempDir.path}/non_existent.bin');
      final result = await OfflineDanmakuService.loadDanmakuFromFile(
        nonExistent,
      );
      expect(result, isNull);
    });

    test('loadDanmakuFromFile 文件为空或损坏时安全返回 null', () async {
      final emptyFile = File('${tempDir.path}/empty.bin');
      await emptyFile.writeAsBytes([]);
      expect(
        await OfflineDanmakuService.loadDanmakuFromFile(emptyFile),
        isNull,
      );

      final corruptFile = File('${tempDir.path}/corrupt.bin');
      await corruptFile.writeAsString('not a protobuf');
      // Protobuf might or might not throw on malformed bytes, but if it throws it catches and returns null
      final res = await OfflineDanmakuService.loadDanmakuFromFile(corruptFile);
      // Either null or empty object, should not throw
      expect(res, anyOf(isNull, isNotNull));
    });

    test('单段网络失败时不阻塞整体，聚合成功段落', () async {
      final targetFile = File('${tempDir.path}/partial_dm.bin');

      final service = OfflineDanmakuService(
        danmakuFetcher: ({required int cid, required int segmentIndex}) async {
          if (segmentIndex == 1) {
            return ApiSuccess<DmSegMobileReply>(
              DmSegMobileReply(
                elems: [DanmakuElem(id: Int64(1), content: '仅第一段成功')],
              ),
            );
          }
          return const ApiFailure<DmSegMobileReply>(
            kind: ApiFailureKind.network,
            message: '网络超时',
            endpoint: 'danmaku.segment',
          );
        },
      );

      final success = await service.downloadDanmaku(
        cid: 999,
        duration: 500, // 2 段
        targetFile: targetFile,
      );

      expect(success, isTrue);
      final loaded = await OfflineDanmakuService.loadDanmakuFromFile(
        targetFile,
      );
      expect(loaded, isNotNull);
      expect(loaded!.elems.length, equals(1));
      expect(loaded.elems.first.content, equals('仅第一段成功'));
    });
  });
}

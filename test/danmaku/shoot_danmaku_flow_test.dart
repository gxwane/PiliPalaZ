import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/danmaku/controller.dart';

void main() {
  group('PlDanmakuController Local Injection Tests', () {
    test('addLocalDanmaku properly inserts DanmakuElem into dmSegMap', () {
      final controller = PlDanmakuController(1001, isOffline: true);

      expect(controller.dmSegMap, isEmpty);

      // 插入在进度 15000 毫秒 (15 秒) 处的弹幕
      final elem = controller.addLocalDanmaku(
        message: '前方高能！',
        color: 0xFE0302,
        mode: 1,
        progress: 15000,
        markAsRendered: false,
      );

      expect(elem.content, equals('前方高能！'));
      expect(elem.color, equals(0xFE0302));
      expect(elem.mode, equals(1));
      expect(elem.progress, equals(15000));
      expect(elem.weight, equals(100)); // 高权重确保不被过滤
      expect(elem.idStr, startsWith('local_'));

      // pos = 15000 ~/ 100 = 150
      final pos = 15000 ~/ 100;
      expect(controller.dmSegMap.containsKey(pos), isTrue);
      expect(controller.dmSegMap[pos]!.length, equals(1));
      expect(controller.dmSegMap[pos]!.first.content, equals('前方高能！'));

      // 因为 markAsRendered 为 false，renderedLocalDanmakuIds 应该为空
      expect(controller.renderedLocalDanmakuIds.contains(elem.idStr), isFalse);

      controller.dispose();
      expect(controller.dmSegMap, isEmpty);
      expect(controller.renderedLocalDanmakuIds, isEmpty);
    });

    test(
      'addLocalDanmaku with markAsRendered=true records ID for deduplication',
      () {
        final controller = PlDanmakuController(1002, isOffline: true);

        final elem = controller.addLocalDanmaku(
          message: '即时弹幕测试',
          color: 0xFFFFFF,
          mode: 5,
          progress: 24500,
          markAsRendered: true,
        );

        expect(controller.renderedLocalDanmakuIds.contains(elem.idStr), isTrue);

        // 模拟帧监听读取并消费去重 ID
        final bool removed = controller.renderedLocalDanmakuIds.remove(
          elem.idStr,
        );
        expect(removed, isTrue);
        expect(
          controller.renderedLocalDanmakuIds.contains(elem.idStr),
          isFalse,
        );

        controller.dispose();
      },
    );

    test(
      'multiple local danmakus at same position keep in-order insertion',
      () {
        final controller = PlDanmakuController(1003, isOffline: true);

        final elem1 = controller.addLocalDanmaku(
          message: '弹幕 1',
          color: 0xFFFFFF,
          mode: 1,
          progress: 1000,
        );

        final elem2 = controller.addLocalDanmaku(
          message: '弹幕 2',
          color: 0x00A1D6,
          mode: 4,
          progress: 1000,
        );

        final pos = 1000 ~/ 100;
        expect(controller.dmSegMap[pos]!.length, equals(2));
        // elem2 插入在头部，优先展示
        expect(controller.dmSegMap[pos]!.first, equals(elem2));
        expect(controller.dmSegMap[pos]!.last, equals(elem1));
        expect(controller.dmSegMap[pos]!.first.content, equals('弹幕 2'));
        expect(controller.dmSegMap[pos]!.last.content, equals('弹幕 1'));

        controller.dispose();
      },
    );

    test(
      'paused danmakus enter pendingLocalDanmakus and are drained on resumption',
      () {
        final controller = PlDanmakuController(1004, isOffline: true);

        expect(controller.pendingLocalDanmakus, isEmpty);

        // 暂停状态发射两条弹幕 (markAsRendered: false)
        final e1 = controller.addLocalDanmaku(
          message: '暂停发的第一条',
          color: 0xFE0302,
          mode: 1,
          progress: 15000,
          markAsRendered: false,
        );

        final e2 = controller.addLocalDanmaku(
          message: '暂停发的第二条',
          color: 0x00A1D6,
          mode: 5,
          progress: 15000,
          markAsRendered: false,
        );

        expect(controller.pendingLocalDanmakus.length, equals(2));
        expect(controller.pendingLocalDanmakus, containsAll([e1, e2]));
        expect(controller.renderedLocalDanmakuIds.contains(e1.idStr), isFalse);
        expect(controller.renderedLocalDanmakuIds.contains(e2.idStr), isFalse);

        // 模拟起播瞬间 drain
        final drained = controller.drainPendingLocalDanmakus();
        expect(drained.length, equals(2));
        expect(drained, containsAll([e1, e2]));
        expect(controller.pendingLocalDanmakus, isEmpty);

        // 验证 drain 之后已被登记至 renderedLocalDanmakuIds，避免帧监听二次发射
        expect(controller.renderedLocalDanmakuIds.contains(e1.idStr), isTrue);
        expect(controller.renderedLocalDanmakuIds.contains(e2.idStr), isTrue);

        controller.dispose();
        expect(controller.pendingLocalDanmakus, isEmpty);
        expect(controller.renderedLocalDanmakuIds, isEmpty);
      },
    );
  });
}

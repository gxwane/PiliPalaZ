import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:pilipalaz/utils/danmaku.dart';

void main() {
  group('DmUtils Tests', () {
    test(
      'decimalToColor correctly preserves Alpha 255 for 24-bit RGB values',
      () {
        // 16777215 (0xFFFFFF, White)
        final white = DmUtils.decimalToColor(16777215);
        expect(white.toARGB32(), equals(0xFFFFFFFF));
        expect(white.a, equals(1.0));
        expect(white.r, equals(1.0));
        expect(white.g, equals(1.0));
        expect(white.b, equals(1.0));

        // 0xFE0302 (Red, 16646914)
        final red = DmUtils.decimalToColor(0xFE0302);
        expect(red.toARGB32(), equals(0xFFFE0302));
        expect(red.a, equals(1.0));

        // <= 0 defaults to white
        final zero = DmUtils.decimalToColor(0);
        expect(zero, equals(Colors.white));

        final negative = DmUtils.decimalToColor(-100);
        expect(negative, equals(Colors.white));
      },
    );

    test('colorToDecimal extracts 24-bit RGB integer without alpha', () {
      const color = Color(0xFFFE0302);
      final dec = DmUtils.colorToDecimal(color);
      expect(dec, equals(0xFE0302));

      const white = Color(0xFFFFFFFF);
      expect(DmUtils.colorToDecimal(white), equals(16777215));
    });

    test(
      'decimalToColor and colorToDecimal are mutually inverse for 24-bit RGB',
      () {
        for (final color in DmUtils.standardColors) {
          final int dec = DmUtils.colorToDecimal(color);
          final Color restored = DmUtils.decimalToColor(dec);
          expect(restored.toARGB32(), equals(color.toARGB32()));
        }
      },
    );

    test('standardColors contains 12 unique, valid colors', () {
      expect(DmUtils.standardColors.length, equals(12));
      final uniqueSet = DmUtils.standardColors.map((c) => c.toARGB32()).toSet();
      expect(uniqueSet.length, equals(12));
    });

    test('getPosition and typeToMode correctly map all danmaku modes', () {
      // Mode 1: Scroll
      expect(DmUtils.getPosition(1), equals(DanmakuItemType.scroll));
      expect(DmUtils.typeToMode(DanmakuItemType.scroll), equals(1));

      // Mode 4: Bottom
      expect(DmUtils.getPosition(4), equals(DanmakuItemType.bottom));
      expect(DmUtils.typeToMode(DanmakuItemType.bottom), equals(4));

      // Mode 5: Top
      expect(DmUtils.getPosition(5), equals(DanmakuItemType.top));
      expect(DmUtils.typeToMode(DanmakuItemType.top), equals(5));

      // Other modes fall back to scroll
      expect(DmUtils.getPosition(2), equals(DanmakuItemType.scroll));
      expect(DmUtils.getPosition(3), equals(DanmakuItemType.scroll));
      expect(DmUtils.getPosition(99), equals(DanmakuItemType.scroll));
    });
  });
}

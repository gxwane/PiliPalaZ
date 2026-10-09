import 'package:flutter/material.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';

class DmUtils {
  /// B站标准弹幕 12 种预设色彩
  static const List<Color> standardColors = [
    Color(0xFFFFFFFF), // 纯白
    Color(0xFFFE0302), // 热情红
    Color(0xFFFF7204), // 活力橙
    Color(0xFFFFAA02), // 暖阳黄
    Color(0xFFFFD302), // 柠檬黄
    Color(0xFF00CD00), // 草木绿
    Color(0xFF00D8C9), // 碧青色
    Color(0xFF00A1D6), // 哔哩蓝
    Color(0xFF0168FE), // 深海蓝
    Color(0xFF892FE8), // 幻境紫
    Color(0xFFFE6C9B), // 樱花粉
    Color(0xFF70F3FF), // 极光绿
  ];

  /// 将 B 站 24 位十进制 RGB 颜色转换为 Flutter 32 位 ARGB Color（强制补充 Alpha = 255）
  static Color decimalToColor(int decimalColor) {
    if (decimalColor <= 0) return Colors.white;
    return Color(0xFF000000 | (decimalColor & 0xFFFFFF));
  }

  /// 将 Flutter Color 转换为 B 站 24 位十进制 RGB 整数
  static int colorToDecimal(Color color) {
    return color.toARGB32() & 0xFFFFFF;
  }

  /// 根据 B 站弹幕 mode 映射为 CanvasDanmaku 的 DanmakuItemType
  /// mode: 1-3 滚动，4 底部固定，5 顶部固定
  static DanmakuItemType getPosition(int mode) {
    if (mode == 4) {
      return DanmakuItemType.bottom;
    } else if (mode == 5) {
      return DanmakuItemType.top;
    }
    return DanmakuItemType.scroll;
  }

  /// 根据 DanmakuItemType 映射为 B 站弹幕 mode 编码
  static int typeToMode(DanmakuItemType type) {
    switch (type) {
      case DanmakuItemType.bottom:
        return 4;
      case DanmakuItemType.top:
        return 5;
      case DanmakuItemType.scroll:
        return 1;
    }
  }
}

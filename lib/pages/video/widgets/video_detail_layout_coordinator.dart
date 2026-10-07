import 'dart:math';

/// 视频详情页大屏与响应式布局协调器
///
/// 封装纯 Dart 几何计算与约束钳制逻辑，负责计算左栏宽度、播放器视高安全钳制、
/// 软键盘单侧消费安全阈值与双栏物理宽度门槛。
class VideoDetailLayoutCoordinator {
  const VideoDetailLayoutCoordinator._();

  /// 双栏模式的最小物理宽度门槛（dp），低于此门槛无论是否为平板均自动降级为单栏，防范分屏塌陷。
  static const double minDualColumnWidth = 640.0;

  /// 左栏播放器最大视高占比（62%），确保大屏下播放器下方有充裕垂直空间展示简介、选集与UP主卡片。
  static const double maxPlayerHeightRatio = 0.62;

  /// 左栏占总视宽比例（62%）。
  static const double leftColumnWidthRatio = 0.62;

  /// 右栏在软键盘弹出时必须保留的最小垂直可视滚动高度（dp），防范负向约束与 RenderFlex overflow。
  static const double minRightColumnHeightWithKeyboard = 120.0;

  /// 计算左栏宽度（扣除 1dp 分割线后按 62% 计算）
  static double computeLeftColumnWidth(double maxWidth) {
    if (maxWidth <= 1.0) return 0.0;
    return (maxWidth - 1.0) * leftColumnWidthRatio;
  }

  /// 计算受视高安全钳制的播放器高度
  static double computeClampedPlayerHeight({
    required double maxHeight,
    required double leftWidth,
  }) {
    if (maxHeight <= 0 || leftWidth <= 0) return 0.0;
    final double rawHeight = leftWidth * 9 / 16;
    final double maxHeightLimit = maxHeight * maxPlayerHeightRatio;
    return min(maxHeightLimit, rawHeight);
  }

  /// 计算软键盘在右栏消费的安全高度（保障右栏至少保留 [minRightColumnHeightWithKeyboard] 视口）
  static double computeClampedKeyboardHeight({
    required double rawKeyboardHeight,
    required double maxHeight,
  }) {
    if (rawKeyboardHeight <= 0.0) return 0.0;
    final double maxAllowed = max(
      0.0,
      maxHeight - minRightColumnHeightWithKeyboard,
    );
    return min(rawKeyboardHeight, maxAllowed);
  }

  /// 判定是否满足双栏模式的全部条件（包含物理宽度下限门槛）
  static bool canUseDualColumn({
    required bool isDualColumnFromScreenUtils,
    required double maxWidth,
  }) {
    return isDualColumnFromScreenUtils && maxWidth >= minDualColumnWidth;
  }
}

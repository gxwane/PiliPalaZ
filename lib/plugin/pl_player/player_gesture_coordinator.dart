import 'package:flutter/material.dart';

/// 播放器滑动手势坐标协调器
///
/// 纯 Dart 几何计算与状态算法，负责防误触边缘死区判定、视口行程自适应、动态虚拟锚点折返计算。
class PlayerGestureCoordinator {
  const PlayerGestureCoordinator._();

  /// 顶部边缘死区高度（dp），避让通知栏/控制中心下拉
  static const double topDeadzone = 28.0;

  /// 底部边缘死区高度（dp），避让全面屏手势条与虚拟导航栏
  static const double bottomDeadzone = 24.0;

  /// 全屏侧边边缘死区宽度（dp），避让边缘返回滑动手势
  static const double sideDeadzone = 16.0;

  /// 基础滑动行程下限（dp），避免小视口跳变过快
  static const double minTravel = 280.0;

  /// 基础滑动行程上限（dp），避免大屏/平板需全臂长距离划屏
  static const double maxTravel = 540.0;

  /// 判定触点是否处于防误触边缘死区
  static bool isInsideDeadzone(
    Offset localPoint,
    Size viewportSize, {
    bool isFullScreen = false,
    bool enableDeadzone = true,
  }) {
    if (!enableDeadzone) return false;
    if (viewportSize.isEmpty) return false;

    // 顶部死区
    if (localPoint.dy < topDeadzone) {
      return true;
    }
    // 底部死区
    if (localPoint.dy > viewportSize.height - bottomDeadzone) {
      return true;
    }
    // 全屏时两翼死区
    if (isFullScreen) {
      if (localPoint.dx < sideDeadzone ||
          localPoint.dx > viewportSize.width - sideDeadzone) {
        return true;
      }
    }
    return false;
  }

  /// 计算自适应视口滑动行程（0% 到 100% 音量所需的像素位移）
  static double calculateTravel(
    double viewportHeight, {
    double sensitivity = 1.0,
  }) {
    final double safeSensitivity = sensitivity.clamp(0.5, 2.0);
    final double baseTravel = viewportHeight.clamp(minTravel, maxTravel);
    return baseTravel / safeSensitivity;
  }

  /// 执行动态虚拟锚点算法，计算最新音量并动态推移起始锚点
  ///
  /// 返回最新合法音量 [0.0, 1.0]。若触顶或触底，通过 [onUpdateAnchorY] 回调平移锚点。
  static double computeUpdatedVolume({
    required double currentY,
    required double startY,
    required double startVolume,
    required double travel,
    required ValueChanged<double> onUpdateAnchorY,
  }) {
    if (travel <= 0.0) return startVolume.clamp(0.0, 1.0);
    final double deltaY = currentY - startY;
    final double rawVolume = startVolume - deltaY / travel;

    if (rawVolume > 1.0) {
      final double newStartY = currentY + (1.0 - startVolume) * travel;
      onUpdateAnchorY(newStartY);
      return 1.0;
    } else if (rawVolume < 0.0) {
      final double newStartY = currentY - startVolume * travel;
      onUpdateAnchorY(newStartY);
      return 0.0;
    }

    return rawVolume;
  }
}

import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:pilipalaz/utils/storage.dart';

/// Utilities for responsive screen breakpoints and device form factors.
class ScreenUtils {
  ScreenUtils._();

  /// The standard Android / Material Design breakpoint for tablets and large screens (sw600dp).
  static const double tabletBreakpoint = 600.0;

  /// The desktop / large monitor breakpoint for wide dual-column mode (900dp).
  static const double desktopBreakpoint = 900.0;

  /// Determines if the device is a tablet or large screen without requiring a [BuildContext].
  ///
  /// Uses [PlatformDispatcher.instance.views.firstOrNull] and accounts for headless
  /// environments or uninitialized view states safely.
  static bool isTabletDevice() {
    final FlutterView? view = PlatformDispatcher.instance.views.firstOrNull;
    if (view == null || view.devicePixelRatio <= 0) {
      return false;
    }
    final double shortestSide =
        view.physicalSize.shortestSide / view.devicePixelRatio;
    return shortestSide >= tabletBreakpoint;
  }

  /// Determines if the current context belongs to a tablet / large screen (shortestSide >= 600dp).
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;
  }

  /// Determines if multi-orientation (auto-rotation) should be globally allowed.
  ///
  /// Tablets and large screens allow multi-orientation by default.
  /// Regular phones only allow it if the user explicitly enabled [SettingBoxKey.horizontalScreen].
  static bool shouldEnableMultiOrientation() {
    if (isTabletDevice()) {
      return true;
    }
    try {
      return GStorage.setting.get(
                SettingBoxKey.horizontalScreen,
                defaultValue: false,
              )
              as bool? ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Determines whether the viewport should activate the dual-column landscape layout.
  ///
  /// To protect smartphone users from unintentional squashing when holding a phone
  /// horizontally, dual-column is only enabled on tablets, user-opted horizontalScreen mode,
  /// or large desktop/freeform windows (maxWidth >= 900).
  static bool shouldUseLandscapeDualColumn(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final bool isWide = constraints.maxWidth > constraints.maxHeight * 1.25;
    if (!isWide) {
      return false;
    }
    if (constraints.maxWidth >= desktopBreakpoint) {
      return true;
    }
    if (isTablet(context)) {
      return true;
    }
    try {
      return GStorage.setting.get(
                SettingBoxKey.horizontalScreen,
                defaultValue: false,
              )
              as bool? ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Determines whether the viewport is squarish (e.g. foldables unfolded 8:7 or 4:3 ratio).
  static bool isSquarish(BoxConstraints constraints) {
    if (constraints.maxHeight <= 0) return false;
    final double ratio = constraints.maxWidth / constraints.maxHeight;
    return constraints.maxWidth >= tabletBreakpoint &&
        ratio >= 0.71 &&
        ratio < 1.25;
  }
}

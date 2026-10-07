import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'storage.dart';

class FeedBackUtils {
  static Box<dynamic> get _setting => GStorage.setting;

  static bool get isEnabled =>
      _setting.get(SettingBoxKey.feedBackEnable, defaultValue: false) as bool;

  static void selectionClick() {
    if (isEnabled) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  static void lightImpact() {
    if (isEnabled) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  static void mediumImpact() {
    if (isEnabled) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }
}

void feedBack() {
  FeedBackUtils.lightImpact();
}

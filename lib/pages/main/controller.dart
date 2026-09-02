import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/common/widgets/app_update_center.dart';
import 'package:pilipalaz/http/common.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/pages/dynamics/index.dart';
import 'package:pilipalaz/pages/home/view.dart';
import 'package:pilipalaz/pages/media/index.dart';
import 'package:pilipalaz/utils/storage.dart';
import '../../models/common/dynamic_badge_mode.dart';
import '../../models/common/nav_bar_config.dart';

class MainController extends GetxController {
  List<Widget> pages = <Widget>[
    HomePage(key: GlobalKey()),
    DynamicsPage(key: GlobalKey()),
    MediaPage(key: GlobalKey()),
  ];
  RxList navigationBars = defaultNavigationBars.obs;
  final StreamController<bool> bottomBarStream =
      StreamController<bool>.broadcast();
  Box setting = GStorage.setting;
  DateTime? _lastPressedAt;
  late bool hideTabBar;
  late PageController pageController;
  late int selectedIndex;
  Box userInfoCache = GStorage.userInfo;
  RxBool userLogin = false.obs;
  late DynamicBadgeMode dynamicBadgeType;

  @override
  void onInit() {
    super.onInit();
    unawaited(_initializeAppUpdates());
    hideTabBar = setting.get(SettingBoxKey.hideTabBar, defaultValue: false);
    int defaultHomePage =
        setting.get(SettingBoxKey.defaultHomePage, defaultValue: 0) as int;
    selectedIndex = defaultNavigationBars.indexWhere(
      (item) => item['id'] == defaultHomePage,
    );
    print("selectedIndex: ${selectedIndex}");
    pageController = PageController(initialPage: selectedIndex);
    var userInfo = userInfoCache.get('userInfoCache');
    userLogin.value = userInfo != null;
    dynamicBadgeType =
        DynamicBadgeMode.values[setting.get(
          SettingBoxKey.dynamicBadgeMode,
          defaultValue: DynamicBadgeMode.number.code,
        )];
    if (dynamicBadgeType != DynamicBadgeMode.hidden) {
      getUnreadDynamic();
    }
  }

  Future<void> _initializeAppUpdates() async {
    await AppUpdateCoordinator.instance.initialize();
    if (setting.get(SettingBoxKey.autoUpdate, defaultValue: false)) {
      await AppUpdateCoordinator.instance.checkStableAutomatically();
    }
  }

  void onBackPressed(BuildContext context) {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      // 两次点击时间间隔超过2秒，重新记录时间戳
      _lastPressedAt = DateTime.now();
      if (selectedIndex != 0) {
        pageController.jumpTo(0);
      }
      SmartDialog.showToast("再按一次退出PiliPalaZ");
      return; // 不退出应用
    }
    SystemNavigator.pop(); // 退出应用
  }

  void getUnreadDynamic() async {
    if (!userLogin.value) {
      return;
    }
    int dynamicItemIndex = navigationBars.indexWhere(
      (item) => item['label'] == "动态",
    );
    var res = await CommonHttp.unReadDynamic();
    if (dynamicItemIndex != -1) {
      navigationBars[dynamicItemIndex]['count'] = switch (res) {
        ApiSuccess<List<Map<String, dynamic>>>(:final data) => data.length,
        ApiFailure<List<Map<String, dynamic>>>() => 0,
      };
    }
    navigationBars.refresh();
  }

  void clearUnread() async {
    int dynamicItemIndex = navigationBars.indexWhere(
      (item) => item['label'] == "动态",
    );
    if (dynamicItemIndex != -1) {
      navigationBars[dynamicItemIndex]['count'] = 0; // 修改 count 属性为新的值
    }
    navigationBars.refresh();
  }
}

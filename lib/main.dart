import 'dart:io';

// import 'package:pilipalaz/plugin/pl_player/android_window.dart';

// import 'package:android_window/android_window.dart';
// import 'package:android_window/main.dart' as android_window;
import 'package:pilipalaz/utils/cache_manage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/common/widgets/custom_toast.dart';
import 'package:pilipalaz/http/init.dart';
import 'package:pilipalaz/models/common/color_type.dart';
import 'package:pilipalaz/models/common/theme_type.dart';
import 'package:pilipalaz/pages/search/index.dart';
import 'package:pilipalaz/pages/video/index.dart';
import 'package:pilipalaz/router/app_pages.dart';
import 'package:pilipalaz/pages/main/view.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/app_scheme.dart';
import 'package:pilipalaz/utils/data.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:media_kit/media_kit.dart'; // Provides [Player], [Media], [Playlist] etc.
import 'package:pilipalaz/utils/recommend_filter.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
// import 'package:flutter/scheduler.dart' show timeDilation;

/// mainName must be the same as the method name
// @pragma('vm:entry-point')
// void androidWindow() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   MediaKit.ensureInitialized();
//   await GStorage.init();
//   await setupServiceLocator();
//   Request();
//   await Request.setCookie();
//   runApp(
//     ClipRRect(
//       borderRadius: BorderRadius.circular(12),
//       child: MaterialApp(
//         debugShowCheckedModeBanner: false,
//         theme: ThemeData.light(),
//         darkTheme: ThemeData.dark(),
//         home: const AndroidWindowApp(),
//       ),
//     ),
//   );
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocalDiagnostics.instance.installGlobalErrorHandlers();
  await LocalDiagnostics.instance.initialize();
  MediaKit.ensureInitialized();
  await GStorage.init();
  // timeDilation = 10.0;
  if (GStorage.setting.get(SettingBoxKey.autoClearCache, defaultValue: false)) {
    try {
      await CacheManage.instance.clearApplicationCache();
    } catch (error, stackTrace) {
      debugPrint('Failed to automatically clear application cache: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
  if (GStorage.setting.get(
    SettingBoxKey.horizontalScreen,
    defaultValue: false,
  )) {
    await SystemChrome.setPreferredOrientations(
      //支持竖屏与横屏
      [
        DeviceOrientation.portraitUp,
        // DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
  } else {
    await SystemChrome.setPreferredOrientations(
      //支持竖屏
      [DeviceOrientation.portraitUp],
    );
  }
  await setupServiceLocator();
  Request();
  await Request.setCookie();
  RecommendFilter();
  SmartDialog.config.toast = SmartConfigToast(
    displayType: SmartToastType.onlyRefresh,
  );
  runApp(const MyApp());

  // 小白条、导航栏沉浸
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  Data.init();
  PiliScheme.init();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Box setting = GStorage.setting;
    // 主题色
    Color defaultColor =
        colorThemeTypes[setting.get(
          SettingBoxKey.customColor,
          defaultValue: 0,
        )]['color'];
    Color brandColor = defaultColor;
    // 主题模式
    ThemeMode currentThemeValue = ThemeType
        .values[setting.get(
          SettingBoxKey.themeMode,
          defaultValue: ThemeType.system.code,
        )]
        .toThemeMode;
    // 是否动态取色
    bool isDynamicColor = setting.get(
      SettingBoxKey.dynamicColor,
      defaultValue: true,
    );
    // 字体缩放大小
    double textScale = setting.get(
      SettingBoxKey.defaultTextScale,
      defaultValue: 1.0,
    );
    FlexSchemeVariant variant = FlexSchemeVariant
        .values[setting.get(SettingBoxKey.schemeVariant, defaultValue: 10)];

    // 强制设置高帧率
    if (Platform.isAndroid) {
      late List modes;
      FlutterDisplayMode.supported.then((value) {
        modes = value;
        var storageDisplay = setting.get(SettingBoxKey.displayMode);
        DisplayMode f = DisplayMode.auto;
        if (storageDisplay != null) {
          f = modes.firstWhere(
            (e) => e.toString() == storageDisplay,
            orElse: () => f,
          );
        }
        DisplayMode preferred = modes.toList().firstWhere((el) => el == f);
        FlutterDisplayMode.setPreferredMode(preferred);
      });
    }

    return DynamicColorBuilder(
      builder: ((ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme? lightColorScheme;
        ColorScheme? darkColorScheme;
        if (lightDynamic != null && darkDynamic != null && isDynamicColor) {
          // dynamic取色成功
          // lightColorScheme = lightDynamic.harmonized();
          // darkColorScheme = darkDynamic.harmonized();
          lightColorScheme = SeedColorScheme.fromSeeds(
            primaryKey: lightDynamic.primary,
            brightness: Brightness.light,
            variant: variant,
            useExpressiveOnContainerColors: false,
          );
          darkColorScheme = SeedColorScheme.fromSeeds(
            primaryKey: darkDynamic.primary,
            brightness: Brightness.dark,
            variant: variant,
            useExpressiveOnContainerColors: false,
          );
        } else {
          // dynamic取色失败，采用品牌色
          lightColorScheme = SeedColorScheme.fromSeeds(
            primaryKey: brandColor,
            brightness: Brightness.light,
            variant: variant,
            useExpressiveOnContainerColors: false,
          );
          darkColorScheme = SeedColorScheme.fromSeeds(
            primaryKey: brandColor,
            brightness: Brightness.dark,
            variant: variant,
            useExpressiveOnContainerColors: false,
          );
        }
        // 图片缓存
        // PaintingBinding.instance.imageCache.maximumSizeBytes = 1000 << 20;
        return GetMaterialApp(
          // showSemanticsDebugger: true,
          title: 'PiliPalaZ',
          theme: _getThemeData(
            colorScheme: lightColorScheme,
            isDynamic: lightDynamic != null && isDynamicColor,
            variant: variant,
          ),
          darkTheme: _getThemeData(
            colorScheme: darkColorScheme,
            isDynamic: darkDynamic != null && isDynamicColor,
            isDark: true,
            variant: variant,
          ),
          themeMode: currentThemeValue,
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          locale: const Locale("zh", "CN"),
          supportedLocales: const [Locale("zh", "CN"), Locale("en", "US")],
          fallbackLocale: const Locale("zh", "CN"),
          getPages: Routes.getPages,
          home: const MainApp(),
          builder: (BuildContext context, Widget? child) {
            return FlutterSmartDialog(
              toastBuilder: (String msg) => CustomToast(msg: msg),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
            );
          },
          navigatorObservers: [
            VideoDetailPage.routeObserver,
            SearchPage.routeObserver,
          ],
        );
      }),
    );
  }

  ThemeData _getThemeData({
    required ColorScheme colorScheme,
    required bool isDynamic,
    bool isDark = false,
    required FlexSchemeVariant variant,
  }) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: isDynamic ? null : colorScheme.surface,
        titleTextStyle: TextStyle(fontSize: 16, color: colorScheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        surfaceTintColor: isDynamic ? colorScheme.onSurfaceVariant : null,
      ),
      snackBarTheme: SnackBarThemeData(
        actionTextColor: colorScheme.primary,
        backgroundColor: colorScheme.secondaryContainer,
        closeIconColor: colorScheme.secondary,
        contentTextStyle: TextStyle(color: colorScheme.secondary),
        elevation: 20,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
        },
      ),
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: isDynamic ? colorScheme.onSurfaceVariant : null,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        surfaceTintColor: isDark ? colorScheme.onSurfaceVariant : null,
        shadowColor: Colors.transparent,
      ),
      // dialogTheme: DialogTheme(
      //   surfaceTintColor: isDark ? colorScheme.onSurfaceVariant : null,
      // ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        refreshBackgroundColor: colorScheme.onSecondary,
      ),
    );
  }
}

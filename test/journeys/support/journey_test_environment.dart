import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/http_runtime.dart';
import 'package:pilipalaz/http/pgc.dart';
import 'package:pilipalaz/http/user_api.dart';
import 'package:pilipalaz/http/video_api.dart';
import 'package:pilipalaz/pages/main/view.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/utils/fullscreen.dart';
import 'package:pilipalaz/router/app_pages.dart';
import 'package:pilipalaz/services/audio_handler.dart';
import 'package:pilipalaz/services/auth/auth_session_manager.dart';
import 'package:pilipalaz/services/auth/legacy_credential_source.dart';
import 'package:pilipalaz/services/auth/secure_cookie_jar.dart';
import 'package:pilipalaz/services/auth/webview_session_bridge.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/recommend_filter.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

import '../../services/auth/fake_credential_store.dart';
import '../../support/http_test_harness.dart';
import 'mock_payloads.dart';

bool _storageInitialized = false;
Directory? _tempHiveDir;

final class NoOpWebViewCookieStore implements WebViewCookieStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> setCookie({
    required String name,
    required String value,
    required String domain,
    required String path,
  }) async {}
}

Future<void> initTestStorage() async {
  if (_storageInitialized) return;
  _tempHiveDir = await Directory.systemTemp.createTemp(
    'pilipalaz_journey_test_',
  );
  Hive.init(_tempHiveDir!.path);
  GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
  GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
  GStorage.localCache = await Hive.openBox<dynamic>(StorageBoxName.localCache);
  GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
  GStorage.historyWord = await Hive.openBox<dynamic>(
    StorageBoxName.historyWord,
  );
  GStorage.onlineCache = await Hive.openBox<dynamic>(
    StorageBoxName.onlineCache,
  );
  _storageInitialized = true;
}

Future<void> clearTestStorage() async {
  await GStorage.setting.clear();
  await GStorage.video.clear();
  await GStorage.localCache.clear();
  await GStorage.userInfo.clear();
  await GStorage.historyWord.clear();
  await GStorage.onlineCache.clear();

  await GStorage.setting.put(SettingBoxKey.feedBackEnable, false);
  await GStorage.setting.put(SettingBoxKey.p1080, true);
  await GStorage.setting.put(SettingBoxKey.autoPiP, false);
  await GStorage.setting.put(SettingBoxKey.enableBackgroundPlay, false);
  await GStorage.setting.put(SettingBoxKey.continuePlayInBackground, false);
  await GStorage.setting.put(SettingBoxKey.horizontalScreen, false);
  await GStorage.setting.put(SettingBoxKey.fullScreenMode, 0);
  await GStorage.setting.put(SettingBoxKey.danmakuWeight, 0);
  await GStorage.setting.put(SettingBoxKey.defaultTextScale, 1.0);
  await GStorage.setting.put(SettingBoxKey.dynamicColor, false);
  await GStorage.setting.put(SettingBoxKey.customColor, 0);
}

Future<void> setupJourneyServiceLocator({
  bool mockPlatformChannels = true,
}) async {
  credentialStore = MemoryCredentialStore();
  legacyCredentialSource = HiveLegacyCredentialSource(
    localCache: GStorage.localCache,
  );
  authSessionManager = AuthSessionManager(
    credentialStore: credentialStore,
    legacySource: legacyCredentialSource,
    localState: HiveAuthLocalState(
      localCache: GStorage.localCache,
      userInfo: GStorage.userInfo,
    ),
  );
  secureCookieJar = SecureCookieJar(
    onChanged: authSessionManager.persistCookieSnapshot,
  );
  authSessionManager.registerRuntimeCredentialClear(secureCookieJar.deleteAll);
  webviewSessionBridge = WebViewSessionBridge(
    cookieJar: secureCookieJar,
    webViewCookieStore: NoOpWebViewCookieStore(),
  );
  videoPlayerServiceHandler = VideoPlayerServiceHandler(
    settingBox: GStorage.setting,
  );
  audioSessionHandler = NoOpPlaybackAudioSession();
  RecommendFilter.update();
  if (mockPlatformChannels) {
    _setupTestPlatformChannels();
  }
}

final class NoOpPlaybackAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

void _setupTestPlatformChannels() {
  const MethodChannel packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(packageInfoChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'PiliPalaZ',
            'packageName': 'io.github.gxwane.pilipalaz',
            'version': '1.0.0',
            'buildNumber': '1',
            'buildSignature': '',
          };
        }
        return null;
      });

  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        MethodCall methodCall,
      ) async {
        return _tempHiveDir?.path ?? Directory.systemTemp.path;
      });

  const MethodChannel mediaKitVideoChannel = MethodChannel(
    'com.alexmercerind/media_kit_video',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        mediaKitVideoChannel,
        (MethodCall methodCall) async => null,
      );

  const MethodChannel orientationChannel = MethodChannel(
    'io.github.gxwane.pilipalaz/orientation',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        orientationChannel,
        (MethodCall methodCall) async => null,
      );

  const MethodChannel flPipChannel = MethodChannel('fl_pip');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(flPipChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'available') {
          return false;
        }
        return null;
      });
}

HttpTestHarness setupJourneyHarness({
  HttpTestResponder? responder,
  Map<String, dynamic> Function(RequestOptions)? customHandler,
  bool simulateOffline = false,
  bool simulateTimeout = false,
}) {
  final defaultResponder = (RequestOptions options) => journeyMockDispatcher(
    options,
    customHandler: customHandler,
    simulateOffline: simulateOffline,
    simulateTimeout: simulateTimeout,
  );
  final harness = HttpTestHarness(responder ?? defaultResponder);
  HttpRuntime.setInstanceForTesting(harness.runtime);
  VideoApi.resetForTesting();
  PgcApi.resetForTesting();
  UserApi.resetForTesting();
  return harness;
}

Future<void> boundedPump(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 100),
  int maxSteps = 20,
}) async {
  for (var i = 0; i < maxSteps; i++) {
    await tester.pump(step);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxSteps = 50,
}) async {
  for (var i = 0; i < maxSteps; i++) {
    await tester.pump(step);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('pumpUntil timed out waiting for $finder after $maxSteps steps');
}

Future<void> journeyTearDown([WidgetTester? tester]) async {
  PlPlayerController.isHeadlessTestMode = false;
  stopScreenTimer();
  try {
    SmartDialog.dismiss();
  } catch (_) {}
  try {
    await PlPlayerController.disposeIfExists();
  } catch (_) {}
  if (tester != null) {
    try {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    } catch (_) {}
  }
  Get.reset();
  HttpRuntime.resetForTesting();
  VideoApi.resetForTesting();
  PgcApi.resetForTesting();
  UserApi.resetForTesting();
}

Widget createJourneyTestApp({Widget? home, String? initialRoute, Key? key}) {
  return GetMaterialApp(
    key: key ?? UniqueKey(),
    title: 'PiliPalaZ Journey Test',
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: ThemeMode.light,
    getPages: Routes.getPages,
    home: home ?? const MainApp(),
    initialRoute: initialRoute,
    navigatorObservers: [FlutterSmartDialog.observer],
    builder: FlutterSmartDialog.init(),
  );
}

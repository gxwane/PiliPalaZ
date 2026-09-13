import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pilipalaz/common/widgets/video_card_v.dart';
import 'package:pilipalaz/http/http_runtime.dart';
import 'package:pilipalaz/pages/main/view.dart';
import 'package:pilipalaz/pages/video/view.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_status.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipalaz/plugin/pl_player/view.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/recommend_filter.dart';
import 'package:pilipalaz/utils/screen_utils.dart';
import 'package:pilipalaz/utils/storage.dart';

import '../../test/journeys/support/journey_test_environment.dart';
import '../../test/journeys/support/mock_payloads.dart';

final Uint8List kTabletTestMp4Bytes = base64Decode(
  'AAAAHGZ0eXBtcDQyAAAAAWlzb21tcDQxbXA0MgAAAAFtZGF0AAAAAAAAAPAAAAAeBgUaR1ZK3FxMQz'
  '+U78URPNFDqAHdzMzdAgAI6YCAAAAAeyW4IAX/8QJz/GmH5ojGf7TPN7+nV8VhVGWvLk5AAAADATq0'
  'wr9+feS/mlJDhSFZNf/4hRF+6oyeBBnUM5xSMqmb8QFtnSOPLNO3XBJMqgABUi4AByNU+UFwm4gdXX'
  'CykATptDAQ02nHTpwhEqHUVhZMvYh3tIZP4G5VQAAAABsh4QhE/wAGhiENK/5aD+Fa4IQ5b0OeIW1T'
  '2vEAAAAcIeIQRv/kQUkTxE79KjKNfMiUEQ2axpWzkkhgUwAAAuFtb292AAAAbG12aGQAAAAA2/A0yt'
  'vwNMoAAAJYAAAGDQABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAA'
  'AEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACbXRyYWsAAABcdGtoZAAAAAHb8DTK2/A0'
  'ygAAAAEAAAAAAAAGDQAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAA'
  'AEAAAAABngAAANAAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAABg0AAAJYAAEAAAAAAeVtZGlhAAAA'
  'IG1kaGQAAAAA2/A0ytvwNMoAAAJYAAAIZVXEAAAAAAAxaGRscgAAAAAAAAAAdmlkZQAAAAAAAAAAAAAA'
  'AENvcmUgTWVkaWEgVmlkZW8AAAABjG1pbmYAAAAUdm1oZAAAAAEAAAAAAAAAAAAAACRkaW5mAAAAHGRy'
  'ZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAAUxzdGJsAAAAkXN0c2QAAAAAAAAAAQAAAIFhdmMxAAAAAAAA'
  'AAEAAAAAAAAAAAAAAAAAAAAAAZ4A0ABIAAAASAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
  'AAAAAAAAAAAAGP//AAAAK2F2Y0MBZAAN/+EAECdkAA2sVsGhvrmoEBAVIEABAAQo7jyw/fj4AAAAACBz'
  'dHRzAAAAAAAAAAIAAAACAAACWAAAAAEAAAO1AAAAGGN0dHMAAAAAAAAAAQAAAAMAAAJYAAAAFHN0c3MA'
  'AAAAAAAAAQAAAAEAAAAPc2R0cAAAAAAgEBAAAAAcc3RzYwAAAAAAAAABAAAAAQAAAAEAAAABAAAAIHN0'
  'c3oAAAAAAAAAAAAAAAMAAAChAAAAHwAAACAAAAAcc3RjbwAAAAAAAAADAAAALAAAAM0AAADs',
);

Future<HttpServer> startLocalMediaServer(Uint8List mp4Bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest request) {
    request.response.headers.contentType = ContentType('video', 'mp4');
    request.response.headers.add('Accept-Ranges', 'bytes');
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.contentLength = mp4Bytes.length;
    request.response.add(mp4Bytes);
    request.response.close();
  });
  return server;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Tier 2: Android 16 Tablet & Large Screen Integration Test', () {
    late HttpServer mediaServer;
    late String mediaUrl;

    setUpAll(() async {
      mediaServer = await startLocalMediaServer(kTabletTestMp4Bytes);
      mediaUrl = 'http://127.0.0.1:${mediaServer.port}/tablet_test_video.mp4';
      debugPrint('LOCAL_TABLET_MEDIA_SERVER=$mediaUrl');

      setupJourneyHarness(
        customHandler: (request) {
          if (request.path.contains('/x/player/wbi/playurl') ||
              request.path.contains('/x/player/wbi/v2') ||
              request.path.contains('/x/player/playurl')) {
            return buildPlayUrlPayload(videoUrl: mediaUrl, includeDash: false);
          }
          return const <String, dynamic>{};
        },
      );

      await initTestStorage();
      await clearTestStorage();
      await GStorage.video.put(
        VideoBoxKey.playRepeat,
        PlayRepeat.singleCycle.value,
      );
      await setupJourneyServiceLocator(mockPlatformChannels: false);
      MediaKit.ensureInitialized();
      PlPlayerController.isHeadlessTestMode = false;

      final httpRuntime = HttpRuntime.ensureInitialized(
        authSessionManager: authSessionManager,
        cookieJar: secureCookieJar,
      );
      await httpRuntime.initializeSession();
      RecommendFilter();
    });

    tearDownAll(() async {
      await mediaServer.close(force: true);
      await journeyTearDown();
    });

    testWidgets(
      'TC-TAB-01 to TC-TAB-05: Real Android 16 Tablet Adaptation Verification',
      (WidgetTester tester) async {
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final isOverflow =
              details.toString().contains('overflowed by') ||
              details.exceptionAsString().contains('overflowed by');
          if (isOverflow) {
            fail('Detected layout overflow on tablet: ${details.exception}');
          }
          originalOnError?.call(details);
        };

        try {
          // -----------------------------------------------------------
          // TC-TAB-01: Tablet Hardware Detection & Cold Start Layout
          // -----------------------------------------------------------
          expect(
            ScreenUtils.isTabletDevice(),
            isTrue,
            reason: 'Should detect Pixel Tablet shortestSide >= 600dp',
          );
          expect(
            ScreenUtils.shouldEnableMultiOrientation(),
            isTrue,
            reason: 'Tablet should enable multi-orientation at startup',
          );
          debugPrint(
            'TC-TAB-01: ScreenUtils correctly identified tablet device',
          );

          await tester.pumpWidget(createJourneyTestApp());
          await pumpUntil(tester, find.byType(MainApp));

          // Wait for feed cards to render in multi-column layout
          await pumpUntil(tester, find.textContaining('端到端测试视频：首页推荐第一条'));
          expect(find.byType(VideoCardV), findsWidgets);
          debugPrint('TC-TAB-01: Tablet home feed loaded successfully');

          // -----------------------------------------------------------
          // TC-TAB-02: Video Detail Dual-Column Architecture
          // -----------------------------------------------------------
          final targetCard = find.byType(VideoCardV).first;
          await tester.ensureVisible(targetCard);
          await tester.tap(targetCard, warnIfMissed: false);
          await tester.pump();
          await pumpUntil(tester, find.byType(VideoDetailPage));
          expect(find.byType(VideoDetailPage), findsOneWidget);

          // Find VideoDetailController
          final videoDetailContext = tester.element(
            find.byType(VideoDetailPage),
          );
          final size = MediaQuery.sizeOf(videoDetailContext);
          expect(
            ScreenUtils.shouldUseLandscapeDualColumn(
              videoDetailContext,
              BoxConstraints(maxWidth: size.width, maxHeight: size.height),
            ),
            isTrue,
            reason:
                'Tablet landscape viewport must activate dual-column layout',
          );
          debugPrint('TC-TAB-02: VideoDetailPage dual-column activated');

          // Wait for PlPlayerController to load video and mount player
          final plController = PlPlayerController.getInstance();
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            if (plController.dataStatus.status.value == DataStatus.loaded &&
                find.byType(PLVideoPlayer).evaluate().isNotEmpty) {
              break;
            }
          }
          expect(plController.videoController, isNotNull);
          expect(find.byType(PLVideoPlayer), findsOneWidget);
          debugPrint('TC-TAB-02: Left column embedded video player verified');

          // Right column verification: Explicit TabBar with '相关推荐' and '评论交流'
          expect(find.text('相关推荐'), findsOneWidget);
          expect(find.text('评论交流'), findsOneWidget);

          final tabFinder = find.byType(TabBar).first;
          expect(tabFinder, findsOneWidget);
          final TabBar tabBar = tester.widget<TabBar>(tabFinder);
          final TabController tabController = tabBar.controller!;
          expect(tabController.index, equals(0));
          debugPrint('TC-TAB-02: Right column dual TabBar verified');

          // -----------------------------------------------------------
          // TC-TAB-03: Right-Column Tab Switching
          // -----------------------------------------------------------
          // Tap '评论交流'
          await tester.tap(find.text('评论交流'));
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            if (tabController.index == 1) break;
          }
          expect(tabController.index, equals(1));
          debugPrint('TC-TAB-03: Switched to comments tab on tablet');

          // Tap '相关推荐'
          await tester.tap(find.text('相关推荐'));
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            if (tabController.index == 0) break;
          }
          expect(tabController.index, equals(0));
          debugPrint('TC-TAB-03: Switched back to recommendations tab');

          // -----------------------------------------------------------
          // TC-TAB-04: Fullscreen Toggle on Tablet (Zero Overflow & Safe Orientation)
          // -----------------------------------------------------------
          unawaited(plController.triggerFullScreen(status: true));
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            if (plController.isFullScreen.value) break;
          }
          expect(plController.isFullScreen.value, isTrue);
          debugPrint(
            'TC-TAB-04: Fullscreen entered on tablet without overflow',
          );

          unawaited(plController.triggerFullScreen(status: false));
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            if (!plController.isFullScreen.value) break;
          }
          expect(plController.isFullScreen.value, isFalse);
          // On tablet, orientation stays in autoScreen/landscape
          expect(find.text('相关推荐'), findsOneWidget);
          debugPrint('TC-TAB-04: Fullscreen exited on tablet safely');

          // -----------------------------------------------------------
          // TC-TAB-05: Route Exit & Lifecycle Teardown
          // -----------------------------------------------------------
          Get.back();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(VideoDetailPage), findsNothing);
          expect(find.byType(MainApp), findsOneWidget);
          debugPrint('TC-TAB-05: Cleanly returned to MainApp');

          await PlPlayerController.disposeIfExists();
          await journeyTearDown();
          debugPrint('TC-TAB-05: All tablet teardowns completed cleanly');
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });
}

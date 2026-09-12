import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/common/widgets/video_card_v.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';

import 'support/journey_test_environment.dart';
import 'support/mock_payloads.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestStorage();
  });

  setUp(() async {
    PlPlayerController.isHeadlessTestMode = true;
    await clearTestStorage();
    await setupJourneyServiceLocator();
  });

  tearDown(() async {
    await journeyTearDown();
  });

  testWidgets(
    'Suite 4: Network resilience, offline/timeout retry, and state self-healing',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Network mode controller: 'offline' -> 'timeout' -> 'online'
      String currentNetworkMode = 'offline';

      setupJourneyHarness(
        responder: (RequestOptions options) {
          if (currentNetworkMode == 'offline') {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: '网络连接异常，请检查网络设置',
            );
          }
          if (currentNetworkMode == 'timeout') {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
              message: '连接超时，请重试',
            );
          }
          return journeyMockDispatcher(options);
        },
      );

      // 1. Mount app in offline mode
      await tester.pumpWidget(createJourneyTestApp());
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );

      // 2. Verify HttpError is displayed with retry button
      expect(find.byType(HttpError), findsOneWidget);
      expect(find.text('点击重试'), findsOneWidget);
      expect(find.byType(VideoCardV), findsNothing);

      // 3. Transition to timeout state and tap retry
      currentNetworkMode = 'timeout';
      await tester.tap(find.text('点击重试'));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );

      // Verify still in error state with retry button
      expect(find.byType(HttpError), findsOneWidget);
      expect(find.text('点击重试'), findsOneWidget);
      expect(find.byType(VideoCardV), findsNothing);

      // 4. Recover online and tap retry -> self-healing feed
      currentNetworkMode = 'online';
      await tester.tap(find.text('点击重试'));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 15,
      );
      expect(find.byType(HttpError), findsNothing);
      expect(find.byType(VideoCardV), findsWidgets);
      expect(find.textContaining('首页推荐第一条'), findsWidgets);

      // 5. Clean teardown: drain all timers before disposing widget tree
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/utils/recommend_filter.dart';

import 'support/journey_test_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestStorage();
  });

  setUp(() async {
    PlPlayerController.isHeadlessTestMode = true;
    await clearTestStorage();
    await setupJourneyServiceLocator();
    setupJourneyHarness();
    RecommendFilter();
  });

  tearDown(() async {
    await journeyTearDown();
  });

  testWidgets(
    'Suite 1: Guest startup, home feed browse, tab switch, and video card push',
    (WidgetTester tester) async {
      // Set standard phone screen size
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Cold start in guest mode
      await tester.pumpWidget(createJourneyTestApp());
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );

      // 2. Recommend feed loads
      final cardFinder = find.textContaining('首页推荐第一条');
      await pumpUntil(
        tester,
        cardFinder,
        step: const Duration(milliseconds: 100),
        maxSteps: 50,
      );
      expect(cardFinder, findsWidgets);

      // 3. Bottom bar tab switch to '动态'
      final dynamicTab = find.text('动态');
      expect(dynamicTab, findsWidgets);
      await tester.tap(dynamicTab.first);
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );

      // 4. Switch back to '首页'
      final homeTab = find.text('首页');
      expect(homeTab, findsWidgets);
      await tester.tap(homeTab.first);
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );

      // Verify HomePage keep-alive: original recommend card still exists
      expect(find.textContaining('首页推荐第一条'), findsWidgets);

      // 5. Tap on the video card to push VideoDetailPage
      await tester.tap(find.textContaining('首页推荐第一条').first);
      await tester.pump();
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );

      // Assert navigation pushed to video detail route
      expect(Get.currentRoute.startsWith('/video'), isTrue);

      // Unmount before ending test to cleanly cancel timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    },
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/models/common/video_source_type.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';

import '../journeys/support/journey_test_environment.dart';

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
  });

  tearDown(() async {
    await journeyTearDown();
  });

  testWidgets(
    'P1-1: Responsive screen adaptation across tablet landscape, foldable, fullscreen, and PGC',
    (WidgetTester tester) async {
      // 1. Start in Landscape Tablet (1280 x 800)
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const testHeroTag = 'adapt_ugc_01';
      const testBvid = 'BV1TestJourney01';
      const testCid = 100001;

      await tester.pumpWidget(createJourneyTestApp());
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );

      // Navigate to UGC Video Detail Page
      Get.toNamed(
        '/video?bvid=$testBvid&cid=$testCid',
        arguments: {
          'heroTag': testHeroTag,
          'pic': 'https://i0.hdslb.com/bfs/archive/test01.jpg',
        },
      );
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 15,
      );

      expect(Get.isRegistered<VideoDetailController>(tag: testHeroTag), isTrue);
      final videoDetailCtr = Get.find<VideoDetailController>(tag: testHeroTag);

      // A. Verify Landscape Tablet Dual-Column & TabBar
      expect(find.text('相关推荐'), findsOneWidget);
      expect(find.text('评论交流'), findsOneWidget);
      expect(videoDetailCtr.tabCtr.index, equals(0));

      // Tap '评论交流'
      await tester.tap(find.text('评论交流'));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );
      expect(videoDetailCtr.tabCtr.index, equals(1));

      // Tap '相关推荐'
      await tester.tap(find.text('相关推荐'));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );
      expect(videoDetailCtr.tabCtr.index, equals(0));

      // B. Verify Fullscreen Enter & Exit (zero RenderFlex overflow)
      final plController = videoDetailCtr.plPlayerController!;
      unawaited(plController.triggerFullScreen(status: true));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );
      expect(plController.isFullScreen.value, isTrue);

      unawaited(plController.triggerFullScreen(status: false));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );
      expect(plController.isFullScreen.value, isFalse);
      expect(find.text('相关推荐'), findsOneWidget);

      // C. Verify Dynamic Window Resizing across form factors
      // 1) Resize to Foldable Squarish (700 x 800)
      tester.view.physicalSize = const Size(1400, 1600);
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );
      // In almost square layout, TabBarView is not used
      expect(find.byType(TabBarView), findsNothing);

      // 2) Resize to Standard Phone Portrait (390 x 844)
      tester.view.physicalSize = const Size(780, 1688);
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );
      // In phone portrait, TabBarView is restored for single column
      expect(find.byType(TabBarView), findsOneWidget);

      // 3) Resize back to Landscape Tablet (1280 x 800)
      tester.view.physicalSize = const Size(2560, 1600);
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );
      expect(find.text('相关推荐'), findsOneWidget);

      // D. Verify PGC Bangumi in Landscape Tablet (zero assertion crash)
      const pgcHeroTag = 'adapt_pgc_02';
      const initialBvid = 'BV1BangumiEp01';
      const initialCid = 600001;
      const initialSeasonId = 40001;
      const initialEpId = 50001;

      Get.toNamed(
        '/video?bvid=$initialBvid&cid=$initialCid&seasonId=$initialSeasonId&epId=$initialEpId',
        arguments: <String, dynamic>{
          'heroTag': pgcHeroTag,
          'videoType': SearchType.media_bangumi,
          'sourceType': VideoSourceType.pgc,
          'pic': 'https://i0.hdslb.com/bfs/bangumi/ep01.jpg',
        },
      );
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 20,
      );

      expect(Get.isRegistered<VideoDetailController>(tag: pgcHeroTag), isTrue);
      final pgcCtr = Get.find<VideoDetailController>(tag: pgcHeroTag);
      expect(pgcCtr.sourceType, equals(VideoSourceType.pgc));

      // Assert PGC TabBar renders cleanly with zero assertion errors
      expect(find.text('相关推荐'), findsOneWidget);
      expect(find.text('评论交流'), findsOneWidget);

      // Flush timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    },
  );
}

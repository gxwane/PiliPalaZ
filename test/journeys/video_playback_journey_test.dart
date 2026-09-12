import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';

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
  });

  tearDown(() async {
    await journeyTearDown();
  });

  testWidgets(
    'Suite 2: Video playback controls, seek, rate, fullscreen rotation, and clean exit',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const testHeroTag = 'journey_hero_01';
      const testBvid = 'BV1TestJourney01';
      const testCid = 100001;

      // 1. Mount app and navigate to VideoDetailPage with arguments
      await tester.pumpWidget(createJourneyTestApp());
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );

      Get.toNamed(
        '/video?bvid=$testBvid&cid=$testCid',
        arguments: {
          'heroTag': testHeroTag,
          'pic': 'https://i0.hdslb.com/bfs/archive/test.jpg',
        },
      );
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 15,
      );

      // Verify VideoDetailController is created and registered
      expect(Get.isRegistered<VideoDetailController>(tag: testHeroTag), isTrue);
      final videoDetailCtr = Get.find<VideoDetailController>(tag: testHeroTag);
      expect(videoDetailCtr.bvid, equals(testBvid));
      expect(videoDetailCtr.cid.value, equals(testCid));

      final PlPlayerController plController =
          videoDetailCtr.plPlayerController!;

      // Wait for playback to initialize
      for (var i = 0; i < 30; i++) {
        await boundedPump(
          tester,
          step: const Duration(milliseconds: 100),
          maxSteps: 1,
        );
        if (plController.dataStatus.status.value == DataStatus.loaded) break;
      }

      expect(plController.dataStatus.status.value, equals(DataStatus.loaded));
      expect(
        plController.playerStatus.status.value,
        equals(PlayerStatus.playing),
      );

      await plController.pause();
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 50),
        maxSteps: 5,
      );
      expect(
        plController.playerStatus.status.value,
        equals(PlayerStatus.paused),
      );

      await plController.play();
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 50),
        maxSteps: 5,
      );
      expect(
        plController.playerStatus.status.value,
        equals(PlayerStatus.playing),
      );

      const targetSeek = Duration(seconds: 42);
      await plController.seekTo(targetSeek, type: 'seek');
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 50),
        maxSteps: 5,
      );
      expect(plController.position.value, equals(targetSeek));

      await plController.setPlaybackSpeed(1.5);
      expect(plController.playbackSpeed, equals(1.5));
      await plController.setPlaybackSpeed(1.0);
      expect(plController.playbackSpeed, equals(1.0));

      plController.setPlayRepeat(PlayRepeat.singleCycle);
      expect(plController.playRepeat, equals(PlayRepeat.singleCycle));

      unawaited(plController.triggerFullScreen(status: true));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 50),
        maxSteps: 5,
      );
      expect(plController.isFullScreen.value, isTrue);

      unawaited(plController.triggerFullScreen(status: false));
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 200),
        maxSteps: 12,
      );
      expect(plController.isFullScreen.value, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    },
  );
}

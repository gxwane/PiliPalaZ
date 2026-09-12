import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/models/common/video_source_type.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/introduction/bangumi/controller.dart';
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
    'Suite 3: PGC Bangumi episode selection, resume, restricted notice, and failure recovery',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Custom handler to simulate episode switching failure and restricted content
      setupJourneyHarness(
        customHandler: (options) {
          final path = options.path;
          final cid = options.queryParameters['cid']?.toString();
          final epId = options.queryParameters['ep_id']?.toString();

          // Simulate failure on episode 999999
          if (cid == '999999' || epId == '59999') {
            return <String, dynamic>{'code': -404, 'message': '视频不存在或已被删除'};
          }

          // Simulate restricted VIP episode on 600004
          if (cid == '600004' || epId == '50004') {
            return <String, dynamic>{
              'code': -10403,
              'message': '大会员专享内容，请登录开通大会员观看',
            };
          }

          // Default PGC playurl with lastPlayTime: 35000 ms (35s) for resume verification
          if (path.contains('/pgc/player/web/playurl') ||
              path.contains('/x/player/playurl')) {
            final payload = buildPlayUrlPayload();
            (payload['data'] as Map<String, dynamic>)['last_play_time'] = 35000;
            (payload['result'] as Map<String, dynamic>)['last_play_time'] =
                35000;
            return payload;
          }

          return <String, dynamic>{};
        },
      );

      const testHeroTag = 'journey_pgc_hero_01';
      const initialBvid = 'BV1BangumiEp01';
      const initialCid = 600001;
      const initialSeasonId = 40001;
      const initialEpId = 50001;

      // 1. Mount app and navigate to PGC video page
      await tester.pumpWidget(createJourneyTestApp());
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 5,
      );

      Get.toNamed(
        '/video?bvid=$initialBvid&cid=$initialCid&seasonId=$initialSeasonId&epId=$initialEpId',
        arguments: <String, dynamic>{
          'heroTag': testHeroTag,
          'videoType': SearchType.media_bangumi,
          'sourceType': VideoSourceType.pgc,
          'pic': 'https://i0.hdslb.com/bfs/bangumi/ep01.jpg',
        },
      );
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 15,
      );

      // Verify controllers registered
      expect(Get.isRegistered<VideoDetailController>(tag: testHeroTag), isTrue);
      final videoDetailCtr = Get.find<VideoDetailController>(tag: testHeroTag);
      expect(videoDetailCtr.sourceType, equals(VideoSourceType.pgc));
      expect(videoDetailCtr.bvid, equals(initialBvid));
      expect(videoDetailCtr.cid.value, equals(initialCid));
      expect(videoDetailCtr.epId, equals(initialEpId));

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

      // Verify resume playback position (35s)
      expect(plController.position.value, equals(const Duration(seconds: 35)));

      // Verify BangumiIntroController is initialized and loaded episodes
      expect(
        Get.isRegistered<BangumiIntroController>(tag: testHeroTag),
        isTrue,
      );
      final bangumiIntroCtr = Get.find<BangumiIntroController>(
        tag: testHeroTag,
      );

      // Wait for Bangumi intro details to load
      for (var i = 0; i < 20; i++) {
        await boundedPump(
          tester,
          step: const Duration(milliseconds: 100),
          maxSteps: 1,
        );
        if ((bangumiIntroCtr.bangumiDetail.value.episodes ?? []).isNotEmpty)
          break;
      }

      final episodes = bangumiIntroCtr.bangumiDetail.value.episodes;
      expect(episodes, isNotNull);
      expect(episodes!.length, greaterThanOrEqualTo(2));
      expect(episodes[0].epId, equals(50001));
      expect(episodes[1].epId, equals(50002));

      // 2. Switch episode to Episode 2
      final ep2 = episodes[1];
      final changeFuture = bangumiIntroCtr.changeSeasonOrbangu(
        ep2.bvid,
        ep2.cid,
        ep2.aid,
        ep2.epId,
      );
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );
      final switchResult = await changeFuture;
      expect(switchResult, isTrue);

      expect(videoDetailCtr.bvid, equals(ep2.bvid));
      expect(videoDetailCtr.cid.value, equals(ep2.cid));
      expect(videoDetailCtr.epId, equals(ep2.epId));
      expect(plController.dataStatus.status.value, equals(DataStatus.loaded));

      // 3. Test episode switching failure recovery (切集失败恢复)
      // Attempt to switch to failing episode (cid 999999)
      final failFuture = bangumiIntroCtr.changeSeasonOrbangu(
        'BV1BangumiEpFail',
        999999,
        1234599,
        59999,
      );
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );
      await failFuture;

      // Verify state restored back to Episode 2
      expect(videoDetailCtr.bvid, equals(ep2.bvid));
      expect(videoDetailCtr.cid.value, equals(ep2.cid));
      expect(videoDetailCtr.epId, equals(ep2.epId));
      expect(plController.dataStatus.status.value, equals(DataStatus.loaded));

      // 4. Test restricted VIP content handling
      videoDetailCtr.epId = 50004;
      videoDetailCtr.cid.value = 600004;
      final restrictedFuture = videoDetailCtr.queryVideoUrl(
        preserveCurrentOnFailure: false,
      );
      await boundedPump(
        tester,
        step: const Duration(milliseconds: 100),
        maxSteps: 10,
      );
      final Map restrictedQuery = await restrictedFuture;
      expect(restrictedQuery['status'], isFalse);
      expect(videoDetailCtr.playbackError.value, isNotEmpty);
      expect(videoDetailCtr.playbackError.value, contains('大会员'));

      // 5. Clean exit
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    },
  );
}

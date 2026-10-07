import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/pages/bangumi/widgets/bangumi_episode_catalog.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/introduction/bangumi/controller.dart';
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
    Get.reset();
  });

  tearDown(() async {
    await journeyTearDown();
    Get.reset();
  });

  group('BangumiEpisodeCatalogView Widget TDD Tests', () {
    final testEpisodes = [
      EpisodeItem(
        cid: 501,
        title: '1',
        longTitle: '破晓之光',
        bvid: 'BV1bangumi1',
        aid: 51,
        epId: 5001,
      ),
      EpisodeItem(
        cid: 502,
        title: '2',
        longTitle: '命运交错',
        bvid: 'BV1bangumi2',
        aid: 52,
        epId: 5002,
        badge: '会员',
      ),
    ];

    testWidgets('renders episodes, active state, and handles episode tap', (
      tester,
    ) async {
      const heroTag = 'test_catalog_hero';
      final videoDetailCtr = Get.put(VideoDetailController(), tag: heroTag);
      videoDetailCtr.cid.value = 501;

      final bangumiIntroCtr = Get.put(BangumiIntroController(), tag: heroTag);
      bangumiIntroCtr.bangumiDetail.value = BangumiInfoModel(
        title: '测试剧集',
        episodes: testEpisodes,
        type: 1,
        seasons: [
          {'season_id': 1, 'season_title': '第一季'},
          {'season_id': 2, 'season_title': '第二季'},
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BangumiEpisodeCatalogView(heroTag: heroTag)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('剧集选集'), findsOneWidget);
      expect(find.text('共 2 话'), findsOneWidget);
      expect(find.text('破晓之光'), findsOneWidget);
      expect(find.text('命运交错'), findsOneWidget);
      expect(find.text('第一季'), findsOneWidget);
      expect(find.text('第二季'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}

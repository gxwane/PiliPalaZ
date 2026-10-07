import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/pages/bangumi/widgets/bangumi_panel.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/introduction/bangumi/controller.dart';
import 'package:pilipalaz/pages/video/introduction/bangumi/view.dart';
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

  group('BangumiPanel & BangumiIntro Robustness TDD Tests', () {
    final testEpisodes = [
      EpisodeItem(
        cid: 101,
        title: '1',
        longTitle: '第一话',
        bvid: 'BV1test1',
        aid: 1,
        epId: 11,
      ),
      EpisodeItem(
        cid: 102,
        title: '2',
        longTitle: '第二话',
        bvid: 'BV1test2',
        aid: 2,
        epId: 12,
      ),
    ];

    testWidgets(
      'BangumiPanel mounts safely when Get.arguments is null (no crash)',
      (tester) async {
        // Ensure Get.arguments is null
        Get.routing.args = null;

        const testHeroTag = 'test_hero_tag_null_args';
        final videoDetailCtr = Get.put(
          VideoDetailController(),
          tag: testHeroTag,
        );
        videoDetailCtr.cid.value = 101;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BangumiPanel(
                pages: testEpisodes,
                cid: 101,
                heroTag: testHeroTag,
                changeFuc: (bvid, cid, aid, epId) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(' 正在播放：第一话'), findsOneWidget);
        expect(find.text('全2话'), findsOneWidget);

        // Verify unmounting doesn't crash or leak
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('BangumiInfo mounts safely when Get.arguments is null', (
      tester,
    ) async {
      Get.routing.args = null;

      const testHeroTag = 'test_bangumi_info_hero';
      final videoDetailCtr = Get.put(VideoDetailController(), tag: testHeroTag);
      videoDetailCtr.cid.value = 101;
      Get.put(BangumiIntroController(), tag: testHeroTag);

      final detail = BangumiInfoModel(
        title: '测试番剧',
        episodes: testEpisodes,
        type: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                BangumiInfo(
                  loadingStatus: false,
                  bangumiDetail: detail,
                  cid: 101,
                  heroTag: testHeroTag,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('测试番剧'), findsOneWidget);
      expect(find.text(' 正在播放：第一话'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets(
      'BangumiIntroController initializes safely when Get.arguments is null',
      (tester) async {
        Get.routing.args = null;
        final controller = BangumiIntroController();
        expect(() => controller.onInit(), returnsNormally);
      },
    );
  });
}

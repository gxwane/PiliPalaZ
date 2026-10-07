import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/fullscreen_episode_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FullScreenEpisodePanel Widget & Interaction TDD Tests', () {
    final testEpisodes = [
      EpisodeItem(
        cid: 10001,
        title: '1',
        longTitle: '开始的物语',
        bvid: 'BV1test1',
        aid: 101,
        epId: 201,
      ),
      EpisodeItem(
        cid: 10002,
        title: '2',
        longTitle: '重逢的约定',
        bvid: 'BV1test2',
        aid: 102,
        epId: 202,
        badge: '会员',
      ),
      EpisodeItem(
        cid: 10003,
        title: '3',
        longTitle: '决战时刻',
        bvid: 'BV1test3',
        aid: 103,
        epId: 203,
        badge: '预告',
      ),
    ];

    testWidgets(
      'renders episodes, header, active status, and badges in landscape',
      (tester) async {
        EpisodeItem? selectedEpisode;

        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FullScreenEpisodePanel(
                episodes: testEpisodes,
                currentCid: 10001,
                onSelect: (ep) => selectedEpisode = ep as EpisodeItem,
              ),
            ),
          ),
        );

        expect(find.text('剧集选集'), findsOneWidget);
        expect(find.text('共 3 话'), findsOneWidget);
        expect(find.text('开始的物语'), findsOneWidget);
        expect(find.text('重逢的约定'), findsOneWidget);
        expect(find.text('决战时刻'), findsOneWidget);
        expect(find.text('预告'), findsOneWidget);

        // Tap second episode
        await tester.tap(find.text('重逢的约定'));
        await tester.pumpAndSettle();
        expect(selectedEpisode, isNotNull);
        expect(selectedEpisode!.cid, 10002);
      },
    );

    testWidgets('movie mode displays proper header text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenEpisodePanel(
              episodes: [testEpisodes.first],
              currentCid: 10001,
              isMovie: true,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('电影选集'), findsOneWidget);
      expect(find.text('共 1 部'), findsOneWidget);
    });

    testWidgets('swiping right triggers dismiss callback', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenEpisodePanel(
              episodes: testEpisodes,
              currentCid: 10001,
              onSelect: (_) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Perform swipe right gesture
      await tester.drag(find.text('剧集选集'), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('auto-dismisses when orientation becomes portrait', (
      tester,
    ) async {
      bool dismissed = false;

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenEpisodePanel(
              episodes: testEpisodes,
              currentCid: 10001,
              onSelect: (_) {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });

    testWidgets('renders and selects PlayQueueItem queue correctly', (
      tester,
    ) async {
      PlayQueueItem? selectedItem;
      final queueItems = [
        const PlayQueueItem(
          id: 'test_1',
          bvid: 'BV1test1',
          cid: 20001,
          title: '视频第一集',
          duration: 125,
          sourceType: PlayQueueSourceType.part,
        ),
        const PlayQueueItem(
          id: 'test_2',
          bvid: 'BV1test2',
          cid: 20002,
          title: '视频第二集',
          duration: 300,
          badge: '独家',
          sourceType: PlayQueueSourceType.part,
        ),
      ];

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenEpisodePanel(
              episodes: queueItems,
              currentCid: 20001,
              bvid: 'BV1test1',
              onSelect: (item) => selectedItem = item as PlayQueueItem,
            ),
          ),
        ),
      );

      expect(find.text('分P列表'), findsOneWidget);
      expect(find.text('共 2 个视频'), findsOneWidget);
      expect(find.text('视频第一集'), findsOneWidget);
      expect(find.text('02:05'), findsOneWidget);
      expect(find.text('视频第二集'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('独家'), findsOneWidget);

      await tester.tap(find.text('视频第二集'));
      await tester.pumpAndSettle();
      expect(selectedItem, isNotNull);
      expect(selectedItem!.cid, 20002);
    });
  });
}

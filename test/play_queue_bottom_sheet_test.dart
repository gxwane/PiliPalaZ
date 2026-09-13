import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/models/model_hot_video_item.dart';
import 'package:pilipalaz/models/model_owner.dart';
import 'package:pilipalaz/pages/video/widgets/play_queue_bottom_sheet.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_repeat.dart';

import 'journeys/support/journey_test_environment.dart';

Widget _wrapInTestApp(Widget child) {
  return GetMaterialApp(home: Scaffold(body: child));
}

void main() {
  setUpAll(() async {
    await initTestStorage();
    PlPlayerController.isHeadlessTestMode = true;
  });

  setUp(() {
    PlaybackQueueController.resetActiveStackForTesting();
  });

  group('PlayQueueBottomSheet Widget Tests', () {
    testWidgets('renders header, queue items, and source pill', (tester) async {
      final controller = PlaybackQueueController(heroTag: 'test_queue_tag');
      controller.mockPlayRepeatForTesting = PlayRepeat.pause;

      final testItems = [
        HotVideoItemModel(
          aid: 101,
          bvid: 'BV101',
          cid: 201,
          title: 'Item 1',
          pic: 'https://example.com/1.jpg',
          duration: 120,
          owner: Owner(mid: 1, name: 'Author A', face: ''),
        ),
        HotVideoItemModel(
          aid: 102,
          bvid: 'BV102',
          cid: 202,
          title: 'Item 2',
          pic: 'https://example.com/2.jpg',
          duration: 240,
          owner: Owner(mid: 2, name: 'Author B', face: ''),
        ),
        HotVideoItemModel(
          aid: 103,
          bvid: 'BV103',
          cid: 203,
          title: 'Item 3',
          pic: 'https://example.com/3.jpg',
          duration: 360,
          owner: Owner(mid: 3, name: 'Author C', face: ''),
        ),
      ];

      controller.initFromWatchLater(items: testItems, initialIndex: 0);

      await tester.pumpWidget(
        _wrapInTestApp(PlayQueueBottomSheet(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('播放队列'), findsOneWidget);
      expect(find.text('稍后再看'), findsOneWidget);
      expect(find.text('(3)'), findsOneWidget);

      // Verify Item 1, 2, 3
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // Item 1 is currently playing (has volume_up_rounded icon)
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tapping item calls jumpToIndex', (tester) async {
      final controller = PlaybackQueueController(heroTag: 'test_jump_tag');
      controller.mockPlayRepeatForTesting = PlayRepeat.pause;

      final testItems = [
        HotVideoItemModel(
          aid: 101,
          bvid: 'BV101',
          cid: 201,
          title: 'Video Alpha',
          owner: Owner(mid: 1, name: 'Author A', face: ''),
        ),
        HotVideoItemModel(
          aid: 102,
          bvid: 'BV102',
          cid: 202,
          title: 'Video Beta',
          owner: Owner(mid: 2, name: 'Author B', face: ''),
        ),
      ];

      controller.initFromWatchLater(items: testItems, initialIndex: 0);

      PlayQueueItem? playedItem;
      controller.onPlayItem = (item) async {
        playedItem = item;
        return true;
      };

      await tester.pumpWidget(
        _wrapInTestApp(PlayQueueBottomSheet(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Tap Video Beta
      await tester.tap(find.text('Video Beta'));
      await tester.pumpAndSettle();

      expect(controller.currentIndex.value, 1);
      expect(playedItem?.title, 'Video Beta');

      controller.dispose();
    });

    testWidgets('tapping remove button removes item from queue', (
      tester,
    ) async {
      final controller = PlaybackQueueController(heroTag: 'test_remove_tag');
      controller.mockPlayRepeatForTesting = PlayRepeat.pause;

      final testItems = [
        HotVideoItemModel(
          aid: 101,
          bvid: 'BV101',
          cid: 201,
          title: 'Keep Me',
          owner: Owner(mid: 1, name: 'Author A', face: ''),
        ),
        HotVideoItemModel(
          aid: 102,
          bvid: 'BV102',
          cid: 202,
          title: 'Delete Me',
          owner: Owner(mid: 2, name: 'Author B', face: ''),
        ),
      ];

      controller.initFromWatchLater(items: testItems, initialIndex: 0);

      await tester.pumpWidget(
        _wrapInTestApp(PlayQueueBottomSheet(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Me'), findsOneWidget);

      // Find the remove button for Delete Me
      final removeButtonFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '从队列移除 Delete Me',
      );
      expect(removeButtonFinder, findsOneWidget);

      await tester.tap(removeButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Delete Me'), findsNothing);
      expect(controller.queue.length, 1);

      controller.dispose();
    });

    testWidgets('tapping clear upcoming removes later items', (tester) async {
      final controller = PlaybackQueueController(heroTag: 'test_clear_tag');
      controller.mockPlayRepeatForTesting = PlayRepeat.pause;

      final testItems = [
        HotVideoItemModel(
          aid: 101,
          bvid: 'BV101',
          cid: 201,
          title: 'Current Song',
          owner: Owner(mid: 1, name: 'Author A', face: ''),
        ),
        HotVideoItemModel(
          aid: 102,
          bvid: 'BV102',
          cid: 202,
          title: 'Upcoming 1',
          owner: Owner(mid: 2, name: 'Author B', face: ''),
        ),
        HotVideoItemModel(
          aid: 103,
          bvid: 'BV103',
          cid: 203,
          title: 'Upcoming 2',
          owner: Owner(mid: 3, name: 'Author C', face: ''),
        ),
      ];

      controller.initFromWatchLater(items: testItems, initialIndex: 0);

      await tester.pumpWidget(
        _wrapInTestApp(PlayQueueBottomSheet(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Tap clear upcoming
      final clearButton = find.byTooltip('清空待播');
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(controller.queue.length, 1);
      expect(find.text('Upcoming 1'), findsNothing);
      expect(find.text('Upcoming 2'), findsNothing);
      expect(find.text('Current Song'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('toggling repeat mode cycles through modes', (tester) async {
      final controller = PlaybackQueueController(heroTag: 'test_mode_tag');
      controller.mockPlayRepeatForTesting = PlayRepeat.pause;

      controller.initFromWatchLater(
        items: [
          HotVideoItemModel(
            aid: 101,
            bvid: 'BV101',
            cid: 201,
            title: 'Track',
            owner: Owner(mid: 1, name: 'Author', face: ''),
          ),
        ],
        initialIndex: 0,
      );

      await tester.pumpWidget(
        _wrapInTestApp(PlayQueueBottomSheet(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Current mode is pause
      expect(controller.playRepeat, PlayRepeat.pause);

      // Tap repeat button
      final repeatButton = find.byTooltip('播放模式: 播完暂停');
      expect(repeatButton, findsOneWidget);

      await tester.tap(repeatButton);
      await tester.pumpAndSettle();

      // Mode changed to listOrder
      expect(controller.playRepeat, PlayRepeat.listOrder);
      expect(find.byTooltip('播放模式: 顺序播放'), findsOneWidget);

      controller.dispose();
    });
  });
}

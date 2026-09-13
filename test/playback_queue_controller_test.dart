import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/models/bangumi/info.dart' as pgc;
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/models/model_hot_video_item.dart';
import 'package:pilipalaz/models/model_owner.dart';
import 'package:pilipalaz/models/video_detail_res.dart' as ugc;
import 'package:pilipalaz/plugin/pl_player/controller.dart';

void main() {
  setUp(() {
    PlaybackQueueController.resetActiveStackForTesting();
    PlPlayerController.isHeadlessTestMode = true;
  });

  group('PlaybackQueueController Stack & Lifecycle', () {
    test('tracks activeInstance via stack push and pop', () {
      expect(PlaybackQueueController.activeInstance, isNull);

      final ctr1 = PlaybackQueueController(heroTag: 'tag1');
      ctr1.onInit();
      expect(PlaybackQueueController.activeInstance, equals(ctr1));

      final ctr2 = PlaybackQueueController(heroTag: 'tag2');
      ctr2.onInit();
      expect(PlaybackQueueController.activeInstance, equals(ctr2));

      // Pop ctr2, ctr1 should become active again
      ctr2.onClose();
      expect(PlaybackQueueController.activeInstance, equals(ctr1));

      ctr1.onClose();
      expect(PlaybackQueueController.activeInstance, isNull);
    });

    test('markActive brings instance to top of stack', () {
      final ctr1 = PlaybackQueueController(heroTag: 'tag1');
      ctr1.onInit();
      final ctr2 = PlaybackQueueController(heroTag: 'tag2');
      ctr2.onInit();
      expect(PlaybackQueueController.activeInstance, equals(ctr2));

      ctr1.markActive();
      expect(PlaybackQueueController.activeInstance, equals(ctr1));

      ctr1.onClose();
      ctr2.onClose();
    });
  });

  group('PlaybackQueueController Initializations & Protection', () {
    test('initFromPages sets up multi-P queue and matches currentCid', () {
      final ctr = PlaybackQueueController(heroTag: 'pages_test');
      ctr.onInit();

      final pages = [
        ugc.Part(cid: 101, page: 1, pagePart: 'P1'),
        ugc.Part(cid: 102, page: 2, pagePart: 'P2'),
        ugc.Part(cid: 103, page: 3, pagePart: 'P3'),
      ];

      ctr.initFromPages(
        pages: pages,
        bvid: 'BV1Pages',
        aid: 999,
        currentCid: 102,
      );

      expect(ctr.queue.length, equals(3));
      expect(ctr.currentIndex.value, equals(1));
      expect(ctr.currentItem?.cid, equals(102));
      expect(ctr.sourceType.value, equals(PlayQueueSourceType.part));
      expect(ctr.hasPrevious.value, isTrue);
      expect(ctr.hasNext.value, isTrue);

      ctr.onClose();
    });

    test(
      'isExternalQueue protects Watch Later queue from queryVideoIntro re-init',
      () {
        final ctr = PlaybackQueueController(heroTag: 'wl_test');
        ctr.onInit();

        final watchLaterItems = [
          HotVideoItemModel(
            aid: 1,
            bvid: 'BV1',
            cid: 11,
            title: 'WL 1',
            owner: Owner(name: 'A'),
          ),
          HotVideoItemModel(
            aid: 2,
            bvid: 'BV2',
            cid: 22,
            title: 'WL 2',
            owner: Owner(name: 'B'),
          ),
          HotVideoItemModel(
            aid: 3,
            bvid: 'BV3',
            cid: 33,
            title: 'WL 3',
            owner: Owner(name: 'C'),
          ),
        ];

        ctr.initFromWatchLater(items: watchLaterItems, initialIndex: 0);

        expect(ctr.isExternalQueue.value, isTrue);
        expect(ctr.queue.length, equals(3));
        expect(ctr.sourceType.value, equals(PlayQueueSourceType.watchLater));

        // Attempt to clobber with pages from current video
        ctr.initFromPages(
          pages: [ugc.Part(cid: 11, page: 1, pagePart: 'P1')],
          bvid: 'BV1',
          aid: 1,
          currentCid: 11,
        );

        // Queue must remain untouched!
        expect(ctr.queue.length, equals(3));
        expect(ctr.sourceType.value, equals(PlayQueueSourceType.watchLater));

        ctr.onClose();
      },
    );

    test('initFromPgc sets up anime episode queue and matches epId/cid', () {
      final ctr = PlaybackQueueController(heroTag: 'pgc_test');
      ctr.onInit();

      final episodes = [
        pgc.EpisodeItem(cid: 201, epId: 501, title: '1', longTitle: '开始'),
        pgc.EpisodeItem(cid: 202, epId: 502, title: '2', longTitle: '进发'),
      ];

      ctr.initFromPgc(episodes: episodes, currentCid: 202, currentEpId: 502);

      expect(ctr.queue.length, equals(2));
      expect(ctr.currentIndex.value, equals(1));
      expect(ctr.currentItem?.epId, equals(502));
      expect(ctr.sourceType.value, equals(PlayQueueSourceType.pgcEpisode));

      ctr.onClose();
    });
  });

  group('PlaybackQueueController Navigation Operations', () {
    test('playNext and playPrevious traverse queue sequentially', () async {
      PlayQueueItem? playedItem;
      final ctr = PlaybackQueueController(
        heroTag: 'nav_test',
        onPlayItem: (item) async {
          playedItem = item;
          return true;
        },
      );
      ctr.onInit();

      final pages = [
        ugc.Part(cid: 1, page: 1, pagePart: 'P1'),
        ugc.Part(cid: 2, page: 2, pagePart: 'P2'),
        ugc.Part(cid: 3, page: 3, pagePart: 'P3'),
      ];
      ctr.initFromPages(pages: pages, bvid: 'BV', aid: 1, currentCid: 1);

      expect(ctr.currentIndex.value, equals(0));

      // Forward navigation
      final next1 = await ctr.playNext();
      expect(next1, isTrue);
      expect(ctr.currentIndex.value, equals(1));
      expect(playedItem?.cid, equals(2));

      final next2 = await ctr.playNext();
      expect(next2, isTrue);
      expect(ctr.currentIndex.value, equals(2));
      expect(playedItem?.cid, equals(3));

      // At end of queue without repeat mode
      final next3 = await ctr.playNext();
      expect(next3, isFalse);
      expect(ctr.currentIndex.value, equals(2));

      // Backward navigation
      final prev1 = await ctr.playPrevious();
      expect(prev1, isTrue);
      expect(ctr.currentIndex.value, equals(1));
      expect(playedItem?.cid, equals(2));

      final prev2 = await ctr.playPrevious();
      expect(prev2, isTrue);
      expect(ctr.currentIndex.value, equals(0));
      expect(playedItem?.cid, equals(1));

      // At start of queue
      final prev3 = await ctr.playPrevious();
      expect(prev3, isFalse);

      ctr.onClose();
    });

    test('jumpToIndex updates index and triggers onPlayItem', () async {
      PlayQueueItem? playedItem;
      final ctr = PlaybackQueueController(
        heroTag: 'jump_test',
        onPlayItem: (item) async {
          playedItem = item;
          return true;
        },
      );
      ctr.onInit();

      final pages = [
        ugc.Part(cid: 1, page: 1),
        ugc.Part(cid: 2, page: 2),
        ugc.Part(cid: 3, page: 3),
      ];
      ctr.initFromPages(pages: pages, bvid: 'BV', aid: 1, currentCid: 1);

      final res = await ctr.jumpToIndex(2);
      expect(res, isTrue);
      expect(ctr.currentIndex.value, equals(2));
      expect(playedItem?.cid, equals(3));

      // Invalid index
      final invalid = await ctr.jumpToIndex(99);
      expect(invalid, isFalse);
      expect(ctr.currentIndex.value, equals(2));

      ctr.onClose();
    });
  });

  group('PlaybackQueueController Item Manipulation & Self-Healing', () {
    test('removeAt item before currentIndex adjusts index correctly', () {
      final ctr = PlaybackQueueController(heroTag: 'remove_before');
      ctr.onInit();

      final pages = [
        ugc.Part(cid: 10, page: 1),
        ugc.Part(cid: 20, page: 2),
        ugc.Part(cid: 30, page: 3),
      ];
      ctr.initFromPages(pages: pages, bvid: 'BV', aid: 1, currentCid: 20);
      expect(ctr.currentIndex.value, equals(1));

      // Remove P1 (index 0)
      ctr.removeAt(0);

      expect(ctr.queue.length, equals(2));
      expect(ctr.currentIndex.value, equals(0));
      expect(ctr.currentItem?.cid, equals(20)); // still playing P2!

      ctr.onClose();
    });

    test('removeAt current item plays subsequent item', () async {
      PlayQueueItem? playedItem;
      final ctr = PlaybackQueueController(
        heroTag: 'remove_current',
        onPlayItem: (item) async {
          playedItem = item;
          return true;
        },
      );
      ctr.onInit();

      final pages = [
        ugc.Part(cid: 10, page: 1),
        ugc.Part(cid: 20, page: 2),
        ugc.Part(cid: 30, page: 3),
      ];
      ctr.initFromPages(pages: pages, bvid: 'BV', aid: 1, currentCid: 20);

      // Remove current playing P2 (index 1)
      ctr.removeAt(1);

      expect(ctr.queue.length, equals(2));
      expect(ctr.currentIndex.value, equals(1));
      expect(ctr.currentItem?.cid, equals(30)); // automatically plays P3!
      expect(playedItem?.cid, equals(30));

      ctr.onClose();
    });

    test('removeAt current item at tail steps back to new tail', () async {
      PlayQueueItem? playedItem;
      final ctr = PlaybackQueueController(
        heroTag: 'remove_tail',
        onPlayItem: (item) async {
          playedItem = item;
          return true;
        },
      );
      ctr.onInit();

      final pages = [ugc.Part(cid: 10, page: 1), ugc.Part(cid: 20, page: 2)];
      ctr.initFromPages(pages: pages, bvid: 'BV', aid: 1, currentCid: 20);
      expect(ctr.currentIndex.value, equals(1));

      // Remove P2 (tail)
      ctr.removeAt(1);

      expect(ctr.queue.length, equals(1));
      expect(ctr.currentIndex.value, equals(0));
      expect(ctr.currentItem?.cid, equals(10));
      expect(playedItem?.cid, equals(10));

      ctr.onClose();
    });

    test(
      'removeAt single remaining item empties queue and invokes callback',
      () {
        bool queueEmptiedCalled = false;
        final ctr = PlaybackQueueController(
          heroTag: 'remove_single',
          onQueueEmptied: () => queueEmptiedCalled = true,
        );
        ctr.onInit();

        final pages = [ugc.Part(cid: 10, page: 1)];
        ctr.initFromPages(pages: pages, bvid: 'BV', aid: 1, currentCid: 10);

        ctr.removeAt(0);

        expect(ctr.queue.isEmpty, isTrue);
        expect(ctr.hasPrevious.value, isFalse);
        expect(ctr.hasNext.value, isFalse);
        expect(queueEmptiedCalled, isTrue);

        ctr.onClose();
      },
    );

    test('clearUpcoming clears only items after current index', () {
      final ctr = PlaybackQueueController(heroTag: 'clear_upcoming');
      ctr.onInit();

      final pages = [
        ugc.Part(cid: 1, page: 1),
        ugc.Part(cid: 2, page: 2),
        ugc.Part(cid: 3, page: 3),
        ugc.Part(cid: 4, page: 4),
      ];
      ctr.initFromPages(pages: pages, bvid: 'BV', aid: 1, currentCid: 2);
      expect(ctr.currentIndex.value, equals(1));

      ctr.clearUpcoming();

      expect(ctr.queue.length, equals(2));
      expect(ctr.queue.map((e) => e.cid).toList(), equals([1, 2]));
      expect(ctr.currentIndex.value, equals(1));

      ctr.onClose();
    });
  });
}

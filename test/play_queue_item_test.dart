import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/bangumi/info.dart' as pgc;
import 'package:pilipalaz/models/common/play_queue_item.dart';
import 'package:pilipalaz/models/model_hot_video_item.dart';
import 'package:pilipalaz/models/model_owner.dart';
import 'package:pilipalaz/models/video_detail_res.dart' as ugc;

void main() {
  group('PlayQueueItem Factory & Model Tests', () {
    test('converts from UGC Part correctly', () {
      final part = ugc.Part(
        cid: 123456,
        page: 2,
        pagePart: '第2集 深入解析',
        duration: 360,
        firstFrame: 'https://i0.hdslb.com/bfs/frame/p2.jpg',
        badge: '会员',
      );

      final item = PlayQueueItem.fromPart(
        part,
        bvid: 'BV1TestUgcPart',
        aid: 987654,
        cover: 'https://i0.hdslb.com/bfs/cover/fallback.jpg',
        author: '测试UP主',
      );

      expect(item.id, equals('part_BV1TestUgcPart_123456'));
      expect(item.bvid, equals('BV1TestUgcPart'));
      expect(item.cid, equals(123456));
      expect(item.aid, equals(987654));
      expect(item.title, equals('第2集 深入解析'));
      expect(item.cover, equals('https://i0.hdslb.com/bfs/cover/fallback.jpg'));
      expect(item.duration, equals(360));
      expect(item.author, equals('测试UP主'));
      expect(item.badge, equals('会员'));
      expect(item.sourceType, equals(PlayQueueSourceType.part));
    });

    test('converts from UGC EpisodeItem (UgcSeason) correctly', () {
      final ugcEp = ugc.EpisodeItem(
        seasonId: 888,
        aid: 111222,
        cid: 333444,
        bvid: 'BV1UgcSeason01',
        title: '合集第一集',
        longTitle: '传奇的序幕',
        badge: '付费',
        page: ugc.Part(
          cid: 333444,
          duration: 480,
          firstFrame: 'https://i0.hdslb.com/bfs/ugc/frame.jpg',
        ),
      );

      final item = PlayQueueItem.fromUgcEpisode(ugcEp, author: '合集作者');

      expect(item.id, equals('ugc_BV1UgcSeason01_333444'));
      expect(item.bvid, equals('BV1UgcSeason01'));
      expect(item.cid, equals(333444));
      expect(item.aid, equals(111222));
      expect(item.seasonId, equals(888));
      expect(item.title, equals('合集第一集 传奇的序幕'));
      expect(item.duration, equals(480));
      expect(item.cover, equals('https://i0.hdslb.com/bfs/ugc/frame.jpg'));
      expect(item.author, equals('合集作者'));
      expect(item.badge, equals('付费'));
      expect(item.sourceType, equals(PlayQueueSourceType.ugcSeason));
    });

    test('converts from PGC EpisodeItem correctly', () {
      final pgcEp = pgc.EpisodeItem(
        aid: 444555,
        bvid: 'BV1PgcAnime01',
        cid: 666777,
        epId: 888999,
        title: '1',
        longTitle: '相遇之日',
        cover: 'https://i0.hdslb.com/bfs/pgc/ep01.jpg',
        duration: 1440000, // 毫秒
        badge: '大会员',
      );

      final item = PlayQueueItem.fromPgcEpisode(pgcEp, seasonId: 5555);

      expect(item.id, equals('pgc_888999_BV1PgcAnime01_666777'));
      expect(item.bvid, equals('BV1PgcAnime01'));
      expect(item.cid, equals(666777));
      expect(item.epId, equals(888999));
      expect(item.seasonId, equals(5555));
      expect(item.title, equals('第1话 相遇之日'));
      expect(item.cover, equals('https://i0.hdslb.com/bfs/pgc/ep01.jpg'));
      expect(item.duration, equals(1440)); // 秒
      expect(item.badge, equals('大会员'));
      expect(item.sourceType, equals(PlayQueueSourceType.pgcEpisode));
    });

    test(
      'converts from HotVideoItemModel (Watch Later & Related) correctly',
      () {
        final hotItem = HotVideoItemModel(
          aid: 123,
          bvid: 'BV1WatchLater01',
          cid: 456,
          title: '稍后再看精彩视频',
          pic: 'https://i0.hdslb.com/bfs/later/pic.jpg',
          duration: 250,
          owner: Owner(mid: 10001, name: '优质UP主'),
        );

        final item = PlayQueueItem.fromHotVideoItem(
          hotItem,
          sourceType: PlayQueueSourceType.watchLater,
        );

        expect(item.id, equals('watchLater_BV1WatchLater01_456'));
        expect(item.bvid, equals('BV1WatchLater01'));
        expect(item.cid, equals(456));
        expect(item.aid, equals(123));
        expect(item.title, equals('稍后再看精彩视频'));
        expect(item.cover, equals('https://i0.hdslb.com/bfs/later/pic.jpg'));
        expect(item.duration, equals(250));
        expect(item.author, equals('优质UP主'));
        expect(item.sourceType, equals(PlayQueueSourceType.watchLater));
      },
    );

    test(
      'copyWith updates properties and preserves identity when unchanged',
      () {
        const original = PlayQueueItem(
          id: 'test_1',
          bvid: 'BV1',
          cid: 101,
          title: '原标题',
          sourceType: PlayQueueSourceType.custom,
        );

        final modified = original.copyWith(title: '新标题', cid: 202);

        expect(modified.title, equals('新标题'));
        expect(modified.cid, equals(202));
        expect(modified.id, equals('test_1'));
        expect(modified, equals(original)); // id-based equality
      },
    );
  });
}

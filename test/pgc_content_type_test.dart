import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/common/pgc_type.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/models/common/video_source_type.dart';

void main() {
  group('PgcCatalogType', () {
    test('maps every supported catalog to the official API value', () {
      expect(PgcCatalogType.values.map((item) => item.apiValue).toList(), <int>[
        1,
        4,
        2,
        5,
        3,
        7,
      ]);
      expect(PgcCatalogType.values.map((item) => item.label).toList(), <String>[
        '番剧',
        '国创',
        '电影',
        '电视剧',
        '纪录片',
        '综艺',
      ]);
    });

    test('uses the two official follow groups', () {
      expect(PgcCatalogType.bangumi.followGroup.apiValue, 1);
      expect(PgcCatalogType.guochuang.followGroup.apiValue, 1);
      expect(PgcCatalogType.movie.followGroup.apiValue, 2);
      expect(PgcCatalogType.tv.followGroup.apiValue, 2);
      expect(PgcCatalogType.documentary.followGroup.apiValue, 2);
      expect(PgcCatalogType.variety.followGroup.apiValue, 2);
      expect(PgcCatalogType.bangumi.continueSectionLabel, '继续观看');
      expect(PgcCatalogType.movie.continueSectionLabel, '继续观看');
      expect(PgcFollowGroup.bangumi.continueScopeLabel, '番剧 · 国创');
      expect(PgcFollowGroup.cinema.continueScopeLabel, '电影 · 电视剧 · 纪录片 · 综艺');
    });

    test('restores persisted values with a safe bangumi fallback', () {
      expect(PgcCatalogTypeCode.fromApiValue(5), PgcCatalogType.tv);
      expect(PgcCatalogTypeCode.fromApiValue(999), PgcCatalogType.bangumi);
      expect(PgcCatalogTypeCode.fromApiValue(null), PgcCatalogType.bangumi);
    });
  });

  test('PGC catalog orders match the official query values', () {
    expect(PgcCatalogOrder.values.map((item) => item.apiValue).toList(), <int>[
      0,
      2,
      3,
      4,
    ]);
    expect(PgcCatalogOrder.values.map((item) => item.label).toList(), <String>[
      '更新时间',
      '播放最多',
      '追番/追剧最多',
      '评分最高',
    ]);
    expect(PgcCatalogOrderCode.fromApiValue(999), PgcCatalogOrder.mostFollowed);
    expect(
      PgcCatalogOrder.mostFollowed.labelFor(PgcFollowGroup.bangumi),
      '追番最多',
    );
    expect(
      PgcCatalogOrder.mostFollowed.labelFor(PgcFollowGroup.cinema),
      '追剧最多',
    );
  });

  test('search and playback types remain separate', () {
    expect(SearchType.media_bangumi.type, 'media_bangumi');
    expect(SearchType.media_ft.type, 'media_ft');
    expect(SearchType.media_ft.label, '影视');
    expect(VideoSourceType.archive.isPgc, isFalse);
    expect(VideoSourceType.pgc.isPgc, isTrue);
  });
}

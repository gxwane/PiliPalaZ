enum PgcFollowGroup {
  bangumi(1),
  cinema(2);

  const PgcFollowGroup(this.apiValue);

  final int apiValue;

  String get continueScopeLabel => switch (this) {
    PgcFollowGroup.bangumi => '番剧 · 国创',
    PgcFollowGroup.cinema => '电影 · 电视剧 · 纪录片 · 综艺',
  };
}

abstract final class PgcSettingKey {
  static const String catalogType = 'lastPgcCatalogType';
  static const String catalogOrder = 'lastPgcCatalogOrder';
}

enum PgcCatalogType {
  bangumi(1, '番剧', PgcFollowGroup.bangumi),
  guochuang(4, '国创', PgcFollowGroup.bangumi),
  movie(2, '电影', PgcFollowGroup.cinema),
  tv(5, '电视剧', PgcFollowGroup.cinema),
  documentary(3, '纪录片', PgcFollowGroup.cinema),
  variety(7, '综艺', PgcFollowGroup.cinema);

  const PgcCatalogType(this.apiValue, this.label, this.followGroup);

  final int apiValue;
  final String label;
  final PgcFollowGroup followGroup;

  String get followSectionLabel =>
      followGroup == PgcFollowGroup.bangumi ? '最近追番' : '最近追剧';

  String get continueSectionLabel => '继续观看';

  String get followActionLabel =>
      followGroup == PgcFollowGroup.bangumi ? '追番' : '追剧';
}

extension PgcCatalogTypeCode on PgcCatalogType {
  static PgcCatalogType fromApiValue(Object? value) {
    final int? apiValue = switch (value) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    return PgcCatalogType.values.firstWhere(
      (item) => item.apiValue == apiValue,
      orElse: () => PgcCatalogType.bangumi,
    );
  }
}

enum PgcCatalogOrder {
  latest(0, '更新时间'),
  mostPlayed(2, '播放最多'),
  mostFollowed(3, '追番/追剧最多'),
  highestRated(4, '评分最高');

  const PgcCatalogOrder(this.apiValue, this.label);

  final int apiValue;
  final String label;

  String labelFor(PgcFollowGroup group) {
    if (this != PgcCatalogOrder.mostFollowed) return label;
    return group == PgcFollowGroup.bangumi ? '追番最多' : '追剧最多';
  }
}

extension PgcCatalogOrderCode on PgcCatalogOrder {
  static PgcCatalogOrder fromApiValue(Object? value) {
    final int? apiValue = switch (value) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    return PgcCatalogOrder.values.firstWhere(
      (item) => item.apiValue == apiValue,
      orElse: () => PgcCatalogOrder.mostFollowed,
    );
  }
}

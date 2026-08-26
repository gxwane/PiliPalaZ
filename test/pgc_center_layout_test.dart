import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/bangumi/list.dart';
import 'package:pilipalaz/models/common/pgc_type.dart';
import 'package:pilipalaz/pages/bangumi/widgets/bangumi_card_v.dart';
import 'package:pilipalaz/pages/bangumi/widgets/pgc_center_sections.dart';
import 'package:pilipalaz/services/pgc_vip_entitlement_resolver.dart';

void main() {
  test(
    'poster grid stays at three columns on phones and adapts on tablets',
    () {
      expect(pgcPosterColumnCount(320), 3);
      expect(pgcPosterColumnCount(430), 3);
      expect(pgcPosterColumnCount(599), 3);
      expect(pgcPosterColumnCount(640), 4);
      expect(pgcPosterColumnCount(800), 5);
      expect(pgcPosterColumnCount(1200), 6);
    },
  );

  testWidgets('category bar exposes every catalog and reports selection', (
    tester,
  ) async {
    PgcCatalogType? selected;

    await tester.pumpWidget(
      _testApp(
        PgcCategoryBar(
          selectedType: PgcCatalogType.bangumi,
          onSelected: (value) => selected = value,
        ),
      ),
    );

    for (final type in PgcCatalogType.values) {
      expect(find.text(type.label), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey<String>('pgc-category-movie')));
    expect(selected, PgcCatalogType.movie);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets(
      'category bar uses an unfilled underline selection in ${brightness.name} mode',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            PgcCategoryBar(
              selectedType: PgcCatalogType.bangumi,
              onSelected: (_) {},
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.getSize(find.byType(PgcCategoryBar)).height, 44);
        final BuildContext barContext = tester.element(
          find.byType(PgcCategoryBar),
        );
        final ThemeData theme = Theme.of(barContext);
        final Finder opaqueBarBackground = find.descendant(
          of: find.byType(PgcCategoryBar),
          matching: find.byWidgetPredicate((Widget widget) {
            if (widget is! DecoratedBox ||
                widget.decoration is! BoxDecoration) {
              return false;
            }
            return (widget.decoration as BoxDecoration).color ==
                theme.scaffoldBackgroundColor;
          }),
        );
        expect(opaqueBarBackground, findsNothing);

        final Finder selectedItem = find.byKey(
          const ValueKey<String>('pgc-category-bangumi'),
        );
        final Finder selectedMaterial = find.descendant(
          of: selectedItem,
          matching: find.byType(Material),
        );
        expect(
          tester.widget<Material>(selectedMaterial.first).color,
          Colors.transparent,
        );
        final AnimatedDefaultTextStyle selectedTextStyle = tester
            .widget<AnimatedDefaultTextStyle>(
              find
                  .descendant(
                    of: selectedItem,
                    matching: find.byType(AnimatedDefaultTextStyle),
                  )
                  .last,
            );
        expect(selectedTextStyle.style.color, theme.colorScheme.primary);

        final Finder unselectedItem = find.byKey(
          const ValueKey<String>('pgc-category-movie'),
        );
        final AnimatedDefaultTextStyle unselectedTextStyle = tester
            .widget<AnimatedDefaultTextStyle>(
              find
                  .descendant(
                    of: unselectedItem,
                    matching: find.byType(AnimatedDefaultTextStyle),
                  )
                  .last,
            );
        expect(
          unselectedTextStyle.style.color,
          theme.colorScheme.onSurfaceVariant,
        );

        final Finder indicator = find.byKey(
          const ValueKey<String>('pgc-category-indicator-bangumi'),
        );
        expect(tester.getSize(indicator), const Size(18, 2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('continue section uses compact cards and real text only', (
    tester,
  ) async {
    final items = <BangumiListItemModel>[
      _item(
        seasonId: 1,
        title: '迷雾列车',
        progress: '看到第 8 话 · 12:36',
        indexShow: '更新至第 10 话',
      ),
      _item(
        seasonId: 2,
        title: '星海回声',
        progress: '看到第 5 话',
        indexShow: '更新至第 7 话',
      ),
    ];

    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 430,
          child: PgcContinueSection(
            title: '继续观看',
            scopeLabel: '番剧 · 国创',
            items: items,
            loading: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('番剧 · 国创'), findsOneWidget);
    expect(find.text('迷雾列车'), findsOneWidget);
    expect(find.text('看到第 8 话 · 12:36'), findsOneWidget);
    expect(find.text('更新至第 10 话'), findsOneWidget);
    expect(find.text('全部'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    final Size cardSize = tester.getSize(find.byType(PgcContinueCard).first);
    expect(cardSize.width, inInclusiveRange(248, 288));
    expect(cardSize.height, lessThanOrEqualTo(112));
  });

  testWidgets('continue section disappears when there is no content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        PgcContinueSection(
          title: '继续观看',
          scopeLabel: '电影 · 电视剧 · 纪录片 · 综艺',
          items: const <BangumiListItemModel>[],
          loading: false,
          onTap: (_) {},
        ),
      ),
    );

    expect(find.text('继续观看'), findsNothing);
    expect(find.byType(PgcContinueCard), findsNothing);
  });

  testWidgets('catalog header uses the follow-group-specific sort label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        PgcCatalogSectionHeader(
          title: '电影精选',
          selectedOrder: PgcCatalogOrder.mostFollowed,
          followGroup: PgcFollowGroup.cinema,
          onOrderSelected: (_) {},
        ),
      ),
    );

    expect(find.text('电影精选'), findsOneWidget);
    expect(find.text('追剧最多'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('poster card prioritizes score and update status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 140,
          height: 280,
          child: BangumiCardV(
            bangumiItem: _item(
              seasonId: 1,
              title: '春日信笺',
              badge: '会员',
              badgeType: 0,
              score: '9.8',
              order: '1234万追番',
              indexShow: '更新至第 6 话',
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('会员'), findsOneWidget);
    expect(find.text('9.8分'), findsOneWidget);
    expect(find.text('1234万追番'), findsNothing);
    expect(find.text('春日信笺'), findsOneWidget);
    expect(find.text('更新至第 6 话'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('poster card only hides a verified unrestricted VIP badge', (
    tester,
  ) async {
    final BangumiListItemModel item = _item(
      seasonId: 1,
      title: '三国演义',
      badge: '大会员',
      badgeType: 0,
    );

    Future<void> pump(PgcVipEntitlement? entitlement) => tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 140,
          height: 280,
          child: BangumiCardV(
            bangumiItem: item,
            vipEntitlement: entitlement,
            onTap: () {},
          ),
        ),
      ),
    );

    await pump(null);
    expect(find.text('大会员'), findsOneWidget);

    await pump(PgcVipEntitlement.restricted);
    expect(find.text('大会员'), findsOneWidget);

    await pump(PgcVipEntitlement.unrestricted);
    expect(find.text('大会员'), findsNothing);
  });
}

Widget _testApp(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

BangumiListItemModel _item({
  required int seasonId,
  required String title,
  String? badge,
  int? badgeType,
  String? score,
  String? order,
  String? progress,
  String? indexShow,
}) => BangumiListItemModel(
  seasonId: seasonId,
  mediaId: seasonId,
  title: title,
  badge: badge,
  badgeType: badgeType,
  score: score,
  order: order,
  progress: progress,
  indexShow: indexShow,
);

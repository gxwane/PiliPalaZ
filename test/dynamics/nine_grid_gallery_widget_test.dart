import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/badge.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/pages/dynamics/widgets/nine_grid_gallery.dart';

void main() {
  testWidgets('NineGridGallery renders SizedBox.shrink when items is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NineGridGallery(items: []),
        ),
      ),
    );

    expect(find.byType(NineGridGallery), findsOneWidget);
    expect(find.byType(NetworkImgLayer), findsNothing);
  });

  testWidgets('NineGridGallery single long image renders with PBadge and Hero tag',
      (WidgetTester tester) async {
    final longPic = OpusPicsModel(
      url: 'https://example.com/long.jpg',
      width: 400,
      height: 1200,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: NineGridGallery(
              items: [longPic],
              sourceScope: 'test_feed',
              dynamicId: 'dyn_123',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NetworkImgLayer), findsOneWidget);
    // Verifies '长图' badge is displayed
    expect(find.byType(PBadge), findsOneWidget);
    expect(find.text('长图'), findsOneWidget);

    // Verifies Hero tag has predictable format
    final heroFinder = find.byType(Hero);
    expect(heroFinder, findsOneWidget);
    final Hero heroWidget = tester.widget(heroFinder);
    expect(heroWidget.tag, equals('hero_gallery_test_feed_dyn_123_0'));
  });

  testWidgets('NineGridGallery 4 items renders 2x2 grid with crossAxisCount: 2',
      (WidgetTester tester) async {
    final items = [
      'https://example.com/1.jpg',
      'https://example.com/2.jpg',
      'https://example.com/3.jpg',
      'https://example.com/4.jpg',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: NineGridGallery(
              items: items,
              sourceScope: 'test_feed',
              dynamicId: 'dyn_444',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verifies 4 images are displayed
    expect(find.byType(NetworkImgLayer), findsNWidgets(4));

    // Verifies GridView is configured with crossAxisCount: 2 (SPEC-01)
    final gridFinder = find.byType(GridView);
    expect(gridFinder, findsOneWidget);
    final GridView gridView = tester.widget(gridFinder);
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, equals(2));

    // Verifies 4 distinct hero tags
    final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
    expect(heroes.length, equals(4));
    expect(heroes[0].tag, equals('hero_gallery_test_feed_dyn_444_0'));
    expect(heroes[1].tag, equals('hero_gallery_test_feed_dyn_444_1'));
    expect(heroes[2].tag, equals('hero_gallery_test_feed_dyn_444_2'));
    expect(heroes[3].tag, equals('hero_gallery_test_feed_dyn_444_3'));
  });

  testWidgets('NineGridGallery 9 items renders 3x3 grid with crossAxisCount: 3',
      (WidgetTester tester) async {
    final items = List.generate(9, (index) => 'https://example.com/$index.jpg');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: NineGridGallery(
              items: items,
              sourceScope: 'test_feed',
              dynamicId: 'dyn_999',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NetworkImgLayer), findsNWidgets(9));

    final gridFinder = find.byType(GridView);
    expect(gridFinder, findsOneWidget);
    final GridView gridView = tester.widget(gridFinder);
    final delegate =
        gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, equals(3));
  });
}

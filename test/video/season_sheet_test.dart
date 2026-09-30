import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/season_sheet.dart';

import '../journeys/support/journey_test_environment.dart';

Widget _wrapInTestApp(Widget child) {
  return GetMaterialApp(home: Scaffold(body: child));
}

void main() {
  setUpAll(() async {
    await initTestStorage();
  });

  group('SeasonSheetContent Widget & Interaction Tests', () {
    late UgcSeason mockUgcSeason;

    setUp(() {
      mockUgcSeason = UgcSeason.fromJson(<String, dynamic>{
        'id': 100,
        'title': '鹅鹅鹅的美食记录',
        'sections': <dynamic>[
          <String, dynamic>{
            'season_id': 100,
            'id': 1001,
            'title': '肯德基',
            'episodes': <dynamic>[
              <String, dynamic>{
                'cid': 111,
                'aid': 1,
                'bvid': 'BV111',
                'title': 'KFC 早餐',
              },
              <String, dynamic>{
                'cid': 112,
                'aid': 1,
                'bvid': 'BV112',
                'title': 'KFC 半价桶',
              },
            ],
          },
          <String, dynamic>{
            'season_id': 100,
            'id': 1002,
            'title': '等等',
            'episodes': <dynamic>[
              <String, dynamic>{
                'cid': 221,
                'aid': 2,
                'bvid': 'BV221',
                'title': '塔斯汀汉堡',
              },
            ],
          },
          <String, dynamic>{
            'season_id': 100,
            'id': 1003,
            'title': '麦当劳',
            'episodes': <dynamic>[
              <String, dynamic>{
                'cid': 331,
                'aid': 3,
                'bvid': 'BV331',
                'title': '麦旋风',
              },
            ],
          },
        ],
      });
    });

    testWidgets('renders total episodes and horizontal section tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          SeasonSheetContent(
            ugcSeason: mockUgcSeason,
            currentCid: 111,
            changeFucCall: (_, _, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total 4 episodes: 2 + 1 + 1
      expect(find.text('合集（共4集）'), findsOneWidget);

      // Section tabs rendered with counts
      expect(find.text('肯德基 (2)'), findsOneWidget);
      expect(find.text('等等 (1)'), findsOneWidget);
      expect(find.text('麦当劳 (1)'), findsOneWidget);

      // Current section (KFC) shows its episodes
      expect(find.text('KFC 早餐'), findsOneWidget);
    });

    testWidgets('automatically activates the section containing currentCid', (
      tester,
    ) async {
      // currentCid 221 belongs to section 2 (等等)
      await tester.pumpWidget(
        _wrapInTestApp(
          SeasonSheetContent(
            ugcSeason: mockUgcSeason,
            currentCid: 221,
            changeFucCall: (_, _, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should automatically display episode for section 2 (等等)
      expect(find.text('塔斯汀汉堡'), findsOneWidget);
    });

    testWidgets('switching section tab updates episodes safely without crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          SeasonSheetContent(
            ugcSeason: mockUgcSeason,
            currentCid: 111,
            changeFucCall: (_, _, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on '麦当劳 (1)' section chip
      await tester.tap(find.text('麦当劳 (1)'));
      await tester.pumpAndSettle();

      // Now showing McDonald's episode (1 item)
      expect(find.text('1/1'), findsOneWidget);

      // Reverse toggle
      await tester.tap(find.byTooltip('反序'));
      await tester.pumpAndSettle();

      // Scroll buttons work safely
      await tester.tap(find.byTooltip('跳至顶部'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('跳至底部'));
      await tester.pumpAndSettle();
    });

    testWidgets('single section season hides section tabs', (tester) async {
      final singleSectionSeason = UgcSeason.fromJson(<String, dynamic>{
        'id': 200,
        'title': '单卷合集',
        'sections': <dynamic>[
          <String, dynamic>{
            'season_id': 200,
            'id': 2001,
            'title': '唯一分卷',
            'episodes': <dynamic>[
              <String, dynamic>{
                'cid': 501,
                'aid': 5,
                'bvid': 'BV501',
                'title': 'Episode 1',
              },
            ],
          },
        ],
      });

      await tester.pumpWidget(
        _wrapInTestApp(
          SeasonSheetContent(
            ugcSeason: singleSectionSeason,
            currentCid: 501,
            changeFucCall: (_, _, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title shows compact format
      expect(find.text('合集（1）'), findsOneWidget);

      // Section chip is hidden since sections.length == 1
      expect(find.text('唯一分卷 (1)'), findsNothing);
    });

    testWidgets(
      'multi-part video with same bvid matches exact cid without false match',
      (tester) async {
        final multiPartSeason = UgcSeason.fromJson(<String, dynamic>{
          'id': 300,
          'title': '多P合集',
          'sections': <dynamic>[
            <String, dynamic>{
              'season_id': 300,
              'id': 3001,
              'title': '第一卷',
              'episodes': <dynamic>[
                <String, dynamic>{
                  'cid': 9001,
                  'aid': 90,
                  'bvid': 'BV_SAME',
                  'title': 'Part 1',
                },
                <String, dynamic>{
                  'cid': 9002,
                  'aid': 90,
                  'bvid': 'BV_SAME',
                  'title': 'Part 2',
                },
              ],
            },
          ],
        });

        await tester.pumpWidget(
          _wrapInTestApp(
            SeasonSheetContent(
              ugcSeason: multiPartSeason,
              currentCid: 9002,
              currentBvid: 'BV_SAME',
              changeFucCall: (_, _, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Part 2 should be selected, Part 1 should not be selected
        final listTiles =
            tester.widgetList<ListTile>(find.byType(ListTile)).toList();
        expect(listTiles.length, 2);
        expect(listTiles[0].selected, isFalse);
        expect(listTiles[1].selected, isTrue);
      },
    );
  });
}

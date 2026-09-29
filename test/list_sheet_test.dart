import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/list_sheet.dart';
import 'package:pilipalaz/models/video_detail_res.dart';

import 'journeys/support/journey_test_environment.dart';

Widget _wrapInTestApp(Widget child) {
  return GetMaterialApp(home: Scaffold(body: child));
}

void main() {
  setUpAll(() async {
    await initTestStorage();
  });

  group('ListSheetContent Safety & Boundary Tests', () {
    testWidgets(
      'Happy Path: currentCid in episodes jumps to index without error',
      (tester) async {
        final episodes = List.generate(
          29,
          (i) => EpisodeItem(
            cid: 1000 + i,
            title: 'Episode ${i + 1}',
            aid: 1,
            bvid: 'BV1',
          ),
        );
        await tester.pumpWidget(
          _wrapInTestApp(
            ListSheetContent(
              episodes: episodes,
              currentCid: 1005,
              changeFucCall: (_, _, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('合集（29）'), findsOneWidget);
      },
    );

    testWidgets(
      'Edge Case: currentCid not in episodes does NOT throw RangeError',
      (tester) async {
        final episodes = List.generate(
          29,
          (i) => EpisodeItem(
            cid: 1000 + i,
            title: 'Episode ${i + 1}',
            aid: 1,
            bvid: 'BV1',
          ),
        );
        await tester.pumpWidget(
          _wrapInTestApp(
            ListSheetContent(
              episodes: episodes,
              currentCid: 99999,
              changeFucCall: (_, _, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('合集（29）'), findsOneWidget);
      },
    );

    testWidgets(
      'Edge Case: empty episodes list renders safely and button actions do not crash',
      (tester) async {
        final episodes = <EpisodeItem>[];
        await tester.pumpWidget(
          _wrapInTestApp(
            ListSheetContent(
              episodes: episodes,
              currentCid: 1000,
              changeFucCall: (_, _, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('合集（0）'), findsOneWidget);

        // Verify safe tap on buttons even with empty list
        await tester.tap(find.byTooltip('跳至顶部'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('跳至底部'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('反序'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Edge Case: reverse order toggle works with populated episodes',
      (tester) async {
        final episodes = List.generate(
          10,
          (i) => EpisodeItem(
            cid: 2000 + i,
            title: 'Episode ${i + 1}',
            aid: 2,
            bvid: 'BV2',
          ),
        );
        await tester.pumpWidget(
          _wrapInTestApp(
            ListSheetContent(
              episodes: episodes,
              currentCid: 2003,
              changeFucCall: (_, _, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Toggle reverse
        await tester.tap(find.byTooltip('反序'));
        await tester.pumpAndSettle();

        // Test jump to top and bottom in reversed mode
        await tester.tap(find.byTooltip('跳至顶部'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('跳至底部'));
        await tester.pumpAndSettle();
      },
    );
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/page.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/season.dart';

import '../journeys/support/journey_test_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestStorage();
  });

  setUp(() async {
    await clearTestStorage();
    Get.reset();
  });

  tearDown(() async {
    Get.reset();
  });

  group('GetX Rx close vs subscription cancel bug verification', () {
    test('calling close() on RxInt causes subscription.cancel() to throw unhandled Null check operator', () async {
      final testRx = 100.obs;
      final StreamSubscription<int> sub = testRx.listen((val) {});

      // Closing the RxInt marks internal GetStream as closed and sets _isBusy = null
      testRx.close();

      dynamic caughtError;
      await runZonedGuarded(() async {
        sub.cancel();
      }, (error, stack) {
        caughtError = error;
      });
      await Future<void>.delayed(Duration.zero);

      expect(caughtError, isA<TypeError>());
      expect(caughtError.toString(), contains('Null check operator used on a null value'));
    });
  });

  group('SeasonPanel & PagesPanel Subscription Lifecycle TDD Tests', () {
    const testHeroTag = 'lifecycle_hero_tag';

    final testSeason = UgcSeason.fromJson(<String, dynamic>{
      'id': 1,
      'title': '测试合集',
      'stat': <String, dynamic>{},
      'sections': <dynamic>[
        <String, dynamic>{
          'season_id': 1,
          'id': 10,
          'title': '第一季',
          'episodes': <dynamic>[
            <String, dynamic>{
              'cid': 101,
              'aid': 1,
              'title': '第1集',
              'page': <String, dynamic>{'cid': 101, 'page': 1, 'part': 'P1'},
            },
            <String, dynamic>{
              'cid': 102,
              'aid': 1,
              'title': '第2集',
              'page': <String, dynamic>{'cid': 102, 'page': 2, 'part': 'P2'},
            },
          ],
        },
      ],
    });

    final testPages = <Part>[
      Part.fromJson(<String, dynamic>{
        'cid': 101,
        'page': 1,
        'part': '第1部分',
        'duration': 120,
      }),
      Part.fromJson(<String, dynamic>{
        'cid': 102,
        'page': 2,
        'part': '第2部分',
        'duration': 180,
      }),
    ];

    testWidgets('SeasonPanel unmounts cleanly and cancels _cidSub when controller is active', (
      WidgetTester tester,
    ) async {
      final controller = Get.put(VideoDetailController(), tag: testHeroTag);
      controller.cid.value = 101;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonPanel(
              ugcSeason: testSeason,
              cid: 101,
              changeFuc: (dynamic bvid, dynamic cid, dynamic aid) {},
              heroTag: testHeroTag,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger cid update
      controller.cid.value = 102;
      await tester.pump();

      // Unmount SeasonPanel by replacing child with SizedBox
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no unhandled exception occurred during unmount
      expect(tester.takeException(), isNull);
    });

    testWidgets('SeasonPanel unmounts safely even if cid was prematurely closed (defensive guard)', (
      WidgetTester tester,
    ) async {
      final controller = Get.put(VideoDetailController(), tag: testHeroTag);
      controller.cid.value = 101;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonPanel(
              ugcSeason: testSeason,
              cid: 101,
              changeFuc: (dynamic bvid, dynamic cid, dynamic aid) {},
              heroTag: testHeroTag,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate the bug where parent prematurely calls cid.close()
      controller.cid.close();

      // Unmount SeasonPanel
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      // With defensive guard, unmount does NOT crash
      expect(tester.takeException(), isNull);
    });

    testWidgets('PagesPanel unmounts cleanly and properly manages subscription', (
      WidgetTester tester,
    ) async {
      final controller = Get.put(VideoDetailController(), tag: testHeroTag);
      controller.cid.value = 101;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagesPanel(
              pages: testPages,
              cid: 101,
              bvid: 'BV1test',
              changeFuc: (dynamic cid) {},
              heroTag: testHeroTag,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger cid update
      controller.cid.value = 102;
      await tester.pump();

      // Unmount PagesPanel
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PagesPanel unmounts safely even if cid was prematurely closed (defensive guard)', (
      WidgetTester tester,
    ) async {
      final controller = Get.put(VideoDetailController(), tag: testHeroTag);
      controller.cid.value = 101;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagesPanel(
              pages: testPages,
              cid: 101,
              bvid: 'BV1test',
              changeFuc: (dynamic cid) {},
              heroTag: testHeroTag,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Premature close simulation
      controller.cid.close();

      // Unmount PagesPanel
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

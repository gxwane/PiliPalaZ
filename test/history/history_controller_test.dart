import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/http_runtime.dart';
import 'package:pilipalaz/models/user/history.dart';
import 'package:pilipalaz/pages/history/controller.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

import '../support/http_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-history-test-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
  });

  tearDownAll(() async {
    HttpRuntime.resetForTesting();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('HistoryController.resolveResourceKid', () {
    test('resolves default and archive business', () {
      expect(
        HistoryController.resolveResourceKid(12345, null),
        'archive_12345',
      );
      expect(HistoryController.resolveResourceKid(12345, ''), 'archive_12345');
      expect(
        HistoryController.resolveResourceKid(12345, 'archive'),
        'archive_12345',
      );
      expect(
        HistoryController.resolveResourceKid(12345, 'ARCHIVE'),
        'archive_12345',
      );
    });

    test('resolves live business', () {
      expect(HistoryController.resolveResourceKid(999, 'live'), 'live_999');
    });

    test('resolves article business', () {
      expect(
        HistoryController.resolveResourceKid(888, 'article'),
        'article_888',
      );
      expect(
        HistoryController.resolveResourceKid(888, 'article-read'),
        'article_888',
      );
    });

    test('resolves pgc business', () {
      expect(HistoryController.resolveResourceKid(777, 'pgc'), 'pgc_777');
      expect(HistoryController.resolveResourceKid(777, 'PGC'), 'pgc_777');
    });

    test('avoids double prefixing if kid already formatted', () {
      expect(
        HistoryController.resolveResourceKid('archive_12345', 'archive'),
        'archive_12345',
      );
      expect(
        HistoryController.resolveResourceKid('live_999', 'live'),
        'live_999',
      );
    });
  });

  group('HistoryController deletion workflows', () {
    late HistoryController controller;

    setUp(() {
      controller = HistoryController();
    });

    tearDown(() {
      SmartDialog.dismiss();
    });

    testWidgets('onDelHistory does nothing when no completed items exist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: FlutterSmartDialog.init(),
          home: const Scaffold(),
        ),
      );

      controller.historyList.addAll([
        HisListItem(
          kid: 1,
          progress: 50,
          history: History(oid: 1, business: 'archive'),
        ),
        HisListItem(
          kid: 2,
          progress: 10,
          history: History(oid: 2, business: 'live'),
        ),
      ]);

      await tester.runAsync(() async {
        await controller.onDelHistory();
      });
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // All items should still be in historyList
      expect(controller.historyList.length, 2);
    });

    testWidgets(
      'onDelHistory batch deletes completed items with correct resource kids',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: FlutterSmartDialog.init(),
            home: const Scaffold(),
          ),
        );

        final harness = HttpTestHarness((request) {
          if (request.path == Api.delHistory) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'message': '0',
            });
          }
          return jsonResponse(<String, Object?>{'code': -400});
        });

        controller.historyList.addAll([
          HisListItem(
            kid: 101,
            progress: -1,
            history: History(oid: 101, business: 'archive'),
          ),
          HisListItem(
            kid: 102,
            progress: 50,
            history: History(oid: 102, business: 'archive'),
          ),
          HisListItem(
            kid: 103,
            progress: -1,
            history: History(oid: 103, business: 'pgc'),
          ),
        ]);

        await tester.runAsync(() async {
          await harness.run(() => controller.onDelHistory());
        });
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Only incomplete item should remain
        expect(controller.historyList.length, 1);
        expect(controller.historyList.first.kid, 102);

        // Verify harness captured the deleted kids in queryParameters
        final deletedKids = harness.requests
            .where((r) => r.path == Api.delHistory)
            .map((r) => r.queryParameters['kid'] as String)
            .toList();
        expect(deletedKids, containsAll(['archive_101', 'pgc_103']));
      },
    );

    testWidgets(
      'delHistory deletes single item with correct resolved kid',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: FlutterSmartDialog.init(),
            home: const Scaffold(),
          ),
        );

        final harness = HttpTestHarness((request) {
          if (request.path == Api.delHistory) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'message': '0',
            });
          }
          return jsonResponse(<String, Object?>{'code': -400});
        });

        controller.historyList.addAll([
          HisListItem(
            kid: 201,
            progress: 30,
            history: History(oid: 201, business: 'pgc'),
          ),
        ]);

        await tester.runAsync(() async {
          await harness.run(() => controller.delHistory(201, 'pgc'));
        });
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(controller.historyList.isEmpty, isTrue);
        final deletedKid = harness.requests.first.queryParameters['kid'];
        expect(deletedKid, 'pgc_201');
      },
    );
  });
}

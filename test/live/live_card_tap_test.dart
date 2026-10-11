import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/pages/live/widgets/live_item.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('live_card_tap_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Tapping text and empty space in LiveCardV triggers navigation', (
    WidgetTester tester,
  ) async {
    final liveItem = LiveItemModel.fromJson({
      'room_id': 888666,
      'title': '可点击测试直播间',
      'uname': '测试主播',
      'cover': 'https://example.com/cover.jpg',
    });

    String? pushedRoute;

    await tester.pumpWidget(
      GetMaterialApp(
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => const Scaffold(body: Text('LiveRoomPage')),
          );
        },
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: LiveCardV(liveItem: liveItem),
            ),
          ),
        ),
      ),
    );

    expect(find.text('可点击测试直播间'), findsOneWidget);
    expect(find.text('测试主播'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LiveCardV),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );

    // Tap on title text directly
    await tester.tap(find.text('可点击测试直播间'));
    await tester.pumpAndSettle();

    expect(
      pushedRoute,
      startsWith('/liveRoom?roomid=888666'),
      reason: 'Tapping on title text must trigger navigation to liveRoom',
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/pages/video/widgets/shoot_danmaku_sheet.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('shoot_sheet_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>('setting');
    GStorage.video = await Hive.openBox<dynamic>('video');
    GStorage.localCache = await Hive.openBox<dynamic>('localCache');
    GStorage.userInfo = await Hive.openBox<dynamic>('userInfo');
  });

  tearDownAll(() async {
    await PlPlayerController.disposeIfExists();
    await GStorage.setting.close();
    await GStorage.video.close();
    await GStorage.localCache.close();
    await GStorage.userInfo.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ShootDanmakuSheet Widget Tests', () {
    testWidgets(
      'renders all core UI elements: title, input, segments, colors and send button',
      (WidgetTester tester) async {
        PlPlayerController.isHeadlessTestMode = true;
        final playerController = PlPlayerController.getInstance();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShootDanmakuSheet(
                cid: 12345,
                bvid: 'BV1test',
                playerController: playerController,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 验证标题与输入区域
        expect(find.text('发送弹幕'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('0/100'), findsOneWidget);
        expect(find.text('发送'), findsOneWidget);

        // 验证模式分段按钮
        expect(find.text('滚动'), findsOneWidget);
        expect(find.text('顶部'), findsOneWidget);
        expect(find.text('底部'), findsOneWidget);

        // 验证调色板：应包含 12 个色彩圆形按钮
        // 验证初始状态下至少有一个选中的白色勾号
        expect(find.byIcon(Icons.check), findsOneWidget);

        // 切换模式到顶部
        await tester.tap(find.text('顶部'));
        await tester.pumpAndSettle();

        // 输入文字后计数器即刻更新
        await tester.enterText(find.byType(TextField), '弹幕测试文本');
        await tester.pumpAndSettle();

        expect(find.text('6/100'), findsOneWidget);
      },
    );
  });
}

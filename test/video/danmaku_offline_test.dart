import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/pages/danmaku/controller.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('danmaku_offline_test_');
    Hive.init(tmpDir.path);
    try {
      GStorage.setting = await Hive.openBox<dynamic>('setting');
    } catch (_) {}
    try {
      GStorage.onlineCache = await Hive.openBox<dynamic>('onlineCache');
    } catch (_) {}
  });

  tearDownAll(() async {
    await Hive.close();
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('PlDanmakuController 离线模式下即使无文件所有分段也置为true，杜绝空转', () async {
    final controller = PlDanmakuController(12345, isOffline: true);
    // 视频时长 10 分钟 (600,000 ms)
    controller.initiate(600000, 0);

    expect(controller.requestedSeg.isNotEmpty, isTrue);
    expect(controller.requestedSeg.every((seg) => seg == true), isTrue);
    expect(controller.getCurrentDanmaku(1000), anyOf(isNull, isEmpty));
  });

  test('PlDanmakuController 离线模式下 queryDanmaku 短路', () async {
    final controller = PlDanmakuController(12345, isOffline: true);
    controller.queryDanmaku(0);
    expect(controller.requestedSeg.isEmpty, isTrue);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/pages/video/introduction/offline/view.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('offline_panel_test_');
    Hive.init(tmpDir.path);
    try {
      GStorage.setting = await Hive.openBox<dynamic>('setting');
    } catch (_) {}
    try {
      GStorage.userInfo = await Hive.openBox<dynamic>('userInfo');
    } catch (_) {}
    try {
      GStorage.localCache = await Hive.openBox<dynamic>('localCache');
    } catch (_) {}
    try {
      GStorage.video = await Hive.openBox<dynamic>('video');
    } catch (_) {}
  });

  tearDownAll(() async {
    Get.reset();
    await Hive.close();
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  testWidgets('OfflineVideoIntroPanel 正确渲染视频元数据且无在线互动栏', (
    WidgetTester tester,
  ) async {
    final task = DownloadTask(
      id: 'BV1offline_1001',
      bvid: 'BV1offline',
      cid: 1001,
      title: '离线纯享视频测试',
      partTitle: 'P1 第一部分',
      cover: 'http://example.com/cover.jpg',
      ownerName: '独立UP主',
      duration: 180,
      videoQuality: 80,
      videoQualityDesc: '1080P 高清',
      videoCodec: 'avc1.640032',
      audioQuality: 30280,
      status: DownloadTaskStatus.completed,
      totalBytes: 52428800,
      downloadedBytes: 52428800,
    );

    const heroTag = 'offlineTestTag';
    Get.parameters = {'bvid': 'BV1offline', 'cid': '1001'};
    Get.routing.args = {
      'heroTag': heroTag,
      'isOffline': true,
      'offlineTask': task,
    };

    Get.put(VideoDetailController(), tag: heroTag);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [OfflineVideoIntroPanel(heroTag: heroTag)],
          ),
        ),
      ),
    );

    expect(find.text('离线纯享视频测试'), findsOneWidget);
    expect(find.text('独立UP主'), findsOneWidget);
    expect(find.text('1080P 高清'), findsOneWidget);
    expect(find.text('avc1.640032'), findsOneWidget);
    expect(find.text('192K'), findsOneWidget);
    expect(find.text('查看在线视频'), findsOneWidget);

    // 严密断言：绝对不包含在线互动相关文本/元素
    expect(find.text('点赞'), findsNothing);
    expect(find.text('投币'), findsNothing);
    expect(find.text('人在看'), findsNothing);
    expect(find.text('相关推荐'), findsNothing);
    expect(find.text('评论'), findsNothing);
  });
}

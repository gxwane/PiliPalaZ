import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/widgets/download_sheet.dart';
import 'package:pilipalaz/services/download/download_dao.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadSheet.isRestricted 权益与试看前置拦截', () {
    test('null playUrlData 默认不拦截', () {
      expect(DownloadSheet.isRestricted(null), isFalse);
    });

    test('isDrm 为 true 时拦截', () {
      final model = PlayUrlModel()..isDrm = true;
      expect(DownloadSheet.isRestricted(model), isTrue);
    });

    test('isPreview 为 true 时拦截', () {
      final model = PlayUrlModel()..isPreview = true;
      expect(DownloadSheet.isRestricted(model), isTrue);
    });

    test('errorCode 为 -10403 或 10403 时拦截', () {
      final model1 = PlayUrlModel()..errorCode = -10403;
      expect(DownloadSheet.isRestricted(model1), isTrue);

      final model2 = PlayUrlModel()..errorCode = 10403;
      expect(DownloadSheet.isRestricted(model2), isTrue);
    });

    test('普通公开 UGC 视频不拦截', () {
      final model = PlayUrlModel()
        ..isDrm = false
        ..isPreview = false
        ..errorCode = 0;
      expect(DownloadSheet.isRestricted(model), isFalse);
    });
  });

  group('DownloadSheet 控件渲染、时长规范化与缓存状态感知 (BAC-16, BAC-18)', () {
    late VideoDetailData videoDetail;

    setUp(() {
      videoDetail = VideoDetailData.fromJson({
        'bvid': 'BV1sheet_test',
        'aid': 123456,
        'title': '测试视频标题',
        'pic': 'https://example.com/cover.jpg',
        'duration': 600,
        'cid': 1001,
        'owner': {'name': '测试UP主'},
        'pages': [
          {'cid': 1001, 'page': 1, 'part': '第一集 开始', 'duration': 300},
          {'cid': 1002, 'page': 2, 'part': '第二集 进展', 'duration': 3665},
        ],
      });
    });

    testWidgets('分P时长规范化为 mm:ss / hh:mm:ss 且不显示裸秒数 (BAC-18)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadSheet(
              videoDetail: videoDetail,
              playUrlData: PlayUrlModel()..acceptQuality = [80, 64, 32],
            ),
          ),
        ),
      );

      // 验证标题
      expect(find.text('离线缓存'), findsOneWidget);

      // 验证清晰度选项
      expect(find.text('1080P 高清'), findsOneWidget);

      // 验证时长格式化：300秒 -> 05:00；3665秒 -> 01:01:05
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('01:01:05'), findsOneWidget);

      // 严密断言：界面绝不包含裸秒数拼接（如“300秒”、“3665秒”）
      expect(find.textContaining('300秒'), findsNothing);
      expect(find.textContaining('3665秒'), findsNothing);
      expect(find.textContaining('秒'), findsNothing);
    });

    testWidgets('多选分P与全选切换', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadSheet(
              videoDetail: videoDetail,
              playUrlData: PlayUrlModel()..acceptQuality = [80],
            ),
          ),
        ),
      );

      final state = tester.state<DownloadSheetState>(
        find.byType(DownloadSheet),
      );

      // 初始选中第 1 个分 P (cid: 1001)
      expect(state.selectedCids, equals({1001}));

      // 点击全选
      await tester.tap(find.text('全选'));
      await tester.pump();

      expect(state.selectedCids, equals({1001, 1002}));
      expect(find.text('取消全选'), findsOneWidget);

      // 点击取消全选
      await tester.tap(find.text('取消全选'));
      await tester.pump();

      expect(state.selectedCids, isEmpty);
      expect(find.text('全选'), findsOneWidget);
    });

    testWidgets('单视频无 pages 时正确渲染单个选项且时长格式化规范', (WidgetTester tester) async {
      final singleVideo = VideoDetailData.fromJson({
        'bvid': 'BVsingle',
        'title': '独立单视频',
        'cid': 9999,
        'duration': 125,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DownloadSheet(videoDetail: singleVideo)),
        ),
      );

      expect(find.text('独立单视频'), findsOneWidget);
      expect(find.text('02:05'), findsOneWidget);
      expect(find.textContaining('125秒'), findsNothing);
      // 单视频不显示“全选”按钮
      expect(find.text('全选'), findsNothing);
    });
  });

  group('DownloadSheet 本地缓存感知与三态全选状态机 (BAC-16, BAC-17, BAC-18)', () {
    late Directory tmpDir;
    late DownloadDao dao;
    late DownloadService service;
    late VideoDetailData videoDetail;

    setUpAll(() async {
      tmpDir = await Directory.systemTemp.createTemp('download_sheet_test_');
      Hive.init(tmpDir.path);
      dao = await DownloadDao.init();
      final storageManager = DownloadStorageManager(
        directoryProvider: () async => tmpDir,
        diskSpaceProvider: (_) async => 10 * 1024 * 1024 * 1024,
      );
      service = await DownloadService.init(
        dao: dao,
        storageManager: storageManager,
      );

      videoDetail = VideoDetailData.fromJson({
        'bvid': 'BVmulti_parts',
        'aid': 998877,
        'title': '测试多P视频',
        'duration': 600,
        'owner': {'name': '测试UP主'},
        'pages': [
          {'cid': 2001, 'page': 1, 'part': '第一集', 'duration': 180},
          {'cid': 2002, 'page': 2, 'part': '第二集', 'duration': 240},
          {'cid': 2003, 'page': 3, 'part': '第三集', 'duration': 300},
        ],
      });

      // 预先写入第 1 集已完成 (cid: 2001, 1080P)
      final task1 = DownloadTask.create(
        bvid: 'BVmulti_parts',
        cid: 2001,
        title: '测试多P视频',
        partTitle: '第一集',
        cover: 'https://example.com/cover.jpg',
        ownerName: '测试UP主',
        duration: 180,
        videoQuality: 80,
        videoQualityDesc: '1080P 高清',
        videoCodec: 'avc1',
        audioQuality: 30280,
      ).copyWith(status: DownloadTaskStatus.completed);
      await dao.saveTask(task1);
    });

    tearDownAll(() async {
      await service.dispose();
      await dao.dispose();
      await Hive.close();
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    });

    testWidgets('感知本地已缓存状态、智能跳过已缓存默认勾选首个未完成项、展示状态胶囊徽标 (BAC-16, BAC-18)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadSheet(
              videoDetail: videoDetail,
              downloadService: service,
            ),
          ),
        ),
      );
      await tester.pump();

      // 验证第 1 集显示胶囊标签：“已缓存 · 1080P 高清”
      expect(find.text('已缓存 · 1080P 高清'), findsOneWidget);

      final state = tester.state<DownloadSheetState>(
        find.byType(DownloadSheet),
      );

      // 智能默认勾选：第 1 集已完成，因此默认智能勾选首个未完成项 (cid: 2002)
      expect(state.selectedCids, equals({2002}));

      // 验证三态“全选”按钮：当前显示“全选未缓存”
      expect(find.text('全选未缓存'), findsOneWidget);

      // 点击“全选未缓存” -> 勾选所有未缓存项 (2002, 2003)
      await tester.tap(find.text('全选未缓存'));
      await tester.pump();
      expect(state.selectedCids, equals({2002, 2003}));
      expect(find.text('全选所有'), findsOneWidget);

      // 点击“全选所有” -> 勾选全部 (2001, 2002, 2003)
      await tester.tap(find.text('全选所有'));
      await tester.pump();
      expect(state.selectedCids, equals({2001, 2002, 2003}));
      expect(find.text('取消全选'), findsOneWidget);

      // 点击“取消全选” -> 清空所有选中
      await tester.tap(find.text('取消全选'));
      await tester.pump();
      expect(state.selectedCids, isEmpty);
      expect(find.text('全选未缓存'), findsOneWidget);
    });

    testWidgets('提交下载四分法流水线：若所选均为同画质已缓存项，直接短路跳过 (BAC-17)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadSheet(
              videoDetail: videoDetail,
              downloadService: service,
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<DownloadSheetState>(
        find.byType(DownloadSheet),
      );

      // 只勾选已完成同画质的 cid: 2001 (1080P)
      state.toggleCid(2002); // 取消默认的 2002
      state.toggleCid(2001); // 勾选已完成的 2001
      await tester.pump();
      expect(state.selectedCids, equals({2001}));

      // 执行提交：应当短路跳过，不调用 startTask，且不引发任何网络请求或异常
      await state.submitDownload();
      await tester.pump();

      // 验证 cid 2001 依然为 completed 状态
      final task1 = service.getTask('BVmulti_parts_2001');
      expect(task1, isNotNull);
      expect(task1!.status, equals(DownloadTaskStatus.completed));
    });

    testWidgets('提交下载四分法流水线：画质冲突时弹出二次确认对话框且取消时不破坏原有任务 (BAC-17)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadSheet(
              videoDetail: videoDetail,
              downloadService: service,
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<DownloadSheetState>(
        find.byType(DownloadSheet),
      );

      // 在清晰度选择栏中点击 ChoiceChip 切换为「720P 高清」
      await tester.tap(find.widgetWithText(ChoiceChip, '720P 高清'));
      await tester.pumpAndSettle();

      // 仅勾选 cid: 2001（本地已缓存的是 1080P）
      state.toggleCid(2002); // 取消 2002
      state.toggleCid(2001); // 选中 2001
      await tester.pumpAndSettle();

      // 点击开始缓存按钮
      await tester.tap(find.text('开始缓存 (1)'));
      await tester.pumpAndSettle();

      // 验证弹出了“替换下载确认”对话框
      expect(find.text('替换下载确认'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('检测到「第一集」已缓存「1080P 高清」'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('720P 高清'),
        ),
        findsOneWidget,
      );

      // 点击“取消”
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 对话框关闭，旧任务依然完好无损
      expect(find.text('替换下载确认'), findsNothing);
      final task1 = service.getTask('BVmulti_parts_2001');
      expect(task1, isNotNull);
      expect(task1!.status, equals(DownloadTaskStatus.completed));
      expect(task1.videoQuality, equals(80));
    });
  });
}

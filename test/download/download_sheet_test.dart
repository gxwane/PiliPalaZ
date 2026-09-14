import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/widgets/download_sheet.dart';

void main() {
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

  group('DownloadSheet 控件渲染与交互', () {
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
          {'cid': 1002, 'page': 2, 'part': '第二集 进展', 'duration': 300},
        ],
      });
    });

    testWidgets('渲染标题、清晰度标签与分P选项', (WidgetTester tester) async {
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
      expect(find.text('720P 高清'), findsOneWidget);
      expect(find.text('480P 清晰'), findsOneWidget);

      // 验证分 P 条目
      expect(find.text('P1 第一集 开始'), findsOneWidget);
      expect(find.text('P2 第二集 进展'), findsOneWidget);

      // 验证底部操作按钮
      expect(find.textContaining('开始缓存'), findsOneWidget);
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

    testWidgets('单视频无 pages 时正确渲染单个选项', (WidgetTester tester) async {
      final singleVideo = VideoDetailData.fromJson({
        'bvid': 'BVsingle',
        'title': '独立单视频',
        'cid': 9999,
        'duration': 120,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DownloadSheet(videoDetail: singleVideo)),
        ),
      );

      expect(find.text('独立单视频'), findsOneWidget);
      // 单视频不显示“全选”按钮
      expect(find.text('全选'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/pages/download/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('下载中卡片在 280dp 极窄屏幕下 0 像素溢出渲染验证 (BAC-15)', (WidgetTester tester) async {
    final task = DownloadTask(
      id: 'BV1test_123',
      bvid: 'BV1test',
      cid: 123,
      title: '这是一个非常非常长的视频标题用来测试极窄屏下的布局抗压能力',
      partTitle: 'P1 这是一个很长很长的分P标题',
      cover: 'http://example.com/cover.jpg',
      ownerName: '测试超长UP主名称',
      duration: 3600,
      videoQuality: 80,
      videoQualityDesc: '1080P 高清',
      videoCodec: 'avc1.640032',
      audioQuality: 30280,
      status: DownloadTaskStatus.downloading,
      totalBytes: 104857600,
      downloadedBytes: 52428800,
      downloadSpeed: 1048576,
    );

    // 构造复现崩溃现场的极窄约束卡片结构（宽度 280dp）
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧：100x62 缩略图
                      const SizedBox(width: 100, height: 62),
                      const SizedBox(width: 12),
                      // 中间：标题与双端弹性文本行
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 双端弹性约束文本行（修复前此处 overflow 44px）
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '${DownloadPageController.formatBytes(task.downloadedBytes)} / '
                                    '${DownloadPageController.formatBytes(task.totalBytes)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    DownloadPageController.formatSpeed(
                                      task.downloadSpeed,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 右侧：单一 40x48 操作按钮
                      const SizedBox(width: 40, height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // 严密断言：无任何 RenderFlex 溢出异常抛出
    expect(tester.takeException(), isNull);
    expect(find.text(task.title), findsOneWidget);
  });
}

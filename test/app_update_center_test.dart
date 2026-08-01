import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/app_update_center.dart';
import 'package:pilipalaz/models/github/latest.dart';

void main() {
  testWidgets('prerelease download requires explicit risk acknowledgement', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool? result;
    const release = LatestDataModel(
      tagName: 'v1.3.0-beta.1',
      htmlUrl: 'https://github.com/gxwane/PiliPalaZ/releases/tag/test',
      prerelease: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const PrereleaseWarningDialog(release: release),
              );
            },
            child: const Text('下载测试版'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('下载测试版'));
    await tester.pumpAndSettle();

    expect(find.text('安装测试版前请确认'), findsOneWidget);
    expect(find.textContaining('可能出现崩溃'), findsOneWidget);
    expect(find.textContaining('卸载后降级会清除应用数据'), findsOneWidget);
    expect(find.textContaining('导入/导出设置'), findsOneWidget);
    expect(find.text('我已了解风险，继续下载'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('下载测试版'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我已了解风险，继续下载'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

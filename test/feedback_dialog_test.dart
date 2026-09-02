import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/feedback_dialog.dart';
import 'package:pilipalaz/services/feedback_coordinator.dart';

void main() {
  Future<void> pumpDialogHost(
    WidgetTester tester,
    FeedbackCoordinator coordinator,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFeedbackDialog(
                context: context,
                coordinator: coordinator,
              ),
              child: const Text('打开反馈'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开反馈'));
    await tester.pumpAndSettle();
  }

  testWidgets('报告问题 opens the bug Issue Form', (tester) async {
    Uri? launchedUri;
    final coordinator = FeedbackCoordinator(
      launchExternal: (uri) async {
        launchedUri = uri;
        return true;
      },
      writeClipboard: (_) async {},
    );
    await pumpDialogHost(tester, coordinator);

    await tester.tap(find.text('报告问题'));
    await tester.pumpAndSettle();

    expect(launchedUri?.queryParameters['template'], 'bug_report.yml');
  });

  testWidgets('功能建议 opens the feature Issue Form', (tester) async {
    Uri? launchedUri;
    final coordinator = FeedbackCoordinator(
      launchExternal: (uri) async {
        launchedUri = uri;
        return true;
      },
      writeClipboard: (_) async {},
    );
    await pumpDialogHost(tester, coordinator);

    await tester.tap(find.text('功能建议'));
    await tester.pumpAndSettle();

    expect(launchedUri?.queryParameters['template'], 'feature_request.yml');
  });

  testWidgets('cancel closes the chooser without opening anything', (
    tester,
  ) async {
    var launchCount = 0;
    final coordinator = FeedbackCoordinator(
      launchExternal: (_) async {
        launchCount += 1;
        return true;
      },
      writeClipboard: (_) async {},
    );
    await pumpDialogHost(tester, coordinator);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(launchCount, 0);
    expect(find.text('问题反馈'), findsNothing);
  });

  testWidgets('launch failure copies the URL and explains the fallback', (
    tester,
  ) async {
    final copied = <String>[];
    final coordinator = FeedbackCoordinator(
      launchExternal: (_) async => false,
      writeClipboard: (text) async => copied.add(text),
    );
    await pumpDialogHost(tester, coordinator);

    await tester.tap(find.text('报告问题'));
    await tester.pumpAndSettle();

    expect(copied.single, contains('template=bug_report.yml'));
    expect(find.text('无法打开浏览器，反馈地址已复制'), findsOneWidget);
  });
}

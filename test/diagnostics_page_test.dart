import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/setting/pages/logs.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';
import 'package:pilipalaz/services/feedback_coordinator.dart';

void main() {
  testWidgets('device information is excluded until the user opts in', (
    tester,
  ) async {
    await _openPreview(tester, _FakeDiagnostics(<DiagnosticRecord>[_record()]));

    expect(find.textContaining('Example Device'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(find.textContaining('Example Device'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('复制并反馈'), findsOneWidget);
    expect(find.text('系统分享'), findsOneWidget);
  });

  testWidgets('copy and feedback copies reviewed text before opening GitHub', (
    tester,
  ) async {
    final events = <String>[];
    String? copiedReport;
    Uri? launchedUri;
    final coordinator = FeedbackCoordinator(
      writeClipboard: (text) async {
        events.add('copy');
        copiedReport = text;
      },
      launchExternal: (uri) async {
        events.add('launch');
        launchedUri = uri;
        return true;
      },
    );
    await _openPreview(
      tester,
      _FakeDiagnostics(<DiagnosticRecord>[_record()]),
      coordinator: coordinator,
    );

    expect(events, isEmpty);

    await tester.tap(find.text('复制并反馈'));
    await tester.pumpAndSettle();

    expect(events, <String>['copy', 'launch']);
    expect(copiedReport, contains('Bad state: test failure'));
    expect(copiedReport, isNot(contains('Example Device')));
    expect(copiedReport, isNot(contains('arm64-v8a')));
    expect(launchedUri?.queryParameters['template'], 'bug_report.yml');
    expect(find.text('诊断报告已复制，请在 GitHub 表单中粘贴后提交'), findsOneWidget);
  });
}

DiagnosticRecord _record() => DiagnosticRecord(
  timestamp: DateTime.utc(2026, 9, 1, 12),
  kind: DiagnosticFailureKind.flutterFramework,
  errorType: 'StateError',
  message: 'Bad state: test failure',
  stackTrace: '#0 test.dart:1',
  environment: const DiagnosticEnvironment(
    appVersion: '1.3.1',
    buildNumber: '114535',
    platform: 'android',
    osVersion: '36',
    manufacturer: 'Example',
    model: 'Device',
    supportedAbis: <String>['arm64-v8a'],
  ),
);

Future<void> _openPreview(
  WidgetTester tester,
  _FakeDiagnostics diagnostics, {
  FeedbackCoordinator coordinator = const FeedbackCoordinator(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LogsPage(
        diagnostics: diagnostics,
        feedbackCoordinator: coordinator,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ExpansionTile));
  await tester.pumpAndSettle();
  final previewButton = find.text('生成反馈内容');
  await tester.ensureVisible(previewButton);
  await tester.pump();
  await tester.tap(previewButton);
  await tester.pumpAndSettle();
}

class _FakeDiagnostics extends LocalDiagnostics {
  _FakeDiagnostics(this.records)
    : super(
        directoryProvider: () async => throw UnsupportedError('unused'),
        environmentLoader: () async => throw UnsupportedError('unused'),
      );

  final List<DiagnosticRecord> records;

  @override
  bool get enabled => true;

  @override
  Future<List<DiagnosticRecord>> readFailures() async => records;

  @override
  Future<int> storageBytes() async => 512;
}

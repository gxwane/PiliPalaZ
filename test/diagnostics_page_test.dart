import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/setting/pages/logs.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';

void main() {
  testWidgets('user previews report and can exclude device information', (
    tester,
  ) async {
    final diagnostics = _FakeDiagnostics(<DiagnosticRecord>[
      DiagnosticRecord(
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
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: LogsPage(diagnostics: diagnostics)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    final previewButton = find.text('生成反馈内容');
    await tester.ensureVisible(previewButton);
    await tester.pump();
    await tester.tap(previewButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Example Device'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(find.textContaining('Example Device'), findsNothing);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('系统分享'), findsOneWidget);
  });
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

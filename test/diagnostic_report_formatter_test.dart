import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_report_formatter.dart';

void main() {
  const environment = DiagnosticEnvironment(
    appVersion: '1.3.1',
    buildNumber: '114535',
    platform: 'android',
    osVersion: '36',
    manufacturer: 'Example',
    model: 'Device',
    supportedAbis: <String>['arm64-v8a'],
  );
  final record = DiagnosticRecord(
    timestamp: DateTime.utc(2026, 9, 1, 12),
    kind: DiagnosticFailureKind.playerNativeFailure,
    errorType: 'StateError',
    message: 'Bad state: decoder failed',
    stackTrace: '#0 player.dart:1',
    environment: environment,
    breadcrumbs: <DiagnosticBreadcrumb>[
      DiagnosticBreadcrumb(
        timestamp: DateTime.utc(2026, 9, 1, 11, 59),
        event: 'native_player_prepare',
        details: const <String, Object?>{'video-codec': 'hevc'},
      ),
    ],
  );

  test('formats an explicitly user-exported diagnostic report', () {
    final output = formatDiagnosticReport(record);

    expect(output, contains('PiliPalaZ 本地诊断'));
    expect(output, contains('用户主动导出'));
    expect(output, contains('1.3.1+114535'));
    expect(output, contains('Example Device'));
    expect(output, contains('video-codec: hevc'));
    expect(output, contains('decoder failed'));
  });

  test('can exclude device compatibility information', () {
    final output = formatDiagnosticReport(record, includeDeviceInfo: false);

    expect(output, contains('1.3.1+114535'));
    expect(output, isNot(contains('Example')));
    expect(output, isNot(contains('Device')));
    expect(output, isNot(contains('arm64-v8a')));
  });
}

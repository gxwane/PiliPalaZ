import 'diagnostic_record.dart';

String formatDiagnosticReport(
  DiagnosticRecord record, {
  bool includeDeviceInfo = true,
}) {
  final environment = record.environment;
  final output = StringBuffer()
    ..writeln('# PiliPalaZ 本地诊断')
    ..writeln()
    ..writeln('> 此内容由用户主动导出，并已在应用内审阅；应用不会自动上传。')
    ..writeln()
    ..writeln('- 时间：${record.timestamp.toLocal().toIso8601String()}')
    ..writeln('- 故障：${record.kind.label}')
    ..writeln('- 应用：${environment.appVersion}+${environment.buildNumber}');
  if (includeDeviceInfo) {
    output
      ..writeln('- 平台：${environment.platform} ${environment.osVersion}')
      ..writeln(
        '- 设备：${<String?>[environment.manufacturer, environment.model].whereType<String>().where((item) => item.isNotEmpty).join(' ')}',
      );
    if (environment.supportedAbis.isNotEmpty) {
      output.writeln('- ABI：${environment.supportedAbis.join(', ')}');
    }
  }
  output
    ..writeln()
    ..writeln('## 错误')
    ..writeln()
    ..writeln('类型：${record.errorType}')
    ..writeln()
    ..writeln('```text')
    ..writeln(_escapeFence(record.message))
    ..writeln('```');
  if (record.stackTrace.isNotEmpty) {
    output
      ..writeln()
      ..writeln('## 堆栈')
      ..writeln()
      ..writeln('```text')
      ..writeln(_escapeFence(record.stackTrace))
      ..writeln('```');
  }
  if (record.breadcrumbs.isNotEmpty) {
    output
      ..writeln()
      ..writeln('## 播放器技术事件')
      ..writeln();
    for (final breadcrumb in record.breadcrumbs) {
      final details = breadcrumb.details.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      output.write(
        '- ${breadcrumb.timestamp.toLocal().toIso8601String()} '
        '${breadcrumb.event}',
      );
      if (details.isNotEmpty) {
        output.write(
          '（${details.map((entry) => '${entry.key}: ${entry.value}').join(', ')}）',
        );
      }
      output.writeln();
    }
  }
  return output.toString().trimRight();
}

String _escapeFence(String value) => value.replaceAll('```', "''' ");

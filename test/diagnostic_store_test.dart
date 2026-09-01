import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_store.dart';

DiagnosticRecord recordAt(DateTime time, String message) {
  return DiagnosticRecord(
    timestamp: time,
    kind: DiagnosticFailureKind.flutterFramework,
    errorType: 'StateError',
    message: message,
    stackTrace: '#0 main (package:pilipalaz/main.dart:1)',
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
}

void main() {
  late Directory directory;
  late File file;
  late DateTime now;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pilipalaz-diagnostics-');
    file = File('${directory.path}${Platform.pathSeparator}diagnostics.jsonl');
    now = DateTime.utc(2026, 9, 1, 12);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('drops expired records and keeps valid records', () async {
    final store = DiagnosticStore(file: file, now: () => now);

    await store.append(recordAt(now.subtract(const Duration(days: 8)), 'old'));
    await store.append(recordAt(now.subtract(const Duration(days: 6)), 'new'));

    final records = await store.read();
    expect(records.map((item) => item.message), <String>['new']);
  });

  test('keeps newest records within byte limit', () async {
    final store = DiagnosticStore(file: file, now: () => now, maxBytes: 900);

    for (var index = 0; index < 10; index++) {
      await store.append(
        recordAt(now.add(Duration(minutes: index)), 'item-$index'),
      );
    }

    final records = await store.read();
    expect(await file.length(), lessThanOrEqualTo(900));
    expect(records.last.message, 'item-9');
    expect(records.any((item) => item.message == 'item-0'), isFalse);
  });

  test('skips malformed json lines', () async {
    final valid = recordAt(now, 'valid');
    await file.writeAsString(
      'not-json\n${jsonEncode(valid.toJson())}\n',
      flush: true,
    );
    final store = DiagnosticStore(file: file, now: () => now);

    final records = await store.read();

    expect(records, hasLength(1));
    expect(records.single.message, 'valid');
  });

  test('serializes concurrent appends without losing records', () async {
    final store = DiagnosticStore(file: file, now: () => now);

    await Future.wait(<Future<void>>[
      for (var index = 0; index < 20; index++)
        store.append(
          recordAt(now.add(Duration(seconds: index)), 'item-$index'),
        ),
    ]);

    final records = await store.read();
    expect(records, hasLength(20));
    expect(records.map((record) => record.message).toSet(), hasLength(20));
  });
}

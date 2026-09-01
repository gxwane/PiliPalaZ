import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project has no remote crash reporting dependencies', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();

    for (final package in <String>[
      'catcher_2',
      'logger',
      'sentry',
      'crashlytics',
    ]) {
      expect(
        RegExp('^  $package:', multiLine: true).hasMatch(pubspec),
        isFalse,
        reason: '$package must not be a direct dependency',
      );
      expect(
        RegExp('^  $package:', multiLine: true).hasMatch(lockfile),
        isFalse,
        reason: '$package must not be present in the lockfile',
      );
    }
  });

  test('diagnostics subsystem has no network client imports', () {
    final directory = Directory('lib/services/diagnostics');
    final source = directory
        .listSync()
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains("import 'package:dio/")));
    expect(source, isNot(contains("import 'package:http/")));
    expect(source, isNot(contains('HttpClient(')));
  });
}

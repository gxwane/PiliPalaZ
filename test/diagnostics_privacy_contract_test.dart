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

  test('feedback coordinator can only copy diagnostics and open a form', () {
    final source = File(
      'lib/services/feedback_coordinator.dart',
    ).readAsStringSync();
    final lowerSource = source.toLowerCase();

    for (final forbidden in <String>[
      "package:dio/",
      "package:http/",
      'httpclient',
      'api.github.com',
      'authorization',
      'bearer ',
    ]) {
      expect(
        lowerSource,
        isNot(contains(forbidden)),
        reason: 'feedback must not contain network upload primitive $forbidden',
      );
    }

    final uriMethodStart = source.indexOf('Uri uriFor');
    final openMethodStart = source.indexOf('Future<FeedbackOpenResult> open');
    expect(uriMethodStart, greaterThanOrEqualTo(0));
    expect(openMethodStart, greaterThan(uriMethodStart));
    final uriConstruction = source.substring(uriMethodStart, openMethodStart);

    expect(uriConstruction, contains('queryParameters'));
    expect(uriConstruction, contains("'template': template"));
    expect(uriConstruction, isNot(contains('diagnosticReport')));
    expect(source, contains('await _copy(diagnosticReport)'));
    expect(
      source.indexOf('await _copy(diagnosticReport)'),
      lessThan(source.indexOf('await _launch(uri)')),
      reason: 'reviewed diagnostics must be copied before the browser opens',
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const templateDirectory = '.github/ISSUE_TEMPLATE';

  test(
    'bug report form collects reproducible details with privacy guidance',
    () {
      final source = File(
        '$templateDirectory/bug_report.yml',
      ).readAsStringSync();

      for (final field in <String>[
        'app_version',
        'platform',
        'system',
        'description',
        'steps',
        'expected',
        'diagnostics',
        'confirmations',
      ]) {
        expect(source, contains('id: $field'));
      }

      expect(source, contains('Cookie'));
      expect(source, contains('令牌'));
      expect(source, contains('本地诊断'));
    },
  );

  test('feature request form documents scope and privacy impact', () {
    final source = File(
      '$templateDirectory/feature_request.yml',
    ).readAsStringSync();

    for (final field in <String>[
      'scenario',
      'proposal',
      'alternatives',
      'privacy',
      'confirmations',
    ]) {
      expect(source, contains('id: $field'));
    }
  });

  test('issue forms disable blank reports and contain no upload secrets', () {
    final config = File('$templateDirectory/config.yml').readAsStringSync();
    final forms = <String>[
      File('$templateDirectory/bug_report.yml').readAsStringSync(),
      File('$templateDirectory/feature_request.yml').readAsStringSync(),
    ].join('\n');

    expect(config, contains('blank_issues_enabled: false'));
    for (final forbidden in <String>[
      'api.github.com',
      'Authorization:',
      'Bearer ',
      'SESSDATA',
      'bili_jct',
    ]) {
      expect(
        forms,
        isNot(contains(forbidden)),
        reason: 'Issue forms must not contain $forbidden',
      );
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false);

  test('legacy access key is isolated to the migration adapter', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (source.contains('LocalCacheKey.accessKey') &&
          !file.path.endsWith(
            'services${Platform.pathSeparator}auth'
            '${Platform.pathSeparator}legacy_credential_source.dart',
          )) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('secure storage plugin is isolated behind the project adapter', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (source.contains(
            "package:flutter_secure_storage/flutter_secure_storage.dart",
          ) &&
          !file.path.endsWith(
            'services${Platform.pathSeparator}auth'
            '${Platform.pathSeparator}flutter_secure_credential_store.dart',
          )) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('persistent cookie files exist only in the legacy reader', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if ((source.contains('PersistCookieJar') ||
              source.contains('FileStorage(')) &&
          !file.path.endsWith(
            'services${Platform.pathSeparator}auth'
            '${Platform.pathSeparator}legacy_credential_source.dart',
          )) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('Dio never stores a process-wide Cookie header', () {
    final assignment = RegExp(
      r'''\.options\.headers\s*\[\s*['"]cookie['"]\s*\]\s*=''',
      caseSensitive: false,
    );
    final offenders = <String>[];
    for (final file in dartFiles) {
      if (assignment.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}

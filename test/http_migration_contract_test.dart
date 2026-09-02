import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy request facade and fake-success fallback stay removed', () {
    expect(File('lib/http/init.dart').existsSync(), isFalse);

    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(RegExp(r'\bRequest(?:\(\)|\.)').hasMatch(source), isFalse);
    expect(source, isNot(contains('makSign(')));
    expect(source, isNot(contains('statusCode: 200')));
  });

  test('HTTP endpoint modules do not expose dynamic futures', () {
    final source = Directory('lib/http')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains('Future<dynamic>')));
  });
}

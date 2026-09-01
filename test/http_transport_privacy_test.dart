import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transport interceptor has no global UI side effects', () {
    final source = File('lib/http/interceptor.dart').readAsStringSync();

    expect(source, isNot(contains('flutter_smart_dialog')));
    expect(source, isNot(contains('SmartDialog')));
    expect(source, contains('requestOptions.uri.path'));
    expect(source, isNot(contains('requestOptions.uri.toString()')));
  });

  test('typed failures never retain raw transport exceptions', () {
    final source = File('lib/http/api_result.dart').readAsStringSync();

    expect(source, isNot(contains('Object? error')));
    expect(source, isNot(contains('StackTrace')));
    expect(source, isNot(contains('RequestOptions')));
  });
}

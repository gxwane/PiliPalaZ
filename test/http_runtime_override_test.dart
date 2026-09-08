import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/http_runtime.dart';

void main() {
  test('uses a zone-scoped HTTP runtime during a test', () async {
    final runtime = HttpRuntime.forTesting(dio: Dio());
    HttpRuntime? observed;

    await HttpRuntime.runWithInstanceForTesting(runtime, () async {
      observed = HttpRuntime.instance;
    });

    expect(observed, same(runtime));
  });
}

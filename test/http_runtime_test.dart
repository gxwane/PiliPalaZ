import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_client.dart';
import 'package:pilipalaz/http/http_runtime.dart';

void main() {
  group('HttpRuntime', () {
    test('owns one Dio session and one typed API client', () {
      final dio = Dio();
      final runtime = HttpRuntime.forTesting(dio: dio);

      expect(runtime.dio, same(dio));
      expect(runtime.client, isA<ApiClient>());
      expect(runtime.client, same(runtime.client));
    });

    test('reads CSRF and BUVID values from its cookie session', () async {
      final jar = CookieJar();
      final runtime = HttpRuntime.forTesting(dio: Dio(), cookieJar: jar);
      final uri = Uri.parse('https://api.bilibili.com');
      await jar.saveFromResponse(uri, <Cookie>[
        Cookie('bili_jct', 'csrf-value'),
        Cookie('Buvid', 'buvid-value'),
      ]);

      expect(await runtime.getCsrf(), 'csrf-value');
      expect(await runtime.getBUVID(), 'buvid-value');
    });

    test('cancels requests through the shared runtime', () {
      final runtime = HttpRuntime.forTesting(dio: Dio());
      final token = CancelToken();

      runtime.cancelRequests(token);

      expect(token.isCancelled, isTrue);
    });
  });
}

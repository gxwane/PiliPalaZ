import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';

void main() {
  group('ApiResult', () {
    test('maps successful values without changing response metadata', () {
      const result = ApiSuccess<int>(21, statusCode: 200);

      final mapped = result.map((value) => value * 2);

      expect(mapped, isA<ApiSuccess<int>>());
      expect((mapped as ApiSuccess<int>).data, 42);
      expect(mapped.statusCode, 200);
    });

    test('preserves typed failures when mapping', () {
      const result = ApiFailure<int>(
        kind: ApiFailureKind.timeout,
        message: '请求超时',
        endpoint: 'video.playUrl',
        retryable: true,
      );

      final mapped = result.map((value) => value.toString());

      expect(mapped, isA<ApiFailure<String>>());
      final failure = mapped as ApiFailure<String>;
      expect(failure.kind, ApiFailureKind.timeout);
      expect(failure.endpoint, 'video.playUrl');
      expect(failure.retryable, isTrue);
    });

    test('fold forces callers to handle success and failure explicitly', () {
      const ApiResult<int> result = ApiFailure<int>(
        kind: ApiFailureKind.apiRejected,
        message: '请求被服务端拒绝',
        apiCode: -101,
      );

      final value = result.fold(
        success: (data) => 'data:$data',
        failure: (failure) => 'code:${failure.apiCode}',
      );

      expect(value, 'code:-101');
    });
  });
}

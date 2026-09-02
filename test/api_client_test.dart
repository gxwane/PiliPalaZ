import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_client.dart';
import 'package:pilipalaz/http/api_result.dart';

void main() {
  group('ApiClient', () {
    test('decodes a successful JSON object into a concrete type', () async {
      final client = _clientWith(
        (_) => ResponseBody.fromString(
          jsonEncode(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{'title': 'PiliPalaZ'},
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      final result = await client.getJson<String>(
        '/video',
        endpoint: 'video.detail',
        decode: (json) =>
            (json['data'] as Map<String, dynamic>)['title'] as String,
      );

      expect(result, isA<ApiSuccess<String>>());
      expect((result as ApiSuccess<String>).data, 'PiliPalaZ');
      expect(result.statusCode, 200);
    });

    test('does not disguise an HTTP error as a successful response', () async {
      final client = _clientWith(
        (_) => ResponseBody.fromString('unavailable', 503),
      );

      final result = await client.getJson<Object?>(
        '/video',
        endpoint: 'video.detail',
        decode: (json) => json,
      );

      expect(result, isA<ApiFailure<Object?>>());
      final failure = result as ApiFailure<Object?>;
      expect(failure.kind, ApiFailureKind.httpStatus);
      expect(failure.statusCode, 503);
      expect(failure.retryable, isTrue);
      expect(failure.endpoint, 'video.detail');
    });

    test('classifies timeout without retaining the raw exception', () async {
      final client = _clientWith((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          error: 'secret low-level transport details',
        );
      });

      final result = await client.getText(
        '/subtitle',
        endpoint: 'video.subtitle',
      );

      expect(result, isA<ApiFailure<String>>());
      final failure = result as ApiFailure<String>;
      expect(failure.kind, ApiFailureKind.timeout);
      expect(failure.retryable, isTrue);
      expect(failure.toString(), isNot(contains('secret')));
    });

    test(
      'classifies an API rejection raised by the endpoint decoder',
      () async {
        final client = _clientWith(
          (_) => ResponseBody.fromString(
            jsonEncode(<String, Object?>{'code': -404, 'message': '不存在'}),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          ),
        );

        final result = await client.getJson<Object?>(
          '/video',
          endpoint: 'video.detail',
          decode: (json) =>
              throw const ApiRejectedException(code: -404, message: '视频不存在'),
        );

        expect(result, isA<ApiFailure<Object?>>());
        final failure = result as ApiFailure<Object?>;
        expect(failure.kind, ApiFailureKind.apiRejected);
        expect(failure.apiCode, -404);
        expect(failure.message, '视频不存在');
      },
    );

    test('returns malformedResponse for a non-object JSON body', () async {
      final client = _clientWith(
        (_) => ResponseBody.fromString(
          jsonEncode(<Object?>['unexpected']),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      final result = await client.getJson<Object?>(
        '/video',
        endpoint: 'video.detail',
        decode: (json) => json,
      );

      expect(result, isA<ApiFailure<Object?>>());
      expect(
        (result as ApiFailure<Object?>).kind,
        ApiFailureKind.malformedResponse,
      );
    });

    test('decodes a JSON object returned as encoded text', () async {
      final client = _clientWith(
        (_) => ResponseBody.fromString(
          jsonEncode(
            jsonEncode(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{'value': 7},
            }),
          ),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      final result = await client.getJson<int>(
        '/text-json',
        decode: (json) =>
            (json['data'] as Map<String, dynamic>)['value'] as int,
      );

      expect(result, isA<ApiSuccess<int>>());
      expect((result as ApiSuccess<int>).data, 7);
    });

    test('returns exact binary response bytes', () async {
      final client = _clientWith(
        (_) => ResponseBody.fromBytes(<int>[0, 255, 1], 200),
      );

      final result = await client.getBytes(
        '/danmaku.seg.so',
        endpoint: 'danmaku.segment',
      );

      expect(result, isA<ApiSuccess<Uint8List>>());
      expect((result as ApiSuccess<Uint8List>).data, <int>[0, 255, 1]);
    });
  });
}

ApiClient _clientWith(ResponseBody Function(RequestOptions options) responder) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.invalid',
      validateStatus: (_) => true,
    ),
  )..httpClientAdapter = _StubAdapter(responder);
  return ApiClient(dio);
}

final class _StubAdapter implements HttpClientAdapter {
  const _StubAdapter(this.responder);

  final ResponseBody Function(RequestOptions options) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => responder(options);

  @override
  void close({bool force = false}) {}
}

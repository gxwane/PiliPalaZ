import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_client.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/danmaku.dart';
import 'package:pilipalaz/models/danmaku/dm.pb.dart';

void main() {
  test('decodes protobuf bytes without routing through JSON', () async {
    final body = DmSegMobileReply(
      elems: <DanmakuElem>[DanmakuElem(content: 'hello')],
    ).writeToBuffer();
    final api = DanmakuApi(
      client: _clientWith((_) => ResponseBody.fromBytes(body, 200)),
    );

    final result = await api.queryDanmaku(cid: 1, segmentIndex: 1);

    expect(result, isA<ApiSuccess<DmSegMobileReply>>());
    expect(
      (result as ApiSuccess<DmSegMobileReply>).data.elems.single.content,
      'hello',
    );
  });

  test('returns a decoding failure instead of casting JSON to bytes', () async {
    final api = DanmakuApi(
      client: _clientWith(
        (_) => ResponseBody.fromBytes(<int>[123, 34, 109, 115, 103, 34], 200),
      ),
    );

    final result = await api.queryDanmaku(cid: 1, segmentIndex: 1);

    expect(result, isA<ApiFailure<DmSegMobileReply>>());
    expect(
      (result as ApiFailure<DmSegMobileReply>).kind,
      ApiFailureKind.decoding,
    );
  });

  test('retries only retryable transport failures', () async {
    var calls = 0;
    var delays = 0;
    final body = DmSegMobileReply().writeToBuffer();
    final api = DanmakuApi(
      client: _clientWith((options) {
        calls += 1;
        if (calls == 1) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }
        return ResponseBody.fromBytes(body, 200);
      }),
      delay: (_) async => delays += 1,
    );

    final result = await api.queryDanmaku(cid: 1, segmentIndex: 1);

    expect(result, isA<ApiSuccess<DmSegMobileReply>>());
    expect(calls, 2);
    expect(delays, 1);
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

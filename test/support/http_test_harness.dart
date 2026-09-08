import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:pilipalaz/http/http_runtime.dart';

typedef HttpTestResponder = ResponseBody Function(RequestOptions request);

final class RecordingHttpAdapter implements HttpClientAdapter {
  RecordingHttpAdapter(this._responder);

  final HttpTestResponder _responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _responder(options);
  }

  @override
  void close({bool force = false}) {}
}

final class HttpTestHarness {
  HttpTestHarness._({required this.runtime, required this.adapter});

  factory HttpTestHarness(HttpTestResponder responder) {
    final adapter = RecordingHttpAdapter(responder);
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.bilibili.com',
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = adapter;
    return HttpTestHarness._(
      runtime: HttpRuntime.forTesting(dio: dio),
      adapter: adapter,
    );
  }

  final HttpRuntime runtime;
  final RecordingHttpAdapter adapter;

  List<RequestOptions> get requests => adapter.requests;

  Future<void> seedCsrf([String value = 'test-csrf']) {
    return runtime.cookieJar.saveFromResponse(
      Uri.parse('https://api.bilibili.com'),
      <Cookie>[Cookie('bili_jct', value)],
    );
  }

  Future<T> run<T>(Future<T> Function() body) {
    return HttpRuntime.runWithInstanceForTesting(runtime, body);
  }
}

ResponseBody jsonResponse(Object? body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

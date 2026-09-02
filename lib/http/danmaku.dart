import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/danmaku/dm.pb.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

final class DanmakuSendReceipt {
  const DanmakuSendReceipt(this.data);

  final Object? data;
}

final class DanmakuApi {
  DanmakuApi({
    ApiClient? client,
    Future<void> Function(Duration duration)? delay,
  }) : _client = client ?? HttpRuntime.instance.client,
       _delay = delay ?? Future<void>.delayed;

  static DanmakuApi? _instance;

  static DanmakuApi get instance => _instance ??= DanmakuApi();

  final ApiClient _client;
  final Future<void> Function(Duration duration) _delay;

  Future<ApiResult<DmSegMobileReply>> queryDanmaku({
    required int cid,
    required int segmentIndex,
    int maxAttempts = 3,
  }) async {
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    ApiFailure<DmSegMobileReply>? lastFailure;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      final response = await _client.getBytes(
        Api.webDanmaku,
        endpoint: 'danmaku.segment',
        queryParameters: <String, dynamic>{
          'type': 1,
          'oid': cid,
          'segment_index': segmentIndex,
        },
      );
      if (response case ApiSuccess<Uint8List>(:final data, :final statusCode)) {
        try {
          return ApiSuccess<DmSegMobileReply>(
            DmSegMobileReply.fromBuffer(data),
            statusCode: statusCode,
          );
        } catch (_) {
          return const ApiFailure<DmSegMobileReply>(
            kind: ApiFailureKind.decoding,
            message: '弹幕数据无法解析',
            endpoint: 'danmaku.segment',
          );
        }
      }

      lastFailure = (response as ApiFailure<Uint8List>)
          .cast<DmSegMobileReply>();
      if (!lastFailure.retryable || attempt == attempts - 1) {
        return lastFailure;
      }
      await _delay(const Duration(seconds: 1));
    }
    return lastFailure ??
        const ApiFailure<DmSegMobileReply>(
          kind: ApiFailureKind.unknown,
          message: '弹幕加载失败',
          endpoint: 'danmaku.segment',
        );
  }

  Future<ApiResult<DanmakuSendReceipt>> shootDanmaku({
    int type = 1,
    required int oid,
    required String message,
    int mode = 1,
    required String bvid,
    int? progress,
    int? color,
    int? fontSize,
    int? pool,
    int? colorful,
    int? checkboxType,
  }) async {
    if (message.length >= 100) {
      return const ApiFailure<DanmakuSendReceipt>(
        kind: ApiFailureKind.apiRejected,
        message: '弹幕内容不能超过 99 个字符',
        endpoint: 'danmaku.shoot',
      );
    }
    final params = <String, dynamic>{
      'type': type,
      'oid': oid,
      'msg': message,
      'mode': mode,
      'bvid': bvid,
      'progress': progress,
      'color': color,
      'fontsize': fontSize,
      'pool': pool,
      'rnd': DateTime.now().microsecondsSinceEpoch,
      'colorful': colorful,
      'checkbox_type': checkboxType,
      'csrf': await HttpRuntime.instance.getCsrf(),
    }..removeWhere((_, value) => value == null);

    return _client.postJson<DanmakuSendReceipt>(
      Api.shootDanmaku,
      endpoint: 'danmaku.shoot',
      data: params,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      decode: (json) => BiliApiDecoder.data<DanmakuSendReceipt>(
        json,
        decode: DanmakuSendReceipt.new,
      ),
    );
  }
}

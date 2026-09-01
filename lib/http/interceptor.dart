import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'log_sanitizer.dart';

/// Keeps transport diagnostics local and leaves presentation to the caller.
class ApiInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final safePath = redactSensitiveLog(err.requestOptions.uri.path);
      debugPrint('HTTP request failed: $safePath (${err.type.name})');
    }
    handler.next(err);
  }

  /// Compatibility message used only by endpoints awaiting migration.
  static Future<String> dioError(DioException error) async {
    return switch (error.type) {
      DioExceptionType.badCertificate => '证书有误！',
      DioExceptionType.badResponse => '服务器异常，请稍后重试！',
      DioExceptionType.cancel => '请求已被取消，请重新请求',
      DioExceptionType.connectionError => '连接错误，请检查网络设置',
      DioExceptionType.connectionTimeout => '网络连接超时，请检查网络设置',
      DioExceptionType.receiveTimeout => '响应超时，请稍后重试！',
      DioExceptionType.sendTimeout => '发送请求超时，请检查网络设置',
      DioExceptionType.transformTimeout => '响应处理超时，请稍后重试！',
      DioExceptionType.unknown => '网络异常，请稍后重试',
    };
  }
}

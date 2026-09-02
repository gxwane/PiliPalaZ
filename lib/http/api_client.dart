import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_result.dart';

typedef JsonObject = Map<String, dynamic>;
typedef JsonDecoder<T> = T Function(JsonObject json);

final class ApiRejectedException implements Exception {
  const ApiRejectedException({required this.code, required this.message});

  final int code;
  final String message;
}

final class MalformedApiResponseException implements Exception {
  const MalformedApiResponseException([this.message = '响应数据格式不正确']);

  final String message;
}

final class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<ApiResult<T>> getJson<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required JsonDecoder<T> decode,
    String? endpoint,
  }) {
    return _requestJson(
      'GET',
      url,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      decode: decode,
      endpoint: endpoint,
    );
  }

  Future<ApiResult<T>> postJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required JsonDecoder<T> decode,
    String? endpoint,
  }) {
    return _requestJson(
      'POST',
      url,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      decode: decode,
      endpoint: endpoint,
    );
  }

  Future<ApiResult<String>> getText(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? endpoint,
  }) {
    return _requestValue<String>(
      () => _dio.get<Object?>(
        url,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(
          responseType: ResponseType.plain,
        ),
        cancelToken: cancelToken,
      ),
      convert: (value) {
        if (value is String) {
          return value;
        }
        throw const MalformedApiResponseException('响应不是文本');
      },
      endpoint: _safeEndpoint(url, endpoint),
    );
  }

  Future<ApiResult<Uint8List>> getBytes(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? endpoint,
  }) {
    return _requestValue<Uint8List>(
      () => _dio.get<Object?>(
        url,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(
          responseType: ResponseType.bytes,
        ),
        cancelToken: cancelToken,
      ),
      convert: (value) {
        if (value is Uint8List) {
          return value;
        }
        if (value is List<int>) {
          return Uint8List.fromList(value);
        }
        throw const MalformedApiResponseException('响应不是二进制数据');
      },
      endpoint: _safeEndpoint(url, endpoint),
    );
  }

  Future<ApiResult<void>> download(
    String url,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    String? endpoint,
  }) {
    return _requestValue<void>(
      () => _dio.download(
        url,
        savePath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
      convert: (_) {},
      endpoint: _safeEndpoint(url, endpoint),
    );
  }

  Future<ApiResult<T>> _requestJson<T>(
    String method,
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required JsonDecoder<T> decode,
    String? endpoint,
  }) {
    return _requestValue<T>(
      () => _dio.request<Object?>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(
          method: method,
          responseType: ResponseType.json,
        ),
        cancelToken: cancelToken,
      ),
      convert: (value) {
        if (value is! Map) {
          throw const MalformedApiResponseException('JSON 响应的顶层结构不是对象');
        }
        return decode(
          value.map((key, value) => MapEntry(key.toString(), value)),
        );
      },
      endpoint: _safeEndpoint(url, endpoint),
    );
  }

  Future<ApiResult<T>> _requestValue<T>(
    Future<Response<Object?>> Function() request, {
    required T Function(Object? value) convert,
    required String endpoint,
  }) async {
    try {
      final response = await request();
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode < 200 || statusCode >= 300) {
        return ApiFailure<T>(
          kind: ApiFailureKind.httpStatus,
          message: '服务器返回了异常状态',
          endpoint: endpoint,
          statusCode: statusCode,
          retryable: statusCode == null || statusCode >= 500,
        );
      }
      try {
        return ApiSuccess<T>(convert(response.data), statusCode: statusCode);
      } on ApiRejectedException catch (error) {
        return ApiFailure<T>(
          kind: ApiFailureKind.apiRejected,
          message: error.message,
          endpoint: endpoint,
          statusCode: statusCode,
          apiCode: error.code,
        );
      } on MalformedApiResponseException catch (error) {
        return ApiFailure<T>(
          kind: ApiFailureKind.malformedResponse,
          message: error.message,
          endpoint: endpoint,
          statusCode: statusCode,
        );
      } on FormatException {
        return ApiFailure<T>(
          kind: ApiFailureKind.decoding,
          message: '响应数据无法解析',
          endpoint: endpoint,
          statusCode: statusCode,
        );
      } on TypeError {
        return ApiFailure<T>(
          kind: ApiFailureKind.decoding,
          message: '响应字段类型不正确',
          endpoint: endpoint,
          statusCode: statusCode,
        );
      } catch (_) {
        return ApiFailure<T>(
          kind: ApiFailureKind.decoding,
          message: '响应数据无法解析',
          endpoint: endpoint,
          statusCode: statusCode,
        );
      }
    } on DioException catch (error) {
      return _fromDioException<T>(error, endpoint);
    } catch (_) {
      return ApiFailure<T>(
        kind: ApiFailureKind.unknown,
        message: '请求发生未知错误',
        endpoint: endpoint,
      );
    }
  }

  ApiFailure<T> _fromDioException<T>(DioException error, String endpoint) {
    final statusCode = error.response?.statusCode;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => ApiFailure<T>(
        kind: ApiFailureKind.timeout,
        message: '请求超时，请稍后重试',
        endpoint: endpoint,
        statusCode: statusCode,
        retryable: true,
      ),
      DioExceptionType.cancel => ApiFailure<T>(
        kind: ApiFailureKind.cancelled,
        message: '请求已取消',
        endpoint: endpoint,
        statusCode: statusCode,
      ),
      DioExceptionType.badResponse => ApiFailure<T>(
        kind: ApiFailureKind.httpStatus,
        message: '服务器返回了异常状态',
        endpoint: endpoint,
        statusCode: statusCode,
        retryable: statusCode == null || statusCode >= 500,
      ),
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => ApiFailure<T>(
        kind: ApiFailureKind.network,
        message: '网络连接失败，请检查网络设置',
        endpoint: endpoint,
        statusCode: statusCode,
        retryable: true,
      ),
      DioExceptionType.unknown when error.error is SocketException =>
        ApiFailure<T>(
          kind: ApiFailureKind.network,
          message: '网络连接失败，请检查网络设置',
          endpoint: endpoint,
          statusCode: statusCode,
          retryable: true,
        ),
      DioExceptionType.unknown => ApiFailure<T>(
        kind: ApiFailureKind.unknown,
        message: '请求发生未知错误',
        endpoint: endpoint,
        statusCode: statusCode,
      ),
    };
  }

  String _safeEndpoint(String url, String? endpoint) {
    if (endpoint != null && endpoint.isNotEmpty) {
      return endpoint;
    }
    try {
      final uri = Uri.parse(url);
      return uri.path.isEmpty ? '/' : uri.path;
    } catch (_) {
      return 'unknown';
    }
  }
}

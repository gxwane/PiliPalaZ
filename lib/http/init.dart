// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'api_result.dart';
import 'http_runtime.dart';
import 'interceptor.dart';

/// Transitional compatibility facade.
///
/// New endpoint modules use [HttpRuntime.client] and return [ApiResult]. The
/// legacy request methods stay here only while the remaining endpoint modules
/// are migrated.
class Request {
  static final Request _instance = Request._internal();

  factory Request() => _instance;

  Request._internal() {
    HttpRuntime.ensureInitialized();
  }

  static Dio get dio => HttpRuntime.instance.dio;

  static CookieManager get cookieManager => HttpRuntime.instance.cookieManager;

  static Future<ApiResult<void>> setCookie() {
    return HttpRuntime.instance.initializeSession();
  }

  static Future<String> getCsrf() => HttpRuntime.instance.getCsrf();

  static Future<String> getBUVID() => HttpRuntime.instance.getBUVID();

  static String getRandomSessionId() {
    return HttpRuntime.instance.getRandomSessionId();
  }

  static void setOptionsHeaders(dynamic userInfo, bool status) {
    HttpRuntime.instance.setOptionsHeaders(userInfo, status);
  }

  static Future<ApiResult<void>> buvidActivate() {
    return HttpRuntime.instance.activateBuvid();
  }

  Future<Response<dynamic>> get(
    String url, {
    dynamic data,
    Options? options,
    CancelToken? cancelToken,
    Map<String, dynamic>? extra,
  }) async {
    options ??= Options();
    var responseType = ResponseType.json;
    if (extra != null) {
      responseType = extra['resType'] as ResponseType? ?? ResponseType.json;
      final uaType = extra['ua'];
      if (uaType != null) {
        options.headers = <String, Object?>{
          'user-agent': headerUa(type: uaType.toString()),
        };
      }
    }
    options.responseType = responseType;

    try {
      return await dio.get<dynamic>(
        url,
        queryParameters: data,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      return Response<dynamic>(
        data: <String, Object?>{
          'message': await ApiInterceptor.dioError(error),
        },
        statusCode: 200,
        requestOptions: error.requestOptions,
      );
    }
  }

  Future<Response<dynamic>> post(
    String url, {
    dynamic data,
    dynamic queryParameters,
    Options? options,
    CancelToken? cancelToken,
    dynamic extra,
  }) async {
    try {
      return await dio.post<dynamic>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      return Response<dynamic>(
        data: <String, Object?>{
          'message': await ApiInterceptor.dioError(error),
        },
        statusCode: 200,
        requestOptions: error.requestOptions,
      );
    }
  }

  Future<dynamic> downloadFile(String urlPath, String savePath) async {
    try {
      final response = await dio.download(urlPath, savePath);
      return response.data;
    } on DioException catch (error) {
      return Future<dynamic>.error(await ApiInterceptor.dioError(error));
    }
  }

  void cancelRequests(CancelToken token) {
    HttpRuntime.instance.cancelRequests(token);
  }

  String headerUa({String type = 'mob'}) {
    return HttpRuntime.instance.headerUa(type: type);
  }
}

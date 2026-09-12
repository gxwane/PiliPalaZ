import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../services/auth/auth_session_manager.dart';
import '../services/auth/secure_cookie_jar.dart';
import '../services/auth/stored_session.dart';
import '../utils/id_utils.dart';
import '../utils/login.dart';
import '../utils/storage.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_result.dart';
import 'constants.dart';
import 'interceptor.dart';
import 'interceptor_anonymity.dart';
import 'log_sanitizer.dart';

final class HttpRuntime {
  HttpRuntime._({
    required this.dio,
    required CookieJar cookieJar,
    AuthSessionManager? authSessionManager,
  }) : _cookieJar = cookieJar,
       _authSessionManager = authSessionManager,
       client = ApiClient(dio),
       _cookieManager = CookieManager(cookieJar) {
    authSessionManager?.registerRuntimeCredentialClear(clearSession);
  }

  factory HttpRuntime.forTesting({
    required Dio dio,
    CookieJar? cookieJar,
    AuthSessionManager? authSessionManager,
  }) {
    return HttpRuntime._(
      dio: dio,
      cookieJar: cookieJar ?? CookieJar(),
      authSessionManager: authSessionManager,
    );
  }

  factory HttpRuntime.fromStorage({
    AuthSessionManager? authSessionManager,
    CookieJar? cookieJar,
  }) {
    final setting = GStorage.setting;
    final options = BaseOptions(
      baseUrl: HttpString.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: 12000),
      receiveTimeout: const Duration(milliseconds: 12000),
      headers: <String, Object?>{},
    );
    final dio = Dio(options);

    final enableSystemProxy =
        setting.get(SettingBoxKey.enableSystemProxy, defaultValue: false)
            as bool;
    if (enableSystemProxy) {
      final systemProxyHost = setting.get(
        SettingBoxKey.systemProxyHost,
        defaultValue: '',
      );
      final systemProxyPort = setting.get(
        SettingBoxKey.systemProxyPort,
        defaultValue: '',
      );
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (_) {
            return 'PROXY $systemProxyHost:$systemProxyPort';
          };
          client.badCertificateCallback = (_, _, _) => true;
          return client;
        },
      );
    }

    dio.interceptors.add(ApiInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          logPrint: (message) => debugPrint(redactSensitiveLog(message)),
        ),
      );
    }
    dio.transformer = BackgroundTransformer();
    dio.options.validateStatus = (status) {
      return status != null &&
          (status >= 200 && status < 300 ||
              HttpString.validateStatusCodes.contains(status));
    };
    return HttpRuntime._(
      dio: dio,
      cookieJar: cookieJar ?? CookieJar(),
      authSessionManager: authSessionManager,
    );
  }

  static HttpRuntime? _instance;

  static final Object _instanceZoneKey = Object();

  static HttpRuntime get instance {
    final scopedInstance = Zone.current[_instanceZoneKey];
    if (scopedInstance is HttpRuntime) {
      return scopedInstance;
    }
    return _instance ??= HttpRuntime.fromStorage();
  }

  @visibleForTesting
  static Future<T> runWithInstanceForTesting<T>(
    HttpRuntime runtime,
    Future<T> Function() body,
  ) {
    return runZoned<Future<T>>(
      body,
      zoneValues: <Object?, Object?>{_instanceZoneKey: runtime},
    );
  }

  static HttpRuntime ensureInitialized({
    AuthSessionManager? authSessionManager,
    CookieJar? cookieJar,
  }) {
    return _instance ??= HttpRuntime.fromStorage(
      authSessionManager: authSessionManager,
      cookieJar: cookieJar,
    );
  }

  final Dio dio;
  final ApiClient client;
  final AuthSessionManager? _authSessionManager;
  CookieJar _cookieJar;
  CookieManager _cookieManager;
  bool _sessionInitialized = false;

  CookieJar get cookieJar => _cookieJar;
  CookieManager get cookieManager => _cookieManager;

  Future<ApiResult<void>> initializeSession() async {
    if (_sessionInitialized) {
      return const ApiSuccess<void>(null);
    }
    try {
      dio.interceptors.add(_cookieManager);
      dio.interceptors.add(AnonymityInterceptor());
      _sessionInitialized = true;

      final authSession = _authSessionManager?.session;
      if (_cookieJar case final SecureCookieJar secureCookieJar) {
        await secureCookieJar.restore(authSession?.cookies ?? const []);
      }
      final isLoggedIn = _authSessionManager?.isAuthenticated == true;
      if (isLoggedIn) {
        final tCookies = await _cookieJar.loadForRequest(
          Uri.parse(HttpString.tUrl),
        );
        if (tCookies.isEmpty) {
          await client.getText(HttpString.tUrl, endpoint: 'session.bootstrap');
        }
      }
      setSessionHeaders(authSession);

      await activateBuvid();
      return const ApiSuccess<void>(null);
    } catch (_) {
      return const ApiFailure<void>(
        kind: ApiFailureKind.unknown,
        message: '网络会话初始化失败',
        endpoint: 'session.initialize',
      );
    }
  }

  Future<void> replaceSession(StoredSession session) async {
    if (_cookieJar case final SecureCookieJar secureCookieJar) {
      await secureCookieJar.restore(session.cookies);
    } else {
      await _cookieJar.deleteAll();
      for (final stored in session.cookies) {
        final cookie = stored.toCookie();
        if (cookie != null) {
          await _cookieJar.saveFromResponse(Uri.parse(stored.origin), [cookie]);
        }
      }
    }
    setSessionHeaders(session);
  }

  Future<void> clearSession() async {
    await _cookieJar.deleteAll();
    dio.options.headers.remove('cookie');
    dio.options.headers.remove('x-bili-mid');
    dio.options.headers.remove('x-bili-aurora-eid');
  }

  Future<String> getCsrf() async {
    final cookies = await _cookieJar.loadForRequest(
      Uri.parse(HttpString.apiBaseUrl),
    );
    for (final cookie in cookies) {
      if (cookie.name == 'bili_jct') {
        return cookie.value;
      }
    }
    return '';
  }

  Future<String> getBUVID() async {
    final cookies = await _cookieJar.loadForRequest(
      Uri.parse(HttpString.apiBaseUrl),
    );
    for (final cookie in cookies) {
      if (cookie.name == 'Buvid') {
        return cookie.value;
      }
    }
    return LoginUtils.buvid();
  }

  String getRandomSessionId() {
    return List.generate(
      8,
      (_) => Random().nextInt(16).toRadixString(16),
    ).join();
  }

  void setSessionHeaders(StoredSession? session) {
    dio.options.headers.remove('cookie');
    dio.options.headers.remove('x-bili-mid');
    dio.options.headers.remove('x-bili-aurora-eid');
    final mid = session?.mid;
    if (session?.isAuthenticated == true && mid != null) {
      dio.options.headers['x-bili-mid'] = mid.toString();
      dio.options.headers['x-bili-aurora-eid'] = IdUtils.genAuroraEid(mid);
    }
    dio.options.headers['env'] = 'prod';
    dio.options.headers['app-key'] = 'android64';
    dio.options.headers['x-bili-aurora-zone'] = 'sh001';
    dio.options.headers['referer'] = 'https://www.bilibili.com/';
  }

  Future<ApiResult<void>> activateBuvid() async {
    final html = await client.getText(
      Api.dynamicSpmPrefix,
      endpoint: 'session.spmPrefix',
    );
    if (html case final ApiFailure<String> failure) {
      return failure.cast<void>();
    }
    final source = (html as ApiSuccess<String>).data;
    final match = RegExp(
      r'<meta name="spm_prefix" content="([^"]+?)">',
    ).firstMatch(source);
    final spmPrefix = match?.group(1);
    if (spmPrefix == null) {
      return const ApiFailure<void>(
        kind: ApiFailureKind.malformedResponse,
        message: '无法读取设备会话参数',
        endpoint: 'session.spmPrefix',
      );
    }

    final random = Random();
    final randomPngEnd = base64.encode(
      List<int>.generate(32, (_) => random.nextInt(256)) +
          List<int>.filled(4, 0) +
          <int>[73, 69, 78, 68] +
          List<int>.generate(4, (_) => random.nextInt(256)),
    );
    final jsonData = json.encode(<String, Object?>{
      '3064': 1,
      '39c8': '$spmPrefix.fp.risk',
      '3c43': <String, Object?>{
        'adca': 'Linux',
        'bfe9': randomPngEnd.substring(randomPngEnd.length - 50),
      },
    });
    final result = await client.postJson<JsonObject>(
      Api.activateBuvidApi,
      data: <String, Object?>{'payload': jsonData},
      options: Options(contentType: Headers.jsonContentType),
      endpoint: 'session.activateBuvid',
      decode: (json) => json,
    );
    return result.map<void>((_) {});
  }

  void cancelRequests(CancelToken token) {
    token.cancel('cancelled');
  }

  String headerUa({String type = 'mob'}) {
    if (type == 'mob') {
      if (Platform.isIOS) {
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_5 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1 '
            'Mobile/15E148 Safari/604.1';
      }
      return 'Mozilla/5.0 (Linux; Android 10; SM-G975F) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 '
          'Mobile Safari/537.36';
    }
    return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';
  }
}

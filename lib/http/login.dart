import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';

import '../common/constants.dart';
import '../utils/login.dart';
import '../utils/utils.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_result.dart';
import 'http_runtime.dart';

final class LoginResponse {
  const LoginResponse({
    required this.code,
    required this.message,
    required this.payload,
  });

  final int code;
  final String message;
  final JsonObject payload;

  bool get accepted => code == 0;
}

abstract final class LoginHttp {
  static final String deviceId = LoginUtils.genDeviceId();
  static final String buvid = LoginUtils.buvid();
  static const String host = 'passport.bilibili.com';
  static final Map<String, String> headers = <String, String>{
    'Host': host,
    'buvid': buvid,
    'env': 'prod',
    'app-key': 'android_hd',
    'user-agent': Constants.userAgent,
    'x-bili-trace-id': Constants.traceId,
    'x-bili-aurora-eid': '',
    'x-bili-aurora-zone': '',
    'bili-http-engine': 'cronet',
    'content-type': 'application/x-www-form-urlencoded; charset=utf-8',
  };

  static ApiClient get _client => HttpRuntime.instance.client;

  static Future<ApiResult<LoginResponse>> getHDcode() {
    final parameters = <String, String>{
      'appkey': Constants.appKey,
      'local_id': '0',
      'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'platform': 'android',
      'mobi_app': 'android_hd',
    };
    parameters['sign'] = Utils.appSign(
      parameters,
      Constants.appKey,
      Constants.appSec,
    );
    return _post(
      Api.getTVCode,
      endpoint: 'login.qrCode',
      queryParameters: parameters,
    );
  }

  static Future<ApiResult<LoginResponse>> codePoll(String authCode) {
    final parameters = <String, String>{
      'appkey': Constants.appKey,
      'auth_code': authCode,
      'local_id': '0',
      'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    };
    parameters['sign'] = Utils.appSign(
      parameters,
      Constants.appKey,
      Constants.appSec,
    );
    return _post(
      Api.qrcodePoll,
      endpoint: 'login.qrPoll',
      queryParameters: parameters,
    );
  }

  static Future<ApiResult<LoginResponse>> getWebKey() {
    return _client.getJson<LoginResponse>(
      Api.getWebKey,
      endpoint: 'login.webKey',
      decode: _decodeResponse,
    );
  }

  static Future<ApiResult<LoginResponse>> sendSmsCode({
    required String cid,
    required String tel,
    String? gee_challenge,
    String? gee_seccode,
    String? gee_validate,
    String? recaptcha_token,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = <String, dynamic>{
      'appkey': Constants.appKey,
      'build': '2001100',
      'buvid': buvid,
      'c_locale': 'zh_CN',
      'channel': 'yingyongbao',
      'cid': cid,
      'disable_rcmd': '0',
      if (gee_challenge != null) 'gee_challenge': gee_challenge,
      if (gee_seccode != null) 'gee_seccode': gee_seccode,
      if (gee_validate != null) 'gee_validate': gee_validate,
      'local_id': buvid,
      'login_session_id': md5
          .convert(utf8.encode(buvid + timestamp.toString()))
          .toString(),
      'mobi_app': 'android_hd',
      'platform': 'android',
      if (recaptcha_token != null) 'recaptcha_token': recaptcha_token,
      's_locale': 'zh_CN',
      'statistics': Constants.statistics,
      'tel': tel,
      'ts': (timestamp ~/ 1000).toString(),
    };
    data['sign'] = Utils.appSign(data, Constants.appKey, Constants.appSec);
    return _post(
      Api.appSmsCode,
      endpoint: 'login.sendSms',
      data: data,
      options: _formOptions(headers),
    );
  }

  static Future<ApiResult<LoginResponse>> loginByPwd({
    required String username,
    required String password,
    required String key,
    required String salt,
    String? gee_challenge,
    String? gee_seccode,
    String? gee_validate,
    String? recaptcha_token,
  }) async {
    try {
      final dynamic publicKey = RSAKeyParser().parse(key);
      final encrypter = Encrypter(RSA(publicKey: publicKey));
      final data = <String, dynamic>{
        'appkey': Constants.appKey,
        'bili_local_id': deviceId,
        'build': '2001100',
        'buvid': buvid,
        'c_locale': 'zh_CN',
        'channel': 'yingyongbao',
        'device': 'phone',
        'device_id': deviceId,
        'device_name': 'vivo',
        'device_platform': 'Android14vivo',
        'disable_rcmd': '0',
        'dt': Uri.encodeComponent(
          encrypter.encrypt(LoginUtils.generateRandomString(16)).base64,
        ),
        'from_pv': 'main.homepage.avatar-nologin.all.click',
        'from_url': Uri.encodeComponent('bilibili://pegasus/promo'),
        if (gee_challenge != null) 'gee_challenge': gee_challenge,
        if (gee_seccode != null) 'gee_seccode': gee_seccode,
        if (gee_validate != null) 'gee_validate': gee_validate,
        'local_id': buvid,
        'mobi_app': 'android_hd',
        'password': encrypter.encrypt(salt + password).base64,
        'permission': 'ALL',
        'platform': 'android',
        if (recaptcha_token != null) 'recaptcha_token': recaptcha_token,
        's_locale': 'zh_CN',
        'statistics': Constants.statistics,
        'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
        'username': username,
      };
      data['sign'] = Utils.appSign(data, Constants.appKey, Constants.appSec);
      return _post(
        Api.loginByPwdApi,
        endpoint: 'login.password',
        data: data,
        options: _formOptions(headers),
      );
    } catch (_) {
      return const ApiFailure<LoginResponse>(
        kind: ApiFailureKind.decoding,
        message: '登录密钥格式不正确',
        endpoint: 'login.password',
      );
    }
  }

  static Future<ApiResult<LoginResponse>> loginBySms({
    required String captchaKey,
    required String tel,
    required String code,
    required String cid,
    required String key,
  }) async {
    try {
      final dynamic publicKey = RSAKeyParser().parse(key);
      final encrypter = Encrypter(RSA(publicKey: publicKey));
      final data = <String, dynamic>{
        'appkey': Constants.appKey,
        'bili_local_id': deviceId,
        'build': '2001100',
        'buvid': buvid,
        'c_locale': 'zh_CN',
        'captcha_key': captchaKey,
        'channel': 'yingyongbao',
        'cid': cid,
        'code': code,
        'device': 'phone',
        'device_id': deviceId,
        'device_name': 'vivo',
        'device_platform': 'Android14vivo',
        'disable_rcmd': '0',
        'dt': Uri.encodeComponent(
          encrypter.encrypt(LoginUtils.generateRandomString(16)).base64,
        ),
        'from_pv': 'main.my-information.my-login.0.click',
        'from_url': Uri.encodeComponent('bilibili://user_center/mine'),
        'local_id': buvid,
        'mobi_app': 'android_hd',
        'platform': 'android',
        's_locale': 'zh_CN',
        'statistics': Constants.statistics,
        'tel': tel,
        'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      };
      data['sign'] = Utils.appSign(data, Constants.appKey, Constants.appSec);
      return _post(
        Api.logInByAppSms,
        endpoint: 'login.sms',
        data: data,
        options: _formOptions(headers),
      );
    } catch (_) {
      return const ApiFailure<LoginResponse>(
        kind: ApiFailureKind.decoding,
        message: '登录密钥格式不正确',
        endpoint: 'login.sms',
      );
    }
  }

  static Future<ApiResult<LoginResponse>> safeCenterGetInfo({
    required String tmpCode,
  }) {
    return _client.getJson<LoginResponse>(
      Api.safeCenterGetInfo,
      queryParameters: <String, dynamic>{'tmp_code': tmpCode},
      endpoint: 'login.safeCenterInfo',
      decode: _decodeResponse,
    );
  }

  static Future<ApiResult<LoginResponse>> preCapture() {
    return _post(Api.preCapture, endpoint: 'login.preCapture');
  }

  static Future<ApiResult<LoginResponse>> safeCenterSmsCode({
    String? smsType,
    required String tmpCode,
    String? geeChallenge,
    String? geeSeccode,
    String? geeValidate,
    String? recaptchaToken,
    required String refererUrl,
  }) {
    final data = <String, dynamic>{
      'disable_rcmd': '0',
      'sms_type': smsType ?? 'loginTelCheck',
      'tmp_code': tmpCode,
      if (geeChallenge != null) 'gee_challenge': geeChallenge,
      if (geeSeccode != null) 'gee_seccode': geeSeccode,
      if (geeValidate != null) 'gee_validate': geeValidate,
      if (recaptchaToken != null) 'recaptcha_token': recaptchaToken,
    };
    data['sign'] = Utils.appSign(data, Constants.appKey, Constants.appSec);
    return _post(
      Api.safeCenterSmsCode,
      endpoint: 'login.safeCenterSendSms',
      data: data,
      options: _formOptions(<String, String>{'Referer': refererUrl}),
    );
  }

  static Future<ApiResult<LoginResponse>> safeCenterSmsVerify({
    String? type,
    required String code,
    required String tmpCode,
    required String requestId,
    required String source,
    required String captchaKey,
    required String refererUrl,
  }) {
    final data = <String, dynamic>{
      'type': type ?? 'loginTelCheck',
      'code': code,
      'tmp_code': tmpCode,
      'request_id': requestId,
      'source': source,
      'captcha_key': captchaKey,
    };
    data['sign'] = Utils.appSign(data, Constants.appKey, Constants.appSec);
    return _post(
      Api.safeCenterSmsVerify,
      endpoint: 'login.safeCenterVerifySms',
      data: data,
      options: _formOptions(<String, String>{'Referer': refererUrl}),
    );
  }

  static Future<ApiResult<LoginResponse>> oauth2AccessToken({
    required String code,
  }) {
    final data = <String, dynamic>{
      'appkey': Constants.appKey,
      'build': '2001100',
      'buvid': buvid,
      'code': code,
      'disable_rcmd': '0',
      'grant_type': 'authorization_code',
      'local_id': buvid,
      'mobi_app': 'android_hd',
      'platform': 'android',
      'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    };
    data['sign'] = Utils.appSign(data, Constants.appKey, Constants.appSec);
    return _post(
      Api.oauth2AccessToken,
      endpoint: 'login.oauthToken',
      data: data,
      options: _formOptions(headers),
    );
  }

  static Future<ApiResult<LoginResponse>> _post(
    String url, {
    required String endpoint,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _client.postJson<LoginResponse>(
      url,
      data: data,
      queryParameters: queryParameters,
      options: options,
      endpoint: endpoint,
      decode: _decodeResponse,
    );
  }

  static LoginResponse _decodeResponse(JsonObject json) {
    final rawCode = json['code'];
    if (rawCode is! num) {
      throw const MalformedApiResponseException('响应缺少有效的 code 字段');
    }
    final rawPayload = json['data'];
    final payload = rawPayload is Map
        ? rawPayload.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final rawMessage = json['message'] ?? json['msg'];
    return LoginResponse(
      code: rawCode.toInt(),
      message: rawMessage is String ? rawMessage : '',
      payload: payload,
    );
  }

  static Options _formOptions(Map<String, String> requestHeaders) {
    return Options(
      contentType: Headers.formUrlEncodedContentType,
      headers: requestHeaders,
    );
  }
}

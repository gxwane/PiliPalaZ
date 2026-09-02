import 'api_client.dart';

abstract final class BiliApiDecoder {
  static T data<T>(
    JsonObject json, {
    required T Function(Object? value) decode,
    String key = 'data',
  }) {
    _requireSuccess(json);
    if (!json.containsKey(key)) {
      throw MalformedApiResponseException('响应缺少 $key 字段');
    }
    return decode(json[key]);
  }

  static T result<T>(
    JsonObject json, {
    required T Function(Object? value) decode,
  }) {
    return data<T>(json, key: 'result', decode: decode);
  }

  static void success(JsonObject json) {
    _requireSuccess(json);
  }

  static JsonObject object(Object? value, {required String field}) {
    if (value is! Map) {
      throw MalformedApiResponseException('$field 字段不是对象');
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic> list(Object? value, {required String field}) {
    if (value is! List) {
      throw MalformedApiResponseException('$field 字段不是列表');
    }
    return List<dynamic>.from(value);
  }

  static int integer(Object? value, {required String field}) {
    if (value is num) {
      return value.toInt();
    }
    throw MalformedApiResponseException('$field 字段不是整数');
  }

  static String message(JsonObject json, {String fallback = '请求失败'}) {
    final value = json['message'] ?? json['msg'];
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }

  static void _requireSuccess(JsonObject json) {
    final rawCode = json['code'];
    if (rawCode is! num) {
      throw const MalformedApiResponseException('响应缺少有效的 code 字段');
    }
    final code = rawCode.toInt();
    if (code != 0) {
      throw ApiRejectedException(code: code, message: message(json));
    }
  }
}

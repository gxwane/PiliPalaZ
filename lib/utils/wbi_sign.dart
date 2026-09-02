// Wbi 签名，用于生成 REST API 请求中的 w_rid 和 wts 字段。
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../http/api_client.dart';
import '../http/api_decoder.dart';
import '../http/api_result.dart';
import '../http/http_runtime.dart';
import 'storage.dart';

final class WbiKeys {
  const WbiKeys({required this.imageKey, required this.subKey});

  final String imageKey;
  final String subKey;

  Map<String, String> toCache() => <String, String>{
    'imgKey': imageKey,
    'subKey': subKey,
  };
}

final class WbiSign {
  WbiSign({ApiClient? client, Box<dynamic>? cache})
    : _client = client ?? HttpRuntime.instance.client,
      _cache = cache ?? GStorage.localCache;

  final ApiClient _client;
  final Box<dynamic> _cache;

  static const List<int> _mixinKeyEncodingTable = <int>[
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  String _mixinKey(String original) {
    final buffer = StringBuffer();
    for (final index in _mixinKeyEncodingTable) {
      if (index >= original.length) {
        throw const FormatException('Wbi key is too short');
      }
      buffer.write(original[index]);
    }
    return buffer.toString().substring(0, 32);
  }

  Map<String, dynamic> _signature(Map<String, dynamic> params, WbiKeys keys) {
    final mixinKey = _mixinKey(keys.imageKey + keys.subKey);
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final characterFilter = RegExp(r"[!\'\(\)*]");
    final values = <String, dynamic>{...params, 'wts': timestamp};
    final names = values.keys.toList()..sort();
    final query = names
        .map(
          (name) =>
              '${Uri.encodeComponent(name)}='
              '${Uri.encodeComponent(values[name].toString().replaceAll(characterFilter, ''))}',
        )
        .join('&');
    return <String, dynamic>{
      'w_rid': md5.convert(utf8.encode(query + mixinKey)).toString(),
      'wts': timestamp.toString(),
    };
  }

  Future<ApiResult<WbiKeys>> getWbiKeys() async {
    final now = DateTime.now();
    final cachedKeys = _cache.get(LocalCacheKey.wbiKeys);
    final cachedTimestamp = _cache.get(LocalCacheKey.timeStamp);
    if (cachedKeys is Map && cachedTimestamp is int) {
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final sameDate =
          cachedAt.year == now.year &&
          cachedAt.month == now.month &&
          cachedAt.day == now.day;
      final imageKey = cachedKeys['imgKey'];
      final subKey = cachedKeys['subKey'];
      if (sameDate && imageKey is String && subKey is String) {
        return ApiSuccess<WbiKeys>(WbiKeys(imageKey: imageKey, subKey: subKey));
      }
    }

    final result = await _client.getJson<WbiKeys>(
      'https://api.bilibili.com/x/web-interface/nav',
      endpoint: 'wbi.keys',
      decode: (json) => BiliApiDecoder.data<WbiKeys>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final wbiImage = BiliApiDecoder.object(
            data['wbi_img'],
            field: 'data.wbi_img',
          );
          final imageUrl = wbiImage['img_url'];
          final subUrl = wbiImage['sub_url'];
          if (imageUrl is! String || subUrl is! String) {
            throw const MalformedApiResponseException('Wbi 密钥地址格式不正确');
          }
          return WbiKeys(
            imageKey: _fileStem(imageUrl),
            subKey: _fileStem(subUrl),
          );
        },
      ),
    );
    if (result case ApiSuccess<WbiKeys>(:final data)) {
      await _cache.put(LocalCacheKey.wbiKeys, data.toCache());
      await _cache.put(LocalCacheKey.timeStamp, now.millisecondsSinceEpoch);
    }
    return result;
  }

  Future<ApiResult<Map<String, dynamic>>> sign(
    Map<String, dynamic> params,
  ) async {
    final keys = await getWbiKeys();
    if (keys case ApiFailure<WbiKeys> failure) {
      return failure.cast<Map<String, dynamic>>();
    }
    try {
      final signature = _signature(params, (keys as ApiSuccess<WbiKeys>).data);
      return ApiSuccess<Map<String, dynamic>>(<String, dynamic>{
        ...params,
        ...signature,
      });
    } catch (_) {
      return const ApiFailure<Map<String, dynamic>>(
        kind: ApiFailureKind.decoding,
        message: '请求签名生成失败',
        endpoint: 'wbi.sign',
      );
    }
  }

  @Deprecated('Migrate the caller to sign() and handle ApiResult explicitly.')
  Future<Map<String, dynamic>> makSign(Map<String, dynamic> params) async {
    final result = await sign(params);
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      return data;
    }
    throw StateError((result as ApiFailure<Map<String, dynamic>>).message);
  }

  static String _fileStem(String url) {
    final path = Uri.parse(url).pathSegments;
    if (path.isEmpty) {
      throw const FormatException('Missing Wbi key path');
    }
    final filename = path.last;
    final dot = filename.lastIndexOf('.');
    return dot <= 0 ? filename : filename.substring(0, dot);
  }
}

import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import '../../http/constants.dart';
import '../../utils/storage.dart';
import '../../utils/storage_contract.dart';
import '../../utils/utils.dart';
import 'stored_session.dart';

abstract interface class LegacyCredentialSource {
  Future<StoredSession?> readSession();

  Future<void> deleteSession();

  Future<bool> hasSession();
}

final class HiveLegacyCredentialSource implements LegacyCredentialSource {
  HiveLegacyCredentialSource({
    required Box<dynamic> localCache,
    Future<Directory> Function()? cookieDirectory,
  }) : _localCache = localCache,
       _cookieDirectory = cookieDirectory ?? Utils.getLegacyCookieDirectory;

  static const List<String> _origins = <String>[
    HttpString.baseUrl,
    HttpString.apiBaseUrl,
    HttpString.tUrl,
    HttpString.appBaseUrl,
    HttpString.liveBaseUrl,
    HttpString.passBaseUrl,
    HttpString.messageBaseUrl,
    HttpString.spaceBaseUrl,
  ];

  final Box<dynamic> _localCache;
  final Future<Directory> Function() _cookieDirectory;

  @override
  Future<bool> hasSession() async {
    if (_localCache.containsKey(LocalCacheKey.accessKey)) {
      return true;
    }
    return await readSession() != null;
  }

  @override
  Future<StoredSession?> readSession() async {
    final token = _readTokenMap();
    final records = <String, StoredCookie>{};
    final directory = await _cookieDirectory();

    if (await directory.exists()) {
      final jar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage(directory.path),
      );
      for (final originText in _origins) {
        final origin = Uri.parse(originText);
        final cookies = await jar.loadForRequest(origin);
        for (final cookie in cookies) {
          final stored = StoredCookie.fromCookie(origin, cookie);
          final effectiveDomain = (stored.domain ?? origin.host)
              .toLowerCase()
              .replaceFirst(RegExp(r'^\\.'), '');
          final effectivePath = stored.path?.isNotEmpty == true
              ? stored.path!
              : '/';
          records['$effectiveDomain\n$effectivePath\n${stored.name}'] = stored;
        }
      }
    }

    int? mid = token?.mid;
    if (mid == null) {
      for (final cookie in records.values) {
        if (cookie.name == 'DedeUserID') {
          mid = int.tryParse(cookie.value);
          if (mid != null) {
            break;
          }
        }
      }
    }

    final cookies = records.values.toList(growable: false);
    final hasSessionCookie = cookies.any(
      (cookie) =>
          cookie.name == 'SESSDATA' &&
          cookie.value.isNotEmpty &&
          !cookie.isExpiredAt(DateTime.now().toUtc()),
    );
    if (token?.accessToken == null && !hasSessionCookie) {
      return null;
    }

    return StoredSession(
      schemaVersion: StoredSession.currentSchemaVersion,
      mid: mid,
      accessToken: token?.accessToken,
      refreshToken: token?.refreshToken,
      cookies: List<StoredCookie>.unmodifiable(cookies),
    );
  }

  @override
  Future<void> deleteSession() async {
    await _localCache.delete(LocalCacheKey.accessKey);
    final directory = await _cookieDirectory();
    final normalized = p.normalize(directory.absolute.path);
    if (p.basename(normalized) != StoragePathName.cookie) {
      throw StateError('Invalid legacy cookie directory.');
    }
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  _LegacyToken? _readTokenMap() {
    final raw = _localCache.get(LocalCacheKey.accessKey);
    if (raw is! Map) {
      return null;
    }
    final accessToken = _nonEmptyString(raw['value']);
    if (accessToken == null) {
      return null;
    }
    return _LegacyToken(
      mid: _parseMid(raw['mid']),
      accessToken: accessToken,
      refreshToken: _nonEmptyString(raw['refresh']),
    );
  }

  static int? _parseMid(Object? value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed > 0 ? parsed : null;
    }
    return null;
  }

  static String? _nonEmptyString(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}

final class _LegacyToken {
  const _LegacyToken({
    required this.mid,
    required this.accessToken,
    required this.refreshToken,
  });

  final int? mid;
  final String accessToken;
  final String? refreshToken;
}

import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';

import 'stored_session.dart';

typedef CookieSnapshotChanged =
    Future<void> Function(List<StoredCookie> cookies);

/// Keeps Bilibili cookies in memory and publishes redaction-safe snapshots for
/// persistence by the authentication layer.
///
/// Cookie matching remains delegated to [CookieJar]. This wrapper additionally
/// rejects cookies received outside Bilibili's HTTPS domain boundary and makes
/// persistence best-effort so a storage outage cannot turn a valid HTTP
/// response into a Dio failure.
final class SecureCookieJar implements CookieJar {
  SecureCookieJar({required this.onChanged, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final CookieSnapshotChanged onChanged;
  final DateTime Function() _clock;
  final CookieJar _delegate = CookieJar();
  final Map<String, StoredCookie> _records = <String, StoredCookie>{};

  Future<void> _persistenceQueue = Future<void>.value();

  /// Whether the most recently completed persistence callback failed.
  ///
  /// The underlying exception is deliberately not retained because it may
  /// contain platform diagnostics or credential material.
  bool _lastPersistenceFailed = false;

  bool get lastPersistenceFailed => _lastPersistenceFailed;

  @override
  bool get ignoreExpires => false;

  List<StoredCookie> get snapshot => _createSnapshot();

  /// Replaces the in-memory state without invoking [onChanged].
  Future<void> restore(List<StoredCookie> cookies) async {
    await _persistenceQueue;
    await _delegate.deleteAll();
    _records.clear();

    final now = _clock().toUtc();
    try {
      for (final stored in cookies) {
        final normalized = _normalizeRestored(stored, now);
        if (normalized == null) {
          continue;
        }
        final cookie = normalized.toCookie(now: now);
        if (cookie == null) {
          continue;
        }
        final origin = Uri.parse(normalized.origin);
        await _delegate.saveFromResponse(origin, <Cookie>[cookie]);
        _records[_recordKey(normalized)] = normalized;
      }
    } catch (_) {
      await _delegate.deleteAll();
      _records.clear();
      rethrow;
    }
  }

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async {
    if (!_isTrustedUri(uri)) {
      return const <Cookie>[];
    }

    final now = _clock().toUtc();
    final expiredKeys = _records.entries
        .where((entry) => entry.value.isExpiredAt(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    if (expiredKeys.isNotEmpty) {
      for (final key in expiredKeys) {
        _records.remove(key);
      }
      await _publishSnapshot();
    }

    final activeRecords = _records.values.toList(growable: false);
    final cookies = await _delegate.loadForRequest(uri);
    return cookies
        .where(
          (cookie) => activeRecords.any(
            (stored) =>
                stored.name == cookie.name &&
                stored.value == cookie.value &&
                _matchesRequest(stored, uri),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    if (!_isTrustedUri(uri)) {
      return;
    }

    final now = _clock().toUtc();
    final accepted = <Cookie>[];
    for (final cookie in cookies) {
      final normalized = _normalizeResponseCookie(uri, cookie, now);
      if (normalized == null) {
        continue;
      }
      final normalizedCookie = _toResponseCookie(normalized);
      accepted.add(normalizedCookie);

      final key = _recordKey(normalized);
      if (_isExpired(normalizedCookie, now)) {
        _records.remove(key);
      } else {
        _records[key] = normalized;
      }
    }

    if (accepted.isEmpty) {
      return;
    }
    await _delegate.saveFromResponse(uri, accepted);
    await _publishSnapshot();
  }

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) async {
    await _delegate.delete(uri, withDomainSharedCookie);
    final host = uri.host.toLowerCase();
    final keysToDelete = _records.entries
        .where((entry) {
          final cookie = entry.value;
          final domain = cookie.domain;
          if (domain == null) {
            return Uri.parse(cookie.origin).host.toLowerCase() == host;
          }
          return withDomainSharedCookie && _domainMatches(host, domain);
        })
        .map((entry) => entry.key)
        .toList(growable: false);
    if (keysToDelete.isEmpty) {
      return;
    }
    for (final key in keysToDelete) {
      _records.remove(key);
    }
    await _publishSnapshot();
  }

  @override
  Future<void> deleteAll() async {
    await _delegate.deleteAll();
    if (_records.isEmpty) {
      return;
    }
    _records.clear();
    await _publishSnapshot();
  }

  StoredCookie? _normalizeRestored(StoredCookie stored, DateTime now) {
    final origin = Uri.tryParse(stored.origin);
    if (origin == null || !_isTrustedUri(origin)) {
      return null;
    }
    final cookie = stored.toCookie(now: now);
    if (cookie == null) {
      return null;
    }
    final domain = _normalizeDomain(cookie.domain);
    if (cookie.domain != null && domain == null) {
      return null;
    }
    if (domain != null &&
        (!_isTrustedHost(domain) || !_domainMatches(origin.host, domain))) {
      return null;
    }
    return StoredCookie(
      origin: _originFor(origin),
      name: stored.name,
      value: stored.value,
      domain: domain,
      path: stored.path ?? '/',
      expires: stored.expires?.toUtc(),
      maxAge: stored.maxAge,
      secure: stored.secure,
      httpOnly: stored.httpOnly,
      sameSite: stored.sameSite,
    );
  }

  StoredCookie? _normalizeResponseCookie(Uri uri, Cookie cookie, DateTime now) {
    if (cookie.name.isEmpty) {
      return null;
    }
    final domain = _normalizeDomain(cookie.domain);
    if (cookie.domain != null && domain == null) {
      return null;
    }
    if (domain != null &&
        (!_isTrustedHost(domain) || !_domainMatches(uri.host, domain))) {
      return null;
    }
    final normalized = _copyCookie(
      cookie,
      domain: domain,
      path: cookie.path ?? _defaultPath(uri.path),
    );
    return StoredCookie.fromCookie(
      Uri.parse(_originFor(uri)),
      normalized,
      receivedAt: now,
    );
  }

  Cookie _toResponseCookie(StoredCookie stored) {
    return Cookie(stored.name, stored.value)
      ..domain = stored.domain
      ..path = stored.path
      ..expires = stored.expires
      ..maxAge = stored.maxAge
      ..secure = stored.secure
      ..httpOnly = stored.httpOnly
      ..sameSite = _sameSite(stored.sameSite);
  }

  Cookie _copyCookie(Cookie source, {String? domain, required String path}) {
    return Cookie(source.name, source.value)
      ..domain = domain
      ..path = path
      ..expires = source.expires?.toUtc()
      ..maxAge = source.maxAge
      ..secure = source.secure
      ..httpOnly = source.httpOnly
      ..sameSite = source.sameSite;
  }

  Future<void> _publishSnapshot() async {
    final current = _createSnapshot();
    _persistenceQueue = _persistenceQueue.then((_) async {
      try {
        await onChanged(current);
        _lastPersistenceFailed = false;
      } catch (_) {
        _lastPersistenceFailed = true;
      }
    });
    await _persistenceQueue;
  }

  List<StoredCookie> _createSnapshot() {
    final records = _records.values.toList(
      growable: false,
    )..sort((first, second) => _recordKey(first).compareTo(_recordKey(second)));
    return List<StoredCookie>.unmodifiable(records);
  }
}

bool _isTrustedUri(Uri uri) =>
    uri.scheme == 'https' && uri.userInfo.isEmpty && _isTrustedHost(uri.host);

bool _isTrustedHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'bilibili.com' || normalized.endsWith('.bilibili.com');
}

String? _normalizeDomain(String? domain) {
  if (domain == null) {
    return null;
  }
  var normalized = domain.trim().toLowerCase();
  while (normalized.startsWith('.')) {
    normalized = normalized.substring(1);
  }
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.isEmpty ? null : normalized;
}

bool _domainMatches(String host, String domain) {
  final normalizedHost = host.toLowerCase();
  final normalizedDomain = domain.toLowerCase();
  return normalizedHost == normalizedDomain ||
      normalizedHost.endsWith('.$normalizedDomain');
}

bool _matchesRequest(StoredCookie cookie, Uri uri) {
  if (cookie.secure && uri.scheme != 'https') {
    return false;
  }
  final domain = cookie.domain;
  final domainMatches = domain == null
      ? Uri.parse(cookie.origin).host.toLowerCase() == uri.host.toLowerCase()
      : _domainMatches(uri.host, domain);
  return domainMatches && _pathMatches(uri.path, cookie.path ?? '/');
}

bool _pathMatches(String requestPath, String cookiePath) {
  if (cookiePath == '/' || requestPath == cookiePath) {
    return true;
  }
  if (!requestPath.startsWith(cookiePath)) {
    return false;
  }
  return cookiePath.endsWith('/') ||
      requestPath.substring(cookiePath.length).startsWith('/');
}

String _defaultPath(String requestPath) {
  if (requestPath.isEmpty || !requestPath.startsWith('/')) {
    return '/';
  }
  final lastSlash = requestPath.lastIndexOf('/');
  if (lastSlash <= 0) {
    return '/';
  }
  return requestPath.substring(0, lastSlash);
}

String _originFor(Uri uri) => uri.origin;

String _recordKey(StoredCookie cookie) {
  final domain = cookie.domain ?? Uri.parse(cookie.origin).host;
  return '${domain.toLowerCase()}\u0000${cookie.path ?? '/'}\u0000${cookie.name}';
}

bool _isExpired(Cookie cookie, DateTime now) {
  final maxAge = cookie.maxAge;
  if (maxAge != null && maxAge <= 0) {
    return true;
  }
  final expires = cookie.expires;
  return expires != null && !expires.toUtc().isAfter(now);
}

SameSite? _sameSite(String? value) => switch (value) {
  'strict' => SameSite.strict,
  'lax' => SameSite.lax,
  'none' => SameSite.none,
  null => null,
  _ => throw const FormatException('Invalid stored cookie SameSite value.'),
};

import 'dart:io';

final class StoredSession {
  const StoredSession({
    required this.schemaVersion,
    required this.cookies,
    this.mid,
    this.accessToken,
    this.refreshToken,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int? mid;
  final String? accessToken;
  final String? refreshToken;
  final List<StoredCookie> cookies;

  bool get isAuthenticated =>
      accessToken?.isNotEmpty == true ||
      cookies.any(
        (cookie) => cookie.name == 'SESSDATA' && cookie.value.isNotEmpty,
      );

  Map<String, Object?> toJson() {
    if (schemaVersion != currentSchemaVersion) {
      throw const FormatException('Unsupported stored session schema.');
    }
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'mid': mid,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'cookies': cookies.map((cookie) => cookie.toJson()).toList(),
    };
  }

  factory StoredSession.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredValue<int>(json, 'schemaVersion');
    if (schemaVersion != currentSchemaVersion) {
      throw const FormatException('Unsupported stored session schema.');
    }

    final rawCookies = json['cookies'];
    if (rawCookies is! List<Object?>) {
      throw const FormatException('Invalid stored session cookies.');
    }

    final cookies = rawCookies
        .map((rawCookie) {
          if (rawCookie is! Map<Object?, Object?>) {
            throw const FormatException('Invalid stored cookie entry.');
          }
          if (rawCookie.keys.any((key) => key is! String)) {
            throw const FormatException('Invalid stored cookie keys.');
          }
          return StoredCookie.fromJson(rawCookie.cast<String, Object?>());
        })
        .toList(growable: false);

    return StoredSession(
      schemaVersion: schemaVersion,
      mid: _optionalValue<int>(json, 'mid'),
      accessToken: _optionalValue<String>(json, 'accessToken'),
      refreshToken: _optionalValue<String>(json, 'refreshToken'),
      cookies: List<StoredCookie>.unmodifiable(cookies),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredSession &&
          schemaVersion == other.schemaVersion &&
          mid == other.mid &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          _listEquals(cookies, other.cookies);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    mid,
    accessToken,
    refreshToken,
    Object.hashAll(cookies),
  );

  @override
  String toString() =>
      'StoredSession('
      'schemaVersion: $schemaVersion, '
      'hasAccessToken: ${accessToken?.isNotEmpty == true}, '
      'hasRefreshToken: ${refreshToken?.isNotEmpty == true}, '
      'cookieCount: ${cookies.length}, '
      'isAuthenticated: $isAuthenticated)';
}

final class StoredCookie {
  const StoredCookie({
    required this.origin,
    required this.name,
    required this.value,
    this.domain,
    this.path,
    this.expires,
    this.maxAge,
    this.secure = false,
    this.httpOnly = false,
    this.sameSite,
  });

  static const Set<String> _supportedSameSiteValues = <String>{
    'strict',
    'lax',
    'none',
  };

  final String origin;
  final String name;
  final String value;
  final String? domain;
  final String? path;
  final DateTime? expires;
  final int? maxAge;
  final bool secure;
  final bool httpOnly;
  final String? sameSite;

  bool isExpiredAt(DateTime now) {
    final absoluteExpiry = expires;
    if (absoluteExpiry != null) {
      return !absoluteExpiry.isAfter(now);
    }
    return maxAge != null && maxAge! <= 0;
  }

  Cookie? toCookie({DateTime? now}) {
    _validate();
    final referenceTime = (now ?? DateTime.now()).toUtc();
    if (isExpiredAt(referenceTime)) {
      return null;
    }

    final cookie = Cookie(name, value)
      ..domain = domain
      ..path = path
      ..expires = expires
      ..secure = secure
      ..httpOnly = httpOnly
      ..sameSite = _decodeSameSite(sameSite);

    final storedMaxAge = maxAge;
    if (storedMaxAge != null) {
      final absoluteExpiry = expires;
      if (absoluteExpiry == null) {
        return null;
      }
      final remainingMilliseconds = absoluteExpiry
          .toUtc()
          .difference(referenceTime)
          .inMilliseconds;
      cookie.maxAge = (remainingMilliseconds / 1000).ceil();
    }
    return cookie;
  }

  factory StoredCookie.fromCookie(
    Uri origin,
    Cookie cookie, {
    DateTime? receivedAt,
  }) {
    final capturedAt = (receivedAt ?? DateTime.now()).toUtc();
    final sourceMaxAge = cookie.maxAge;
    final absoluteExpiry = sourceMaxAge == null
        ? cookie.expires?.toUtc()
        : capturedAt.add(Duration(seconds: sourceMaxAge));

    final stored = StoredCookie(
      origin: origin.toString(),
      name: cookie.name,
      value: cookie.value,
      domain: cookie.domain,
      path: cookie.path,
      expires: absoluteExpiry,
      maxAge: sourceMaxAge,
      secure: cookie.secure,
      httpOnly: cookie.httpOnly,
      sameSite: cookie.sameSite?.name.toLowerCase(),
    );
    stored._validate();
    return stored;
  }

  Map<String, Object?> toJson() {
    _validate();
    return <String, Object?>{
      'origin': origin,
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'expires': expires?.toUtc().toIso8601String(),
      'maxAge': maxAge,
      'secure': secure,
      'httpOnly': httpOnly,
      'sameSite': sameSite,
    };
  }

  factory StoredCookie.fromJson(Map<String, Object?> json) {
    final expiresValue = _optionalValue<String>(json, 'expires');
    final expires = expiresValue == null
        ? null
        : DateTime.tryParse(expiresValue)?.toUtc();
    if (expiresValue != null && expires == null) {
      throw const FormatException('Invalid stored cookie expiry.');
    }

    final stored = StoredCookie(
      origin: _requiredValue<String>(json, 'origin'),
      name: _requiredValue<String>(json, 'name'),
      value: _requiredValue<String>(json, 'value'),
      domain: _optionalValue<String>(json, 'domain'),
      path: _optionalValue<String>(json, 'path'),
      expires: expires,
      maxAge: _optionalValue<int>(json, 'maxAge'),
      secure: _optionalValue<bool>(json, 'secure') ?? false,
      httpOnly: _optionalValue<bool>(json, 'httpOnly') ?? false,
      sameSite: _optionalValue<String>(json, 'sameSite'),
    );
    stored._validate();
    return stored;
  }

  void _validate() {
    final uri = Uri.tryParse(origin);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid stored cookie origin.');
    }
    if (name.isEmpty) {
      throw const FormatException('Invalid stored cookie name.');
    }
    if (sameSite != null && !_supportedSameSiteValues.contains(sameSite)) {
      throw const FormatException('Invalid stored cookie SameSite value.');
    }
    if (maxAge != null && maxAge! > 0 && expires == null) {
      throw const FormatException(
        'Stored Max-Age cookie requires an absolute expiry.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredCookie &&
          origin == other.origin &&
          name == other.name &&
          value == other.value &&
          domain == other.domain &&
          path == other.path &&
          expires == other.expires &&
          maxAge == other.maxAge &&
          secure == other.secure &&
          httpOnly == other.httpOnly &&
          sameSite == other.sameSite;

  @override
  int get hashCode => Object.hash(
    origin,
    name,
    value,
    domain,
    path,
    expires,
    maxAge,
    secure,
    httpOnly,
    sameSite,
  );

  @override
  String toString() =>
      'StoredCookie('
      'secure: $secure, '
      'httpOnly: $httpOnly, '
      'hasExpiry: ${expires != null}, '
      'hasMaxAge: ${maxAge != null}, '
      'hasSameSite: ${sameSite != null})';
}

T _requiredValue<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) {
    throw FormatException('Invalid required field: $key.');
  }
  return value;
}

T? _optionalValue<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! T) {
    throw FormatException('Invalid optional field: $key.');
  }
  return value as T;
}

SameSite? _decodeSameSite(String? value) => switch (value) {
  'strict' => SameSite.strict,
  'lax' => SameSite.lax,
  'none' => SameSite.none,
  null => null,
  _ => throw const FormatException('Invalid stored cookie SameSite value.'),
};

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) {
    return true;
  }
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

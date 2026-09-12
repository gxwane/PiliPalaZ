import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/auth/stored_session.dart';

void main() {
  group('StoredSession', () {
    const session = StoredSession(
      schemaVersion: StoredSession.currentSchemaVersion,
      mid: 42,
      accessToken: 'fake-access-token',
      refreshToken: 'fake-refresh-token',
      cookies: <StoredCookie>[
        StoredCookie(
          origin: 'https://api.bilibili.com',
          name: 'SESSDATA',
          value: 'fake-cookie',
          domain: '.bilibili.com',
          path: '/',
          secure: true,
          httpOnly: true,
          sameSite: 'lax',
        ),
      ],
    );

    test('round trips every supported field', () {
      expect(StoredSession.fromJson(session.toJson()), session);
      expect(session.isAuthenticated, isTrue);
    });

    test('classifies token, cookie, and anonymous sessions', () {
      const anonymous = StoredSession(
        schemaVersion: StoredSession.currentSchemaVersion,
        cookies: <StoredCookie>[
          StoredCookie(
            origin: 'https://www.bilibili.com',
            name: 'buvid3',
            value: 'fake-anonymous-cookie',
          ),
        ],
      );
      const tokenSession = StoredSession(
        schemaVersion: StoredSession.currentSchemaVersion,
        accessToken: 'fake-token',
        cookies: <StoredCookie>[],
      );
      const cookieSession = StoredSession(
        schemaVersion: StoredSession.currentSchemaVersion,
        cookies: <StoredCookie>[
          StoredCookie(
            origin: 'https://www.bilibili.com',
            name: 'SESSDATA',
            value: 'fake-session-cookie',
          ),
        ],
      );

      expect(anonymous.isAuthenticated, isFalse);
      expect(tokenSession.isAuthenticated, isTrue);
      expect(cookieSession.isAuthenticated, isTrue);
    });

    test('rejects malformed primitive fields', () {
      final valid = session.toJson();

      expect(
        () => StoredSession.fromJson(<String, Object?>{
          ...valid,
          'schemaVersion': '1',
        }),
        throwsFormatException,
      );
      expect(
        () => StoredSession.fromJson(<String, Object?>{...valid, 'mid': 42.0}),
        throwsFormatException,
      );
      expect(
        () => StoredSession.fromJson(<String, Object?>{
          ...valid,
          'accessToken': 42,
        }),
        throwsFormatException,
      );
      expect(
        () => StoredSession.fromJson(<String, Object?>{
          ...valid,
          'cookies': 'not-a-list',
        }),
        throwsFormatException,
      );
      expect(
        () => StoredSession.fromJson(<String, Object?>{
          ...valid,
          'cookies': <Object?>['not-an-object'],
        }),
        throwsFormatException,
      );
    });

    test('rejects unknown schema versions', () {
      expect(
        () => StoredSession.fromJson(<String, Object?>{
          ...session.toJson(),
          'schemaVersion': StoredSession.currentSchemaVersion + 1,
        }),
        throwsFormatException,
      );
    });

    test('redacts all credential values in diagnostics', () {
      expect(session.toString(), isNot(contains('fake-access-token')));
      expect(session.toString(), isNot(contains('fake-refresh-token')));
      expect(session.toString(), isNot(contains('fake-cookie')));
      expect(session.cookies.single.toString(), isNot(contains('fake-cookie')));
      expect(session.toString(), contains('cookieCount: 1'));
    });
  });

  group('StoredCookie', () {
    test('round trips JSON and dart:io Cookie fields', () {
      final expires = DateTime.utc(2030, 1, 2, 3, 4, 5);
      final cookie = Cookie('SESSDATA', 'fake-cookie')
        ..domain = '.bilibili.com'
        ..path = '/'
        ..expires = expires
        ..maxAge = 3600
        ..secure = true
        ..httpOnly = true
        ..sameSite = SameSite.strict;

      final receivedAt = DateTime.utc(2029, 12, 31, 3, 4, 5);
      final stored = StoredCookie.fromCookie(
        Uri.parse('https://api.bilibili.com'),
        cookie,
        receivedAt: receivedAt,
      );
      final restored = stored.toCookie(now: receivedAt);

      expect(StoredCookie.fromJson(stored.toJson()), stored);
      expect(restored, isNotNull);
      expect(restored!.name, cookie.name);
      expect(restored.value, cookie.value);
      expect(restored.domain, cookie.domain);
      expect(restored.path, cookie.path);
      expect(restored.expires, receivedAt.add(const Duration(hours: 1)));
      expect(restored.maxAge, 3600);
      expect(restored.secure, isTrue);
      expect(restored.httpOnly, isTrue);
      expect(restored.sameSite, SameSite.strict);
    });

    test('does not reset Max-Age after a restart', () {
      final receivedAt = DateTime.utc(2030, 1, 1, 12);
      final responseCookie = Cookie('SESSDATA', 'fake-cookie')..maxAge = 3600;
      final stored = StoredCookie.fromCookie(
        Uri.parse('https://api.bilibili.com'),
        responseCookie,
        receivedAt: receivedAt,
      );
      final decoded = StoredCookie.fromJson(stored.toJson());

      expect(stored.expires, receivedAt.add(const Duration(hours: 1)));
      expect(
        decoded
            .toCookie(now: receivedAt.add(const Duration(minutes: 45)))
            ?.maxAge,
        900,
      );
      expect(
        decoded.toCookie(now: receivedAt.add(const Duration(hours: 1))),
        isNull,
      );
      expect(
        decoded.toCookie(now: receivedAt.add(const Duration(hours: 2))),
        isNull,
      );
    });

    test('identifies expired cookies deterministically', () {
      final stored = StoredCookie(
        origin: 'https://api.bilibili.com',
        name: 'SESSDATA',
        value: 'fake-cookie',
        expires: DateTime.utc(2025),
      );

      expect(stored.isExpiredAt(DateTime.utc(2026)), isTrue);
      expect(stored.isExpiredAt(DateTime.utc(2024)), isFalse);
      expect(
        const StoredCookie(
          origin: 'https://api.bilibili.com',
          name: 'SESSDATA',
          value: 'fake-cookie',
          maxAge: 0,
        ).isExpiredAt(DateTime.utc(2024)),
        isTrue,
      );
    });

    test('rejects unsafe origins, empty names, and unsupported SameSite', () {
      expect(
        () => StoredCookie.fromJson(<String, Object?>{
          'origin': 'http://api.bilibili.com',
          'name': 'SESSDATA',
          'value': 'fake-cookie',
        }),
        throwsFormatException,
      );
      expect(
        () => StoredCookie.fromJson(<String, Object?>{
          'origin': 'https://api.bilibili.com',
          'name': '',
          'value': 'fake-cookie',
        }),
        throwsFormatException,
      );
      expect(
        () => StoredCookie.fromJson(<String, Object?>{
          'origin': 'https://api.bilibili.com',
          'name': 'SESSDATA',
          'value': 'fake-cookie',
          'sameSite': 'invalid',
        }),
        throwsFormatException,
      );
    });

    test('rejects malformed optional primitive fields', () {
      final base = <String, Object?>{
        'origin': 'https://api.bilibili.com',
        'name': 'SESSDATA',
        'value': 'fake-cookie',
      };

      for (final invalid in <Map<String, Object?>>[
        <String, Object?>{...base, 'expires': 42},
        <String, Object?>{...base, 'expires': 'not-a-date'},
        <String, Object?>{...base, 'maxAge': 1.5},
        <String, Object?>{...base, 'secure': 'true'},
        <String, Object?>{...base, 'httpOnly': 1},
      ]) {
        expect(() => StoredCookie.fromJson(invalid), throwsFormatException);
      }
    });
  });
}

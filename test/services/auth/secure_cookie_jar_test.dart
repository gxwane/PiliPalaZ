import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/auth/secure_cookie_jar.dart';
import 'package:pilipalaz/services/auth/stored_session.dart';

void main() {
  final futureExpiry = DateTime.utc(2035, 1, 1);

  StoredCookie sessionCookie({
    String origin = 'https://api.bilibili.com',
    String value = 'fake-session',
  }) {
    return StoredCookie(
      origin: origin,
      name: 'SESSDATA',
      value: value,
      domain: 'bilibili.com',
      path: '/',
      expires: futureExpiry,
      secure: true,
      httpOnly: true,
    );
  }

  test('restore is silent and shares Bilibili domain cookies safely', () async {
    final snapshots = <List<StoredCookie>>[];
    final jar = SecureCookieJar(
      onChanged: (cookies) async => snapshots.add(cookies),
    );

    await jar.restore(<StoredCookie>[sessionCookie()]);

    expect(snapshots, isEmpty);
    expect(
      await jar.loadForRequest(Uri.parse('https://space.bilibili.com/42')),
      contains(
        isA<Cookie>()
            .having((cookie) => cookie.name, 'name', 'SESSDATA')
            .having((cookie) => cookie.value, 'value', 'fake-session'),
      ),
    );
    expect(
      await jar.loadForRequest(Uri.parse('https://example.com/')),
      isEmpty,
    );
    expect(
      await jar.loadForRequest(Uri.parse('http://api.bilibili.com/')),
      isEmpty,
    );
  });

  test('save emits a normalized snapshot with an absolute expiry', () async {
    final snapshots = <List<StoredCookie>>[];
    final jar = SecureCookieJar(
      onChanged: (cookies) async => snapshots.add(cookies),
    );
    final cookie = Cookie('bili_jct', 'fake-csrf')
      ..domain = '.BILIBILI.COM'
      ..maxAge = 3600
      ..secure = true
      ..httpOnly = true;

    await jar.saveFromResponse(
      Uri.parse('https://api.bilibili.com/x/web-interface/nav'),
      <Cookie>[cookie],
    );

    expect(snapshots, hasLength(1));
    final stored = snapshots.single.single;
    expect(stored.origin, 'https://api.bilibili.com');
    expect(stored.domain, 'bilibili.com');
    expect(stored.path, '/x/web-interface');
    expect(stored.maxAge, 3600);
    expect(stored.expires, isNotNull);
    expect(stored.expires!.isAfter(DateTime.now().toUtc()), isTrue);
  });

  test('expired response cookies remove their normalized record', () async {
    final snapshots = <List<StoredCookie>>[];
    final jar = SecureCookieJar(
      onChanged: (cookies) async => snapshots.add(cookies),
    );
    final uri = Uri.parse('https://api.bilibili.com/');
    final active = Cookie('SESSDATA', 'fake-session')
      ..domain = '.bilibili.com'
      ..path = '/'
      ..secure = true;
    final deletion = Cookie('SESSDATA', '')
      ..domain = '.bilibili.com'
      ..path = '/'
      ..maxAge = 0
      ..secure = true;

    await jar.saveFromResponse(uri, <Cookie>[active]);
    await jar.saveFromResponse(uri, <Cookie>[deletion]);

    expect(snapshots, hasLength(2));
    expect(snapshots.last, isEmpty);
    expect(await jar.loadForRequest(uri), isEmpty);
  });

  test('restore drops expired cookies without publishing a mutation', () async {
    final snapshots = <List<StoredCookie>>[];
    final jar = SecureCookieJar(
      onChanged: (cookies) async => snapshots.add(cookies),
    );

    await jar.restore(<StoredCookie>[
      StoredCookie(
        origin: 'https://api.bilibili.com',
        name: 'SESSDATA',
        value: 'expired-session',
        domain: 'bilibili.com',
        path: '/',
        expires: DateTime.utc(2020),
        secure: true,
      ),
    ]);

    expect(jar.snapshot, isEmpty);
    expect(snapshots, isEmpty);
    expect(
      await jar.loadForRequest(Uri.parse('https://api.bilibili.com/')),
      isEmpty,
    );
  });

  test('load prunes cookies that expire during the process lifetime', () async {
    var now = DateTime.utc(2030, 1, 1);
    final snapshots = <List<StoredCookie>>[];
    final jar = SecureCookieJar(
      clock: () => now,
      onChanged: (cookies) async => snapshots.add(cookies),
    );
    final uri = Uri.parse('https://api.bilibili.com/');
    final expiring = Cookie('SESSDATA', 'short-session')
      ..domain = '.bilibili.com'
      ..path = '/'
      ..maxAge = 60
      ..secure = true;

    await jar.saveFromResponse(uri, <Cookie>[expiring]);
    now = now.add(const Duration(minutes: 2));

    expect(await jar.loadForRequest(uri), isEmpty);
    expect(jar.snapshot, isEmpty);
    expect(snapshots, hasLength(2));
    expect(snapshots.last, isEmpty);
  });

  test(
    'rejects unrelated responses forging a Bilibili domain cookie',
    () async {
      final snapshots = <List<StoredCookie>>[];
      final jar = SecureCookieJar(
        onChanged: (cookies) async => snapshots.add(cookies),
      );
      final forged = Cookie('SESSDATA', 'forged-session')
        ..domain = '.bilibili.com'
        ..path = '/'
        ..secure = true;

      await jar.saveFromResponse(Uri.parse('https://example.com/'), <Cookie>[
        forged,
      ]);

      expect(snapshots, isEmpty);
      expect(
        await jar.loadForRequest(Uri.parse('https://api.bilibili.com/')),
        isEmpty,
      );
    },
  );

  test('delete mirrors host and shared-domain cookie scopes', () async {
    final snapshots = <List<StoredCookie>>[];
    final jar = SecureCookieJar(
      onChanged: (cookies) async => snapshots.add(cookies),
    );
    await jar.restore(<StoredCookie>[
      sessionCookie(),
      StoredCookie(
        origin: 'https://api.bilibili.com',
        name: 'host-only',
        value: 'fake-host-value',
        path: '/',
        expires: futureExpiry,
        secure: true,
      ),
    ]);

    await jar.delete(Uri.parse('https://api.bilibili.com/'));

    expect(snapshots.single.map((cookie) => cookie.name), contains('SESSDATA'));
    expect(
      snapshots.single.map((cookie) => cookie.name),
      isNot(contains('host-only')),
    );

    await jar.delete(Uri.parse('https://api.bilibili.com/'), true);

    expect(snapshots.last, isEmpty);
  });

  test('persistence callback failures never fail cookie mutations', () async {
    var shouldFail = true;
    final jar = SecureCookieJar(
      onChanged: (_) async {
        if (shouldFail) {
          throw StateError('fake storage failure with secret material');
        }
      },
    );
    final uri = Uri.parse('https://api.bilibili.com/');

    await expectLater(
      jar.saveFromResponse(uri, <Cookie>[Cookie('first', 'fake-value')]),
      completes,
    );
    expect(jar.lastPersistenceFailed, isTrue);

    shouldFail = false;
    await jar.saveFromResponse(uri, <Cookie>[Cookie('second', 'fake-value')]);
    expect(jar.lastPersistenceFailed, isFalse);
  });
}

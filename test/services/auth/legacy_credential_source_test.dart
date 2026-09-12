import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/constants.dart';
import 'package:pilipalaz/services/auth/legacy_credential_source.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  late Directory root;
  late Directory cookieDirectory;
  late Box<dynamic> localCache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pilipalaz-legacy-auth-');
    Hive.init('${root.path}/hive');
    localCache = await Hive.openBox<dynamic>(
      'local-cache-${DateTime.now().microsecondsSinceEpoch}',
    );
    cookieDirectory = Directory('${root.path}/.plpl');
  });

  tearDown(() async {
    await localCache.close();
    await Hive.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  HiveLegacyCredentialSource createSource({Directory? directory}) {
    return HiveLegacyCredentialSource(
      localCache: localCache,
      cookieDirectory: () async => directory ?? cookieDirectory,
    );
  }

  test('reads a legacy token map without exposing it', () async {
    await localCache.put(LocalCacheKey.accessKey, <String, Object?>{
      'mid': '42',
      'value': 'fake-access-token',
      'refresh': 'fake-refresh-token',
    });

    final session = await createSource().readSession();

    expect(session, isNotNull);
    expect(session!.mid, 42);
    expect(session.accessToken, 'fake-access-token');
    expect(session.refreshToken, 'fake-refresh-token');
  });

  test('loads and deduplicates legacy Bilibili domain cookies', () async {
    await cookieDirectory.create(recursive: true);
    final jar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage(cookieDirectory.path),
    );
    await jar.saveFromResponse(Uri.parse(HttpString.apiBaseUrl), <Cookie>[
      Cookie('SESSDATA', 'fake-session')
        ..domain = '.bilibili.com'
        ..path = '/'
        ..secure = true,
      Cookie('DedeUserID', '42')
        ..domain = '.bilibili.com'
        ..path = '/'
        ..secure = true,
    ]);

    final session = await createSource().readSession();

    expect(session, isNotNull);
    expect(session!.mid, 42);
    expect(
      session.cookies.where((cookie) => cookie.name == 'SESSDATA'),
      hasLength(1),
    );
    expect(
      session.cookies.map((cookie) => cookie.origin),
      everyElement(startsWith('https://')),
    );
  });

  test(
    'malformed token data is ignored when no session cookie exists',
    () async {
      await localCache.put(LocalCacheKey.accessKey, <String, Object?>{
        'mid': -1,
        'value': 7,
        'refresh': <String>['invalid'],
      });

      expect(await createSource().readSession(), isNull);
      expect(await createSource().hasSession(), isTrue);
    },
  );

  test(
    'an empty legacy directory is not classified as a login session',
    () async {
      await cookieDirectory.create(recursive: true);

      expect(await createSource().hasSession(), isFalse);
    },
  );

  test(
    'deletion removes only the bounded legacy locations and is idempotent',
    () async {
      await localCache.put(LocalCacheKey.accessKey, <String, Object?>{
        'value': 'fake-access-token',
      });
      await cookieDirectory.create(recursive: true);
      await File('${cookieDirectory.path}/fixture').writeAsString('fixture');
      final source = createSource();

      await source.deleteSession();
      await source.deleteSession();

      expect(localCache.containsKey(LocalCacheKey.accessKey), isFalse);
      expect(await cookieDirectory.exists(), isFalse);
    },
  );

  test('deletion rejects a directory outside the legacy basename', () async {
    final unsafeDirectory = Directory('${root.path}/not-cookie-storage');
    await unsafeDirectory.create();

    await expectLater(
      createSource(directory: unsafeDirectory).deleteSession(),
      throwsStateError,
    );
    expect(await unsafeDirectory.exists(), isTrue);
  });
}

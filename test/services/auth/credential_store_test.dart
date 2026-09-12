import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/auth/credential_store.dart';
import 'package:pilipalaz/services/auth/flutter_secure_credential_store.dart';
import 'package:pilipalaz/services/auth/stored_session.dart';

import 'fake_credential_store.dart';

void main() {
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
      ),
    ],
  );

  group('CredentialStore contract fake', () {
    test('round trips sessions and install IDs', () async {
      final store = MemoryCredentialStore();

      expect(await store.readSession(), isNull);
      expect(await store.readInstallId(), isNull);

      await store.writeSession(session);
      await store.writeInstallId('fake-install-id');

      expect(await store.readSession(), session);
      expect(await store.readInstallId(), 'fake-install-id');
    });
  });

  group('FlutterSecureCredentialStore', () {
    test('production options fail closed without auto-erasing credentials', () {
      final source = File(
        'lib/services/auth/flutter_secure_credential_store.dart',
      ).readAsStringSync();

      expect(source, contains('migrateWithBackup: true'));
      expect(source, contains('resetOnError: false'));
      expect(source, contains('KeychainAccessibility.unlocked_this_device'));
    });

    test('encodes and decodes the versioned JSON object', () async {
      final backend = MemorySecureStorageBackend();
      final store = FlutterSecureCredentialStore(backend: backend);

      await store.writeSession(session);

      expect(
        backend.values[FlutterSecureCredentialStore.sessionKey],
        allOf(contains('"schemaVersion":1'), contains('"fake-access-token"')),
      );
      expect(await store.readSession(), session);
    });

    test('returns null when the namespaced session key is absent', () async {
      final store = FlutterSecureCredentialStore(
        backend: MemorySecureStorageBackend(),
      );

      expect(await store.readSession(), isNull);
    });

    test('classifies malformed and non-object JSON as corrupt', () async {
      for (final payload in <String>[
        'fake-corrupt-payload',
        '["not-an-object"]',
        '{"schemaVersion":999,"cookies":[]}',
      ]) {
        final backend = MemorySecureStorageBackend()
          ..values[FlutterSecureCredentialStore.sessionKey] = payload;
        final store = FlutterSecureCredentialStore(backend: backend);

        await expectLater(
          store.readSession(),
          throwsA(
            isA<CredentialStoreFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  CredentialStoreFailureKind.corrupt,
                )
                .having(
                  (failure) => failure.toString(),
                  'redacted message',
                  isNot(contains(payload)),
                ),
          ),
        );
      }
    });

    test('maps backend failures without exposing caught values', () async {
      const secret = 'fake-backend-secret';
      final readBackend = MemorySecureStorageBackend()
        ..readError = StateError(secret);
      final writeBackend = MemorySecureStorageBackend()
        ..writeError = StateError(secret);
      final deleteBackend = MemorySecureStorageBackend()
        ..deleteError = StateError(secret);

      await _expectFailure(
        FlutterSecureCredentialStore(backend: readBackend).readSession(),
        CredentialStoreFailureKind.unavailable,
        secret,
      );
      await _expectFailure(
        FlutterSecureCredentialStore(
          backend: writeBackend,
        ).writeSession(session),
        CredentialStoreFailureKind.writeFailed,
        secret,
      );
      await _expectFailure(
        FlutterSecureCredentialStore(backend: deleteBackend).deleteSession(),
        CredentialStoreFailureKind.deleteFailed,
        secret,
      );
    });

    test('deletes only the application session namespace', () async {
      final backend = MemorySecureStorageBackend()
        ..values.addAll(<String, String>{
          FlutterSecureCredentialStore.sessionKey: 'fake-session',
          FlutterSecureCredentialStore.installIdKey: 'fake-install-id',
          'unrelated.key': 'must-remain',
        });
      final store = FlutterSecureCredentialStore(backend: backend);

      await store.deleteSession();

      expect(backend.deletedKeys, <String>[
        FlutterSecureCredentialStore.sessionKey,
      ]);
      expect(
        backend.values[FlutterSecureCredentialStore.installIdKey],
        'fake-install-id',
      );
      expect(backend.values['unrelated.key'], 'must-remain');
    });

    test('round trips the install identity using its own key', () async {
      final backend = MemorySecureStorageBackend();
      final store = FlutterSecureCredentialStore(backend: backend);

      await store.writeInstallId('fake-install-id');

      expect(await store.readInstallId(), 'fake-install-id');
      expect(
        backend.values[FlutterSecureCredentialStore.installIdKey],
        'fake-install-id',
      );
      expect(
        backend.values.containsKey(FlutterSecureCredentialStore.sessionKey),
        isFalse,
      );
    });

    test('rejects empty install identity without persisting it', () async {
      final backend = MemorySecureStorageBackend();
      final store = FlutterSecureCredentialStore(backend: backend);

      await expectLater(store.writeInstallId(''), throwsArgumentError);

      expect(backend.values, isEmpty);
    });
  });
}

Future<void> _expectFailure(
  Future<void> future,
  CredentialStoreFailureKind kind,
  String secret,
) async {
  await expectLater(
    future,
    throwsA(
      isA<CredentialStoreFailure>()
          .having((failure) => failure.kind, 'kind', kind)
          .having(
            (failure) => failure.toString(),
            'redacted message',
            isNot(contains(secret)),
          ),
    ),
  );
}

final class MemorySecureStorageBackend implements SecureStorageBackend {
  final Map<String, String> values = <String, String>{};
  final List<String> deletedKeys = <String>[];
  Object? readError;
  Object? writeError;
  Object? deleteError;

  @override
  Future<void> delete({required String key}) async {
    if (deleteError case final error?) {
      throw error;
    }
    deletedKeys.add(key);
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    if (readError case final error?) {
      throw error;
    }
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (writeError case final error?) {
      throw error;
    }
    values[key] = value;
  }
}

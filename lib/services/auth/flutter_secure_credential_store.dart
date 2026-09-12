import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'credential_store.dart';
import 'stored_session.dart';

abstract interface class SecureStorageBackend {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

final class FlutterSecureStorageBackend implements SecureStorageBackend {
  FlutterSecureStorageBackend({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              migrateWithBackup: true,
              resetOnError: false,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

final class FlutterSecureCredentialStore implements CredentialStore {
  FlutterSecureCredentialStore({SecureStorageBackend? backend})
    : _backend = backend ?? FlutterSecureStorageBackend();

  static const String sessionKey = 'pilipalaz.auth.session.v1';
  static const String installIdKey = 'pilipalaz.auth.install-id.v1';

  final SecureStorageBackend _backend;

  @override
  Future<StoredSession?> readSession() async {
    final String? encoded;
    try {
      encoded = await _backend.read(key: sessionKey);
    } catch (_) {
      throw const CredentialStoreFailure(
        CredentialStoreFailureKind.unavailable,
      );
    }
    if (encoded == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<Object?, Object?> ||
          decoded.keys.any((key) => key is! String)) {
        throw const FormatException('Stored session must be a JSON object.');
      }
      return StoredSession.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      throw const CredentialStoreFailure(CredentialStoreFailureKind.corrupt);
    }
  }

  @override
  Future<void> writeSession(StoredSession session) async {
    try {
      await _backend.write(
        key: sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {
      throw const CredentialStoreFailure(
        CredentialStoreFailureKind.writeFailed,
      );
    }
  }

  @override
  Future<void> deleteSession() async {
    try {
      await _backend.delete(key: sessionKey);
    } catch (_) {
      throw const CredentialStoreFailure(
        CredentialStoreFailureKind.deleteFailed,
      );
    }
  }

  @override
  Future<String?> readInstallId() async {
    final String? value;
    try {
      value = await _backend.read(key: installIdKey);
    } catch (_) {
      throw const CredentialStoreFailure(
        CredentialStoreFailureKind.unavailable,
      );
    }
    if (value?.isEmpty == true) {
      throw const CredentialStoreFailure(CredentialStoreFailureKind.corrupt);
    }
    return value;
  }

  @override
  Future<void> writeInstallId(String value) async {
    if (value.isEmpty) {
      throw ArgumentError.value(null, 'value', 'Install identity is empty.');
    }
    try {
      await _backend.write(key: installIdKey, value: value);
    } catch (_) {
      throw const CredentialStoreFailure(
        CredentialStoreFailureKind.writeFailed,
      );
    }
  }
}

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../utils/storage.dart';
import 'credential_store.dart';
import 'legacy_credential_source.dart';
import 'stored_session.dart';

enum AuthStartupState {
  authenticated,
  anonymous,
  reauthRequired,
  storageTemporarilyUnavailable,
  logoutCleanupPending,
}

enum AuthStorageHealth { available, temporarilyUnavailable, cleanupPending }

enum InstallIdentityState { firstRun, sameInstall, replacedInstall }

enum AuthSessionFailureKind { invalidSession, saveFailed, verificationFailed }

final class AuthStartupResult {
  const AuthStartupResult(this.state);

  final AuthStartupState state;
}

final class AuthLogoutResult {
  const AuthLogoutResult({required this.cleanupPending});

  final bool cleanupPending;
}

final class AuthSessionFailure implements Exception {
  const AuthSessionFailure(this.kind);

  final AuthSessionFailureKind kind;

  @override
  String toString() => 'AuthSessionFailure(kind: ${kind.name})';
}

abstract interface class AuthLocalState {
  Future<String?> readInstallId();

  Future<void> writeInstallId(String value);

  Future<bool> readLogoutPending();

  Future<void> writeLogoutPending(bool value);

  Future<void> clearUserInfo();
}

final class HiveAuthLocalState implements AuthLocalState {
  HiveAuthLocalState({
    required Box<dynamic> localCache,
    required Box<dynamic> userInfo,
  }) : _localCache = localCache,
       _userInfo = userInfo;

  final Box<dynamic> _localCache;
  final Box<dynamic> _userInfo;

  @override
  Future<void> clearUserInfo() => _userInfo.clear();

  @override
  Future<String?> readInstallId() async {
    final value = _localCache.get(LocalCacheKey.authInstallId);
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  Future<bool> readLogoutPending() async =>
      _localCache.get(LocalCacheKey.authLogoutPending, defaultValue: false) ==
      true;

  @override
  Future<void> writeInstallId(String value) =>
      _localCache.put(LocalCacheKey.authInstallId, value);

  @override
  Future<void> writeLogoutPending(bool value) =>
      _localCache.put(LocalCacheKey.authLogoutPending, value);
}

InstallIdentityState compareInstallIds(String? localId, String? secureId) {
  if (localId == null && secureId == null) {
    return InstallIdentityState.firstRun;
  }
  if (localId != null && localId == secureId) {
    return InstallIdentityState.sameInstall;
  }
  return InstallIdentityState.replacedInstall;
}

final class AuthSessionManager {
  AuthSessionManager({
    required CredentialStore credentialStore,
    required LegacyCredentialSource legacySource,
    required AuthLocalState localState,
    String Function()? installIdGenerator,
  }) : _credentialStore = credentialStore,
       _legacySource = legacySource,
       _localState = localState,
       _installIdGenerator = installIdGenerator ?? const Uuid().v4;

  final CredentialStore _credentialStore;
  final LegacyCredentialSource _legacySource;
  final AuthLocalState _localState;
  final String Function() _installIdGenerator;

  StoredSession? _session;
  AuthStorageHealth _storageHealth = AuthStorageHealth.available;
  Future<void> Function()? _clearRuntimeCredentials;

  StoredSession? get session => _session;
  bool get isAuthenticated => _session?.isAuthenticated == true;
  String? get accessToken => _session?.accessToken;
  AuthStorageHealth get storageHealth => _storageHealth;

  void registerRuntimeCredentialClear(Future<void> Function() clear) {
    _clearRuntimeCredentials = clear;
  }

  Future<AuthStartupResult> initialize() async {
    _session = null;

    if (await _localState.readLogoutPending()) {
      final cleaned = await _clearAllCredentialLayers();
      if (!cleaned) {
        _storageHealth = AuthStorageHealth.cleanupPending;
        return const AuthStartupResult(AuthStartupState.logoutCleanupPending);
      }
      await _localState.writeLogoutPending(false);
    }

    final localId = await _localState.readInstallId();
    String? secureId;
    var secureMarkerCorrupt = false;
    try {
      secureId = await _credentialStore.readInstallId();
    } on CredentialStoreFailure catch (failure) {
      if (failure.kind == CredentialStoreFailureKind.corrupt) {
        secureMarkerCorrupt = true;
      } else {
        return _storageUnavailable();
      }
    } catch (_) {
      return _storageUnavailable();
    }

    final identityState = secureMarkerCorrupt
        ? InstallIdentityState.replacedInstall
        : compareInstallIds(localId, secureId);
    return switch (identityState) {
      InstallIdentityState.firstRun => _initializeFirstRun(),
      InstallIdentityState.sameInstall => _restoreSameInstall(),
      InstallIdentityState.replacedInstall => _resetReplacedInstall(),
    };
  }

  Future<void> saveLogin(StoredSession candidate) async {
    if (!candidate.isAuthenticated) {
      throw const AuthSessionFailure(AuthSessionFailureKind.invalidSession);
    }

    try {
      final verified = await _writeSessionVerified(candidate);
      _session = verified;
      _storageHealth = AuthStorageHealth.available;
    } catch (error) {
      _session = null;
      await _localState.clearUserInfo();
      var cleanupPending = false;
      try {
        cleanupPending = !await _deleteSecureSessionVerified();
      } catch (_) {
        cleanupPending = true;
      }
      if (cleanupPending) {
        await _localState.writeLogoutPending(true);
        _storageHealth = AuthStorageHealth.cleanupPending;
      }
      if (error is AuthSessionFailure) {
        rethrow;
      }
      throw const AuthSessionFailure(AuthSessionFailureKind.saveFailed);
    }
  }

  Future<void> persistCookieSnapshot(List<StoredCookie> cookies) async {
    final current = _session;
    if (current == null) {
      return;
    }
    final next = StoredSession(
      schemaVersion: current.schemaVersion,
      mid: current.mid,
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
      cookies: List<StoredCookie>.unmodifiable(cookies),
    );
    try {
      _session = await _writeSessionVerified(next);
      _storageHealth = AuthStorageHealth.available;
    } catch (_) {
      _storageHealth = AuthStorageHealth.temporarilyUnavailable;
      throw const AuthSessionFailure(AuthSessionFailureKind.saveFailed);
    }
  }

  Future<AuthLogoutResult> logout() async {
    _session = null;
    try {
      await _localState.writeLogoutPending(true);
    } catch (_) {
      // Cleanup still proceeds even when the non-sensitive marker cannot be
      // written.
    }

    var cleaned = await _clearAllCredentialLayers();
    try {
      await _localState.writeLogoutPending(!cleaned);
    } catch (_) {
      cleaned = false;
    }
    _storageHealth = cleaned
        ? AuthStorageHealth.available
        : AuthStorageHealth.cleanupPending;
    return AuthLogoutResult(cleanupPending: !cleaned);
  }

  Future<AuthStartupResult> _initializeFirstRun() async {
    bool hasLegacy;
    try {
      hasLegacy = await _legacySource.hasSession();
    } catch (_) {
      hasLegacy = true;
    }

    if (!hasLegacy) {
      try {
        if (!await _deleteSecureSessionVerified()) {
          return _storageUnavailable();
        }
        await _legacySource.deleteSession();
        await _writeFreshInstallIds();
        await _localState.clearUserInfo();
        _storageHealth = AuthStorageHealth.available;
        return const AuthStartupResult(AuthStartupState.anonymous);
      } catch (_) {
        return _storageUnavailable();
      }
    }

    try {
      final legacySession = await _legacySource.readSession();
      if (legacySession == null) {
        throw const FormatException('Legacy session is invalid.');
      }
      final verified = await _writeSessionVerified(legacySession);
      await _legacySource.deleteSession();
      await _writeFreshInstallIds();
      _session = verified;
      _storageHealth = AuthStorageHealth.available;
      if (!verified.isAuthenticated) {
        await _localState.clearUserInfo();
      }
      return AuthStartupResult(
        verified.isAuthenticated
            ? AuthStartupState.authenticated
            : AuthStartupState.anonymous,
      );
    } on CredentialStoreFailure catch (failure) {
      if (!await _cleanupFailedMigration()) {
        return _migrationCleanupPending();
      }
      if (failure.kind == CredentialStoreFailureKind.unavailable) {
        return _storageUnavailable();
      }
      return const AuthStartupResult(AuthStartupState.reauthRequired);
    } catch (_) {
      if (!await _cleanupFailedMigration()) {
        return _migrationCleanupPending();
      }
      return const AuthStartupResult(AuthStartupState.reauthRequired);
    }
  }

  Future<AuthStartupResult> _restoreSameInstall() async {
    StoredSession? restored;
    try {
      restored = await _credentialStore.readSession();
    } on CredentialStoreFailure catch (failure) {
      if (failure.kind == CredentialStoreFailureKind.corrupt) {
        final cleaned = await _clearAllCredentialLayers();
        if (cleaned) {
          _storageHealth = AuthStorageHealth.available;
          return const AuthStartupResult(AuthStartupState.reauthRequired);
        }
      }
      return _storageUnavailable();
    } catch (_) {
      return _storageUnavailable();
    }

    try {
      await _legacySource.deleteSession();
    } catch (_) {
      // The verified secure copy remains authoritative. Cleanup is retried on
      // the next start without exposing credential values to diagnostics.
    }

    _session = restored;
    _storageHealth = AuthStorageHealth.available;
    if (restored?.isAuthenticated != true) {
      await _localState.clearUserInfo();
    }
    return AuthStartupResult(
      restored?.isAuthenticated == true
          ? AuthStartupState.authenticated
          : AuthStartupState.anonymous,
    );
  }

  Future<AuthStartupResult> _resetReplacedInstall() async {
    final cleaned = await _clearAllCredentialLayers();
    if (!cleaned) {
      return _storageUnavailable();
    }
    try {
      await _writeFreshInstallIds();
    } catch (_) {
      return _storageUnavailable();
    }
    _storageHealth = AuthStorageHealth.available;
    return const AuthStartupResult(AuthStartupState.reauthRequired);
  }

  Future<StoredSession> _writeSessionVerified(StoredSession value) async {
    try {
      await _credentialStore.writeSession(value);
      final readBack = await _credentialStore.readSession();
      if (readBack != value) {
        throw const AuthSessionFailure(
          AuthSessionFailureKind.verificationFailed,
        );
      }
      return readBack!;
    } on AuthSessionFailure {
      rethrow;
    } on CredentialStoreFailure {
      rethrow;
    } catch (_) {
      throw const AuthSessionFailure(AuthSessionFailureKind.saveFailed);
    }
  }

  Future<bool> _deleteSecureSessionVerified() async {
    try {
      await _credentialStore.deleteSession();
      return await _credentialStore.readSession() == null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _clearAllCredentialLayers() async {
    _session = null;
    var cleaned = true;

    try {
      await _clearRuntimeCredentials?.call();
    } catch (_) {
      // Runtime credentials live only in memory and cannot survive restart.
    }
    try {
      await _localState.clearUserInfo();
    } catch (_) {
      cleaned = false;
    }
    try {
      await _legacySource.deleteSession();
    } catch (_) {
      cleaned = false;
    }
    if (!await _deleteSecureSessionVerified()) {
      cleaned = false;
    }
    return cleaned;
  }

  Future<bool> _cleanupFailedMigration() async {
    _session = null;
    var cleaned = true;
    try {
      await _localState.clearUserInfo();
    } catch (_) {
      cleaned = false;
    }
    try {
      await _legacySource.deleteSession();
    } catch (_) {
      cleaned = false;
    }
    final secureDeleted = await _deleteSecureSessionVerified();
    if (!secureDeleted) {
      cleaned = false;
    }
    if (secureDeleted) {
      try {
        await _writeFreshInstallIds();
      } catch (_) {}
    }
    return cleaned;
  }

  Future<AuthStartupResult> _migrationCleanupPending() async {
    try {
      await _localState.writeLogoutPending(true);
    } catch (_) {}
    _storageHealth = AuthStorageHealth.cleanupPending;
    return const AuthStartupResult(AuthStartupState.logoutCleanupPending);
  }

  Future<void> _writeFreshInstallIds() async {
    final installId = _installIdGenerator();
    if (installId.isEmpty) {
      throw StateError('Install identity generator returned an empty value.');
    }
    await _credentialStore.writeInstallId(installId);
    await _localState.writeInstallId(installId);
  }

  Future<AuthStartupResult> _storageUnavailable() async {
    _session = null;
    _storageHealth = AuthStorageHealth.temporarilyUnavailable;
    try {
      await _localState.clearUserInfo();
    } catch (_) {}
    return const AuthStartupResult(
      AuthStartupState.storageTemporarilyUnavailable,
    );
  }
}

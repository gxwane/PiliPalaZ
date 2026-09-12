import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/auth/auth_session_manager.dart';
import 'package:pilipalaz/services/auth/credential_store.dart';
import 'package:pilipalaz/services/auth/legacy_credential_source.dart';
import 'package:pilipalaz/services/auth/stored_session.dart';

void main() {
  group('compareInstallIds', () {
    test('implements the installation identity table', () {
      expect(compareInstallIds(null, null), InstallIdentityState.firstRun);
      expect(
        compareInstallIds('same-id', 'same-id'),
        InstallIdentityState.sameInstall,
      );
      expect(
        compareInstallIds('local-id', null),
        InstallIdentityState.replacedInstall,
      );
      expect(
        compareInstallIds(null, 'secure-id'),
        InstallIdentityState.replacedInstall,
      );
      expect(
        compareInstallIds('local-id', 'secure-id'),
        InstallIdentityState.replacedInstall,
      );
    });
  });

  group('AuthSessionManager.initialize', () {
    test('creates both markers on a fresh anonymous installation', () async {
      final fixture = _Fixture();

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.anonymous);
      expect(fixture.manager.session, isNull);
      expect(fixture.manager.storageHealth, AuthStorageHealth.available);
      expect(fixture.local.installId, 'generated-install-id');
      expect(fixture.secure.installId, 'generated-install-id');
      expect(fixture.local.userInfoClearCount, 1);
      expect(
        fixture.trace,
        containsAllInOrder(<String>[
          'local.readLogoutPending',
          'local.readInstallId',
          'secure.readInstallId',
          'legacy.hasSession',
          'secure.deleteSession',
          'secure.readSession',
          'secure.writeInstallId:generated-install-id',
          'local.writeInstallId:generated-install-id',
          'local.clearUserInfo',
        ]),
      );
    });

    test('migrates an old installation before deleting plaintext', () async {
      final fixture = _Fixture(
        legacySession: _authenticatedSession,
        legacyPresent: true,
      );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.authenticated);
      expect(fixture.manager.session, _authenticatedSession);
      expect(fixture.legacy.deleted, isTrue);
      expect(fixture.secure.session, _authenticatedSession);
      expect(fixture.local.installId, 'generated-install-id');
      expect(fixture.secure.installId, 'generated-install-id');
      expect(
        fixture.trace,
        containsAllInOrder(<String>[
          'legacy.readSession',
          'secure.writeSession',
          'secure.readSession',
          'legacy.deleteSession',
          'secure.writeInstallId:generated-install-id',
          'local.writeInstallId:generated-install-id',
        ]),
      );
    });

    test('restores a matching secure installation', () async {
      final fixture = _Fixture(
        localInstallId: 'same-id',
        secureInstallId: 'same-id',
        secureSession: _authenticatedSession,
      );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.authenticated);
      expect(fixture.manager.session, _authenticatedSession);
      expect(fixture.manager.accessToken, 'fake-access-token');
      expect(fixture.manager.isAuthenticated, isTrue);
      expect(fixture.local.userInfoClearCount, 0);
    });

    test(
      'secure session wins and stale legacy credentials are removed',
      () async {
        final fixture = _Fixture(
          localInstallId: 'same-id',
          secureInstallId: 'same-id',
          secureSession: _authenticatedSession,
          legacySession: _otherAuthenticatedSession,
          legacyPresent: true,
        );

        final result = await fixture.manager.initialize();

        expect(result.state, AuthStartupState.authenticated);
        expect(fixture.manager.session, _authenticatedSession);
        expect(fixture.legacy.readCount, 0);
        expect(fixture.legacy.deleted, isTrue);
        expect(
          fixture.trace,
          containsAllInOrder(<String>[
            'secure.readSession',
            'legacy.deleteSession',
          ]),
        );
      },
    );

    test(
      'stale legacy cleanup failure does not discard secure session',
      () async {
        final fixture = _Fixture(
          localInstallId: 'same-id',
          secureInstallId: 'same-id',
          secureSession: _authenticatedSession,
          legacySession: _otherAuthenticatedSession,
          legacyPresent: true,
        )..legacy.deleteError = StateError('fake cleanup failure');

        final result = await fixture.manager.initialize();

        expect(result.state, AuthStartupState.authenticated);
        expect(fixture.manager.session, _authenticatedSession);
        expect(fixture.secure.session, _authenticatedSession);
      },
    );

    test('matching markers without a session start anonymously', () async {
      final fixture = _Fixture(
        localInstallId: 'same-id',
        secureInstallId: 'same-id',
      );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.anonymous);
      expect(fixture.local.userInfoClearCount, 1);
      expect(fixture.manager.isAuthenticated, isFalse);
    });

    for (final entry in <({String name, String? localId, String? secureId})>[
      (name: 'local-only marker', localId: 'local-id', secureId: null),
      (name: 'secure-only marker', localId: null, secureId: 'secure-id'),
      (name: 'mismatched markers', localId: 'local-id', secureId: 'secure-id'),
    ]) {
      test('${entry.name} is treated as a replaced installation', () async {
        final fixture = _Fixture(
          localInstallId: entry.localId,
          secureInstallId: entry.secureId,
          secureSession: _authenticatedSession,
          legacySession: _otherAuthenticatedSession,
          legacyPresent: true,
        );

        final result = await fixture.manager.initialize();

        expect(result.state, AuthStartupState.reauthRequired);
        expect(fixture.manager.session, isNull);
        expect(fixture.secure.session, isNull);
        expect(fixture.legacy.deleted, isTrue);
        expect(fixture.local.userInfoClearCount, 1);
        expect(fixture.local.installId, 'generated-install-id');
        expect(fixture.secure.installId, 'generated-install-id');
        expect(fixture.legacy.readCount, 0);
      });
    }

    test('a corrupt install marker is treated as a replaced install', () async {
      final fixture =
          _Fixture(
              localInstallId: 'local-id',
              secureInstallId: 'old-secure-id',
              secureSession: _authenticatedSession,
            )
            ..secure.readInstallIdError = const CredentialStoreFailure(
              CredentialStoreFailureKind.corrupt,
            );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.reauthRequired);
      expect(fixture.secure.session, isNull);
      expect(fixture.local.installId, 'generated-install-id');
      expect(fixture.secure.installId, 'generated-install-id');
    });

    test('a corrupt secure session is cleared and requires login', () async {
      final fixture = _Fixture(
        localInstallId: 'same-id',
        secureInstallId: 'same-id',
        secureSession: _authenticatedSession,
      );
      fixture.secure.sessionReadBehaviors.add(
        () => throw const CredentialStoreFailure(
          CredentialStoreFailureKind.corrupt,
        ),
      );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.reauthRequired);
      expect(fixture.secure.session, isNull);
      expect(fixture.local.userInfoClearCount, 1);
      expect(fixture.manager.storageHealth, AuthStorageHealth.available);
    });

    test('unavailable marker storage preserves existing credentials', () async {
      final fixture =
          _Fixture(
              localInstallId: 'same-id',
              secureInstallId: 'same-id',
              secureSession: _authenticatedSession,
              legacySession: _otherAuthenticatedSession,
              legacyPresent: true,
            )
            ..secure.readInstallIdError = const CredentialStoreFailure(
              CredentialStoreFailureKind.unavailable,
            );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.storageTemporarilyUnavailable);
      expect(fixture.manager.session, isNull);
      expect(
        fixture.manager.storageHealth,
        AuthStorageHealth.temporarilyUnavailable,
      );
      expect(fixture.secure.session, _authenticatedSession);
      expect(fixture.legacy.deleted, isFalse);
      expect(fixture.local.userInfoClearCount, 1);
    });

    test('unavailable session storage does not delete secure data', () async {
      final fixture = _Fixture(
        localInstallId: 'same-id',
        secureInstallId: 'same-id',
        secureSession: _authenticatedSession,
      );
      fixture.secure.sessionReadBehaviors.add(
        () => throw const CredentialStoreFailure(
          CredentialStoreFailureKind.unavailable,
        ),
      );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.storageTemporarilyUnavailable);
      expect(fixture.secure.session, _authenticatedSession);
      expect(fixture.trace, isNot(contains('secure.deleteSession')));
    });

    test(
      'migration write failure removes plaintext and partial data',
      () async {
        final fixture =
            _Fixture(legacySession: _authenticatedSession, legacyPresent: true)
              ..secure.writeSessionError = const CredentialStoreFailure(
                CredentialStoreFailureKind.writeFailed,
              );

        final result = await fixture.manager.initialize();

        expect(result.state, AuthStartupState.reauthRequired);
        expect(fixture.manager.session, isNull);
        expect(fixture.legacy.deleted, isTrue);
        expect(fixture.secure.session, isNull);
        expect(
          fixture.trace,
          containsAllInOrder(<String>[
            'secure.writeSession',
            'local.clearUserInfo',
            'legacy.deleteSession',
            'secure.deleteSession',
            'secure.readSession',
          ]),
        );
      },
    );

    test(
      'migration read-back mismatch removes both credential copies',
      () async {
        final fixture = _Fixture(
          legacySession: _authenticatedSession,
          legacyPresent: true,
        );
        fixture.secure.sessionReadBehaviors.add(
          () async => _otherAuthenticatedSession,
        );

        final result = await fixture.manager.initialize();

        expect(result.state, AuthStartupState.reauthRequired);
        expect(fixture.manager.session, isNull);
        expect(fixture.legacy.deleted, isTrue);
        expect(fixture.secure.session, isNull);
        expect(fixture.local.userInfoClearCount, 1);
      },
    );

    test(
      'migration read-back outage clears copies and runs anonymously',
      () async {
        final fixture = _Fixture(
          legacySession: _authenticatedSession,
          legacyPresent: true,
        );
        fixture.secure.sessionReadBehaviors.add(
          () => throw const CredentialStoreFailure(
            CredentialStoreFailureKind.unavailable,
          ),
        );

        final result = await fixture.manager.initialize();

        expect(result.state, AuthStartupState.storageTemporarilyUnavailable);
        expect(fixture.manager.session, isNull);
        expect(fixture.legacy.deleted, isTrue);
        expect(fixture.secure.session, isNull);
        expect(
          fixture.manager.storageHealth,
          AuthStorageHealth.temporarilyUnavailable,
        );
      },
    );

    test(
      'failed migration cleanup blocks recovery until it can be retried',
      () async {
        final fixture = _Fixture(
          legacySession: _authenticatedSession,
          legacyPresent: true,
        );
        fixture.secure.sessionReadBehaviors.add(
          () async => _otherAuthenticatedSession,
        );
        fixture.secure.deleteSessionError = const CredentialStoreFailure(
          CredentialStoreFailureKind.deleteFailed,
        );

        final result = await fixture.manager.initialize();

        expect(result.state, AuthStartupState.logoutCleanupPending);
        expect(fixture.manager.session, isNull);
        expect(fixture.manager.storageHealth, AuthStorageHealth.cleanupPending);
        expect(fixture.local.logoutPending, isTrue);
        expect(fixture.legacy.deleted, isTrue);
        expect(fixture.secure.session, _authenticatedSession);
      },
    );

    test('invalid legacy data is removed and requires login', () async {
      final fixture = _Fixture(legacyPresent: true);

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.reauthRequired);
      expect(fixture.legacy.deleted, isTrue);
      expect(fixture.secure.session, isNull);
    });

    test('initialization is stable when repeated', () async {
      final fixture = _Fixture(
        legacySession: _authenticatedSession,
        legacyPresent: true,
      );

      final first = await fixture.manager.initialize();
      final second = await fixture.manager.initialize();

      expect(first.state, AuthStartupState.authenticated);
      expect(second.state, AuthStartupState.authenticated);
      expect(fixture.manager.session, _authenticatedSession);
      expect(fixture.legacy.readCount, 1);
      expect(fixture.secure.writeSessionCount, 1);
    });

    test('pending logout cleanup completes before normal restore', () async {
      final fixture = _Fixture(
        localInstallId: 'same-id',
        secureInstallId: 'same-id',
        secureSession: _authenticatedSession,
        legacySession: _otherAuthenticatedSession,
        legacyPresent: true,
        logoutPending: true,
      );
      var runtimeClearCount = 0;
      fixture.manager.registerRuntimeCredentialClear(() async {
        runtimeClearCount++;
        fixture.trace.add('runtime.clear');
      });

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.anonymous);
      expect(fixture.local.logoutPending, isFalse);
      expect(runtimeClearCount, 1);
      expect(fixture.secure.session, isNull);
      expect(fixture.legacy.deleted, isTrue);
      expect(
        fixture.trace,
        containsAllInOrder(<String>[
          'local.readLogoutPending',
          'runtime.clear',
          'legacy.deleteSession',
          'secure.deleteSession',
          'local.writeLogoutPending:false',
          'local.readInstallId',
        ]),
      );
    });

    test('failed pending logout cleanup blocks credential recovery', () async {
      final fixture =
          _Fixture(
              localInstallId: 'same-id',
              secureInstallId: 'same-id',
              secureSession: _authenticatedSession,
              logoutPending: true,
            )
            ..secure.deleteSessionError = const CredentialStoreFailure(
              CredentialStoreFailureKind.deleteFailed,
            );

      final result = await fixture.manager.initialize();

      expect(result.state, AuthStartupState.logoutCleanupPending);
      expect(fixture.manager.session, isNull);
      expect(fixture.local.logoutPending, isTrue);
      expect(fixture.manager.storageHealth, AuthStorageHealth.cleanupPending);
      expect(fixture.trace, isNot(contains('local.readInstallId')));
      expect(fixture.trace, isNot(contains('secure.readSession')));
    });
  });

  group('AuthSessionManager.saveLogin', () {
    test('publishes a login only after verified secure persistence', () async {
      final fixture = _Fixture();

      await fixture.manager.saveLogin(_authenticatedSession);

      expect(fixture.manager.session, _authenticatedSession);
      expect(fixture.manager.isAuthenticated, isTrue);
      expect(fixture.manager.storageHealth, AuthStorageHealth.available);
      expect(fixture.trace, <String>[
        'secure.writeSession',
        'secure.readSession',
      ]);
    });

    test('rejects an anonymous candidate without touching storage', () async {
      final fixture = _Fixture();

      await expectLater(
        fixture.manager.saveLogin(_anonymousSession),
        throwsA(
          isA<AuthSessionFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthSessionFailureKind.invalidSession,
          ),
        ),
      );

      expect(fixture.trace, isEmpty);
      expect(fixture.manager.session, isNull);
    });

    test('verification mismatch clears the incomplete login', () async {
      final fixture = _Fixture();
      fixture.secure.sessionReadBehaviors.add(
        () async => _otherAuthenticatedSession,
      );

      await expectLater(
        fixture.manager.saveLogin(_authenticatedSession),
        throwsA(
          isA<AuthSessionFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthSessionFailureKind.verificationFailed,
          ),
        ),
      );

      expect(fixture.manager.session, isNull);
      expect(fixture.secure.session, isNull);
      expect(fixture.local.userInfoClearCount, 1);
      expect(fixture.local.logoutPending, isFalse);
    });

    test('failed save reports a redacted categorized failure', () async {
      final fixture = _Fixture()
        ..secure.writeSessionError = const CredentialStoreFailure(
          CredentialStoreFailureKind.writeFailed,
        );

      await expectLater(
        fixture.manager.saveLogin(_authenticatedSession),
        throwsA(
          isA<AuthSessionFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                AuthSessionFailureKind.saveFailed,
              )
              .having(
                (failure) => failure.toString(),
                'redacted output',
                isNot(contains('fake-access-token')),
              ),
        ),
      );

      expect(fixture.manager.session, isNull);
      expect(fixture.secure.session, isNull);
      expect(fixture.local.userInfoClearCount, 1);
    });

    test('failed cleanup sets the non-sensitive pending flag', () async {
      final fixture = _Fixture()
        ..secure.writeSessionError = const CredentialStoreFailure(
          CredentialStoreFailureKind.writeFailed,
        )
        ..secure.deleteSessionError = const CredentialStoreFailure(
          CredentialStoreFailureKind.deleteFailed,
        );

      await expectLater(
        fixture.manager.saveLogin(_authenticatedSession),
        throwsA(isA<AuthSessionFailure>()),
      );

      expect(fixture.local.logoutPending, isTrue);
      expect(fixture.manager.storageHealth, AuthStorageHealth.cleanupPending);
    });
  });

  group('AuthSessionManager.persistCookieSnapshot', () {
    test('updates cookies without changing token fields', () async {
      final fixture = _Fixture();
      await fixture.manager.saveLogin(_authenticatedSession);
      fixture.trace.clear();

      await fixture.manager.persistCookieSnapshot(<StoredCookie>[
        _authenticatedSession.cookies.single,
        const StoredCookie(
          origin: 'https://www.bilibili.com',
          name: 'bili_jct',
          value: 'fake-csrf',
          domain: '.bilibili.com',
          path: '/',
          secure: true,
        ),
      ]);

      expect(fixture.manager.session?.accessToken, 'fake-access-token');
      expect(fixture.manager.session?.refreshToken, 'fake-refresh-token');
      expect(fixture.manager.session?.cookies, hasLength(2));
      expect(fixture.trace, <String>[
        'secure.writeSession',
        'secure.readSession',
      ]);
    });

    test('does nothing when there is no active session', () async {
      final fixture = _Fixture();

      await fixture.manager.persistCookieSnapshot(const <StoredCookie>[]);

      expect(fixture.trace, isEmpty);
    });
  });

  group('AuthSessionManager.logout', () {
    test('clears runtime first and attempts every credential layer', () async {
      final fixture = _Fixture(
        legacySession: _otherAuthenticatedSession,
        legacyPresent: true,
      );
      await fixture.manager.saveLogin(_authenticatedSession);
      fixture.trace.clear();
      fixture.manager.registerRuntimeCredentialClear(() async {
        expect(fixture.manager.session, isNull);
        fixture.trace.add('runtime.clear');
      });

      final result = await fixture.manager.logout();

      expect(result.cleanupPending, isFalse);
      expect(fixture.manager.session, isNull);
      expect(fixture.manager.isAuthenticated, isFalse);
      expect(fixture.local.logoutPending, isFalse);
      expect(fixture.local.userInfoClearCount, 1);
      expect(fixture.legacy.deleted, isTrue);
      expect(fixture.secure.session, isNull);
      expect(fixture.manager.storageHealth, AuthStorageHealth.available);
      expect(
        fixture.trace,
        containsAllInOrder(<String>[
          'local.writeLogoutPending:true',
          'runtime.clear',
          'local.clearUserInfo',
          'legacy.deleteSession',
          'secure.deleteSession',
          'secure.readSession',
          'local.writeLogoutPending:false',
        ]),
      );
    });

    test(
      'secure deletion failure keeps logout pending and stays logged out',
      () async {
        final fixture = _Fixture();
        await fixture.manager.saveLogin(_authenticatedSession);
        fixture.secure.deleteSessionError = const CredentialStoreFailure(
          CredentialStoreFailureKind.deleteFailed,
        );
        fixture.trace.clear();

        final result = await fixture.manager.logout();

        expect(result.cleanupPending, isTrue);
        expect(fixture.manager.session, isNull);
        expect(fixture.manager.isAuthenticated, isFalse);
        expect(fixture.local.logoutPending, isTrue);
        expect(fixture.local.userInfoClearCount, 1);
        expect(fixture.manager.storageHealth, AuthStorageHealth.cleanupPending);
        expect(fixture.trace, contains('legacy.deleteSession'));
      },
    );
  });
}

const _authenticatedSession = StoredSession(
  schemaVersion: StoredSession.currentSchemaVersion,
  mid: 42,
  accessToken: 'fake-access-token',
  refreshToken: 'fake-refresh-token',
  cookies: <StoredCookie>[
    StoredCookie(
      origin: 'https://api.bilibili.com',
      name: 'SESSDATA',
      value: 'fake-session-cookie',
      domain: '.bilibili.com',
      path: '/',
      secure: true,
      httpOnly: true,
    ),
  ],
);

const _otherAuthenticatedSession = StoredSession(
  schemaVersion: StoredSession.currentSchemaVersion,
  mid: 84,
  accessToken: 'other-fake-access-token',
  refreshToken: 'other-fake-refresh-token',
  cookies: <StoredCookie>[],
);

const _anonymousSession = StoredSession(
  schemaVersion: StoredSession.currentSchemaVersion,
  cookies: <StoredCookie>[],
);

final class _Fixture {
  _Fixture({
    String? localInstallId,
    String? secureInstallId,
    StoredSession? secureSession,
    StoredSession? legacySession,
    bool legacyPresent = false,
    bool logoutPending = false,
  }) : local = _FakeLocalState(
         trace: <String>[],
         installId: localInstallId,
         logoutPending: logoutPending,
       ),
       secure = _FakeCredentialStore(
         trace: <String>[],
         installId: secureInstallId,
         session: secureSession,
       ),
       legacy = _FakeLegacySource(
         trace: <String>[],
         session: legacySession,
         present: legacyPresent,
       ) {
    local.trace = trace;
    secure.trace = trace;
    legacy.trace = trace;
    manager = AuthSessionManager(
      credentialStore: secure,
      legacySource: legacy,
      localState: local,
      installIdGenerator: () => 'generated-install-id',
    );
  }

  final List<String> trace = <String>[];
  final _FakeLocalState local;
  final _FakeCredentialStore secure;
  final _FakeLegacySource legacy;
  late final AuthSessionManager manager;
}

final class _FakeLocalState implements AuthLocalState {
  _FakeLocalState({
    required this.trace,
    this.installId,
    this.logoutPending = false,
  });

  List<String> trace;
  String? installId;
  bool logoutPending;
  int userInfoClearCount = 0;

  @override
  Future<void> clearUserInfo() async {
    trace.add('local.clearUserInfo');
    userInfoClearCount++;
  }

  @override
  Future<String?> readInstallId() async {
    trace.add('local.readInstallId');
    return installId;
  }

  @override
  Future<bool> readLogoutPending() async {
    trace.add('local.readLogoutPending');
    return logoutPending;
  }

  @override
  Future<void> writeInstallId(String value) async {
    trace.add('local.writeInstallId:$value');
    installId = value;
  }

  @override
  Future<void> writeLogoutPending(bool value) async {
    trace.add('local.writeLogoutPending:$value');
    logoutPending = value;
  }
}

final class _FakeCredentialStore implements CredentialStore {
  _FakeCredentialStore({required this.trace, this.installId, this.session});

  List<String> trace;
  String? installId;
  StoredSession? session;
  Object? readInstallIdError;
  Object? writeInstallIdError;
  Object? writeSessionError;
  Object? deleteSessionError;
  final List<Future<StoredSession?> Function()> sessionReadBehaviors =
      <Future<StoredSession?> Function()>[];
  int writeSessionCount = 0;

  @override
  Future<void> deleteSession() async {
    trace.add('secure.deleteSession');
    if (deleteSessionError case final error?) {
      throw error;
    }
    session = null;
  }

  @override
  Future<String?> readInstallId() async {
    trace.add('secure.readInstallId');
    if (readInstallIdError case final error?) {
      throw error;
    }
    return installId;
  }

  @override
  Future<StoredSession?> readSession() async {
    trace.add('secure.readSession');
    if (sessionReadBehaviors.isNotEmpty) {
      return sessionReadBehaviors.removeAt(0)();
    }
    return session;
  }

  @override
  Future<void> writeInstallId(String value) async {
    trace.add('secure.writeInstallId:$value');
    if (writeInstallIdError case final error?) {
      throw error;
    }
    installId = value;
  }

  @override
  Future<void> writeSession(StoredSession value) async {
    trace.add('secure.writeSession');
    writeSessionCount++;
    if (writeSessionError case final error?) {
      throw error;
    }
    session = value;
  }
}

final class _FakeLegacySource implements LegacyCredentialSource {
  _FakeLegacySource({
    required this.trace,
    required this.session,
    required this.present,
  });

  List<String> trace;
  StoredSession? session;
  bool present;
  bool deleted = false;
  Object? hasError;
  Object? readError;
  Object? deleteError;
  int readCount = 0;

  @override
  Future<void> deleteSession() async {
    trace.add('legacy.deleteSession');
    if (deleteError case final error?) {
      throw error;
    }
    deleted = true;
    present = false;
    session = null;
  }

  @override
  Future<bool> hasSession() async {
    trace.add('legacy.hasSession');
    if (hasError case final error?) {
      throw error;
    }
    return present;
  }

  @override
  Future<StoredSession?> readSession() async {
    trace.add('legacy.readSession');
    readCount++;
    if (readError case final error?) {
      throw error;
    }
    return session;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/auth/login_session_commit.dart';
import 'package:pilipalaz/services/auth/stored_session.dart';

void main() {
  const session = StoredSession(
    schemaVersion: StoredSession.currentSchemaVersion,
    accessToken: 'fake-access-token',
    cookies: <StoredCookie>[],
  );

  test(
    'secure save and runtime replacement precede account validation',
    () async {
      final operations = <String>[];
      final committer = LoginSessionCommitter<String>(
        saveSecurely: (_) async => operations.add('save'),
        replaceRuntime: (_) async => operations.add('replace'),
        verifyAccount: () async {
          operations.add('verify');
          return 'verified-user';
        },
        rollback: () async => operations.add('rollback'),
      );

      expect(await committer.commit(session), 'verified-user');
      expect(operations, <String>['save', 'replace', 'verify']);
    },
  );

  test('secure save failure prevents validation and rolls back', () async {
    final operations = <String>[];
    final committer = LoginSessionCommitter<String>(
      saveSecurely: (_) async {
        operations.add('save');
        throw StateError('fake storage failure');
      },
      replaceRuntime: (_) async => operations.add('replace'),
      verifyAccount: () async {
        operations.add('verify');
        return 'should-not-run';
      },
      rollback: () async => operations.add('rollback'),
    );

    await expectLater(
      committer.commit(session),
      throwsA(isA<LoginSessionCommitFailure>()),
    );
    expect(operations, <String>['save', 'rollback']);
  });

  test('invalid account validation rolls back published credentials', () async {
    final operations = <String>[];
    final committer = LoginSessionCommitter<String>(
      saveSecurely: (_) async => operations.add('save'),
      replaceRuntime: (_) async => operations.add('replace'),
      verifyAccount: () async {
        operations.add('verify');
        return null;
      },
      rollback: () async => operations.add('rollback'),
    );

    await expectLater(
      committer.commit(session),
      throwsA(isA<LoginSessionCommitFailure>()),
    );
    expect(operations, <String>['save', 'replace', 'verify', 'rollback']);
  });

  test('login payload is normalized without real account data', () {
    final parsed = parseLoginSession(
      <String, dynamic>{
        'mid': '42',
        'access_token': 'fake-access-token',
        'refresh_token': 'fake-refresh-token',
      },
      <String, dynamic>{
        'cookies': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'SESSDATA',
            'value': 'fake-cookie',
            'expires': 2000000000,
          },
        ],
      },
    );

    expect(parsed.mid, 42);
    expect(parsed.cookies.single.domain, 'bilibili.com');
    expect(parsed.cookies.single.secure, isTrue);
    expect(parsed.isAuthenticated, isTrue);
  });
}

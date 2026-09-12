import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/auth/auth_session_manager.dart';
import 'package:pilipalaz/services/auth/login_session_commit.dart';

void main() {
  group('LogoutSessionCoordinator', () {
    test('successful logout coordinates all cleanup steps', () async {
      final operations = <String>[];
      final toasts = <String>[];
      bool? refreshedStatus;

      final coordinator = LogoutSessionCoordinator(
        logout: () async {
          operations.add('logout');
          return const AuthLogoutResult(cleanupPending: false);
        },
        clearWebView: () async => operations.add('clearWebView'),
        clearWebCache: () async => operations.add('clearWebCache'),
        resetUserState: () => operations.add('resetUserState'),
        refreshLoginStatus: (status) async {
          operations.add('refreshLoginStatus');
          refreshedStatus = status;
        },
        onCleanupPending: (msg) => toasts.add(msg),
      );

      final result = await coordinator.execute();

      expect(result.cleanupPending, isFalse);
      expect(refreshedStatus, isFalse);
      expect(toasts, isEmpty);
      expect(operations, <String>[
        'logout',
        'clearWebView',
        'clearWebCache',
        'resetUserState',
        'refreshLoginStatus',
      ]);
    });

    test(
      'webview and web cache errors do not prevent state reset or status refresh',
      () async {
        final operations = <String>[];
        bool? refreshedStatus;

        final coordinator = LogoutSessionCoordinator(
          logout: () async {
            operations.add('logout');
            return const AuthLogoutResult(cleanupPending: false);
          },
          clearWebView: () async {
            operations.add('clearWebView');
            throw Exception('webview error');
          },
          clearWebCache: () async {
            operations.add('clearWebCache');
            throw StateError('cache error');
          },
          resetUserState: () => operations.add('resetUserState'),
          refreshLoginStatus: (status) async {
            operations.add('refreshLoginStatus');
            refreshedStatus = status;
          },
        );

        final result = await coordinator.execute();

        expect(result.cleanupPending, isFalse);
        expect(refreshedStatus, isFalse);
        expect(operations, <String>[
          'logout',
          'clearWebView',
          'clearWebCache',
          'resetUserState',
          'refreshLoginStatus',
        ]);
      },
    );

    test('notifies user when cleanup is pending', () async {
      final toasts = <String>[];

      final coordinator = LogoutSessionCoordinator(
        logout: () async => const AuthLogoutResult(cleanupPending: true),
        clearWebView: () async {},
        clearWebCache: () async {},
        resetUserState: () {},
        refreshLoginStatus: (_) async {},
        onCleanupPending: (msg) => toasts.add(msg),
      );

      final result = await coordinator.execute();

      expect(result.cleanupPending, isTrue);
      expect(toasts, <String>['已退出登录，但本地安全凭据仍在等待清理。']);
    });
  });
}

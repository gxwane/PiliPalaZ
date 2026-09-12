import '../../http/constants.dart';
import 'auth_session_manager.dart';
import 'stored_session.dart';

final class LoginSessionCommitFailure implements Exception {
  const LoginSessionCommitFailure();

  @override
  String toString() => 'LoginSessionCommitFailure';
}

final class LogoutSessionCoordinator {
  const LogoutSessionCoordinator({
    required this.logout,
    required this.clearWebView,
    required this.clearWebCache,
    required this.resetUserState,
    required this.refreshLoginStatus,
    this.onCleanupPending,
  });

  final Future<AuthLogoutResult> Function() logout;
  final Future<void> Function() clearWebView;
  final Future<void> Function() clearWebCache;
  final void Function() resetUserState;
  final Future<void> Function(bool status) refreshLoginStatus;
  final void Function(String message)? onCleanupPending;

  Future<AuthLogoutResult> execute() async {
    final result = await logout();
    try {
      await clearWebView();
    } catch (_) {}
    try {
      await clearWebCache();
    } catch (_) {}
    resetUserState();
    await refreshLoginStatus(false);
    if (result.cleanupPending) {
      onCleanupPending?.call('已退出登录，但本地安全凭据仍在等待清理。');
    }
    return result;
  }
}

final class LoginSessionCommitter<T> {
  const LoginSessionCommitter({
    required this.saveSecurely,
    required this.replaceRuntime,
    required this.verifyAccount,
    required this.rollback,
  });

  final Future<void> Function(StoredSession session) saveSecurely;
  final Future<void> Function(StoredSession session) replaceRuntime;
  final Future<T?> Function() verifyAccount;
  final Future<void> Function() rollback;

  Future<T> commit(StoredSession candidate) async {
    try {
      await saveSecurely(candidate);
      await replaceRuntime(candidate);
      final verified = await verifyAccount();
      if (verified == null) {
        throw const LoginSessionCommitFailure();
      }
      return verified;
    } catch (_) {
      try {
        await rollback();
      } catch (_) {
        // A pending-cleanup marker keeps a failed secure deletion from being
        // restored on the next start.
      }
      throw const LoginSessionCommitFailure();
    }
  }
}

StoredSession parseLoginSession(
  Map<String, dynamic> tokenInfo,
  Object? cookieInfo,
) {
  if (cookieInfo is! Map || cookieInfo['cookies'] is! List) {
    throw const FormatException('Invalid login session payload.');
  }

  final cookies = <StoredCookie>[];
  for (final entry in cookieInfo['cookies'] as List) {
    if (entry is! Map) {
      throw const FormatException('Invalid login cookie payload.');
    }
    final name = entry['name'];
    final value = entry['value'];
    if (name is! String || name.isEmpty || value is! String || value.isEmpty) {
      throw const FormatException('Invalid login cookie payload.');
    }
    cookies.add(
      StoredCookie(
        origin: HttpString.apiBaseUrl,
        name: name,
        value: value,
        domain: 'bilibili.com',
        path: '/',
        expires: _parseExpiry(entry['expires']),
        secure: true,
        httpOnly: entry['http_only'] == true || entry['httpOnly'] == true,
      ),
    );
  }

  final session = StoredSession(
    schemaVersion: StoredSession.currentSchemaVersion,
    mid: _parseMid(tokenInfo['mid']),
    accessToken: _nonEmptyString(tokenInfo['access_token']),
    refreshToken: _nonEmptyString(tokenInfo['refresh_token']),
    cookies: List<StoredCookie>.unmodifiable(cookies),
  );
  if (!session.isAuthenticated) {
    throw const FormatException('Login session is not authenticated.');
  }
  return session;
}

DateTime? _parseExpiry(Object? value) {
  final seconds = switch (value) {
    int seconds => seconds,
    String text => int.tryParse(text),
    _ => null,
  };
  if (seconds == null || seconds <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

int? _parseMid(Object? value) {
  final mid = switch (value) {
    int mid => mid,
    String text => int.tryParse(text),
    _ => null,
  };
  return mid != null && mid > 0 ? mid : null;
}

String? _nonEmptyString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

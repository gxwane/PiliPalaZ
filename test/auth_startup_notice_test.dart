import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/auth_startup_notice.dart';
import 'package:pilipalaz/services/auth/auth_session_manager.dart';

void main() {
  test('only exceptional startup states have non-sensitive messages', () {
    expect(
      AuthStartupNotice.messageFor(AuthStartupState.authenticated),
      isNull,
    );
    expect(AuthStartupNotice.messageFor(AuthStartupState.anonymous), isNull);
    expect(
      AuthStartupNotice.messageFor(AuthStartupState.reauthRequired),
      '旧版登录信息无法安全迁移，已清除，请重新登录。',
    );
    expect(
      AuthStartupNotice.messageFor(
        AuthStartupState.storageTemporarilyUnavailable,
      ),
      '安全存储暂时不可用，本次将以未登录状态运行，请稍后重试。',
    );
  });

  testWidgets('notice is presented only once across rebuilds', (tester) async {
    final messages = <String>[];
    final result = AuthStartupResult(AuthStartupState.reauthRequired);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthStartupNotice(
          result: result,
          onNotice: (_, message) => messages.add(message),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStartupNotice(
          result: result,
          onNotice: (_, message) => messages.add(message),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(messages, <String>['旧版登录信息无法安全迁移，已清除，请重新登录。']);
  });

  testWidgets('normal startup never presents a notice', (tester) async {
    final messages = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStartupNotice(
          result: const AuthStartupResult(AuthStartupState.anonymous),
          onNotice: (_, message) => messages.add(message),
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(messages, isEmpty);
  });
}

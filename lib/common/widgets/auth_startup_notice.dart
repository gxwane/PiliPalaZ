import 'package:flutter/material.dart';

import '../../services/auth/auth_session_manager.dart';

final class AuthStartupNotice extends StatefulWidget {
  const AuthStartupNotice({
    required this.result,
    required this.child,
    this.onNotice,
    super.key,
  });

  final AuthStartupResult result;
  final Widget child;
  final void Function(BuildContext context, String message)? onNotice;

  static String? messageFor(AuthStartupState state) => switch (state) {
    AuthStartupState.reauthRequired => '旧版登录信息无法安全迁移，已清除，请重新登录。',
    AuthStartupState.storageTemporarilyUnavailable =>
      '安全存储暂时不可用，本次将以未登录状态运行，请稍后重试。',
    AuthStartupState.logoutCleanupPending => '上次退出登录的本地安全凭据仍在等待清理，请稍后重试。',
    AuthStartupState.authenticated || AuthStartupState.anonymous => null,
  };

  @override
  State<AuthStartupNotice> createState() => _AuthStartupNoticeState();
}

final class _AuthStartupNoticeState extends State<AuthStartupNotice> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown) {
      return;
    }
    final message = AuthStartupNotice.messageFor(widget.result.state);
    if (message == null) {
      return;
    }
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final presenter = widget.onNotice;
      if (presenter != null) {
        presenter(context, message);
        return;
      }
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

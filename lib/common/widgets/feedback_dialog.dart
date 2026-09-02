import 'package:flutter/material.dart';

import '../../services/feedback_coordinator.dart';

Future<void> showFeedbackDialog({
  required BuildContext context,
  FeedbackCoordinator coordinator = const FeedbackCoordinator(),
}) async {
  final kind = await showDialog<FeedbackKind>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('问题反馈'),
      children: [
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('报告问题'),
          subtitle: const Text('提交可复现的异常或故障'),
          onTap: () => Navigator.of(dialogContext).pop(FeedbackKind.bug),
        ),
        ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: const Text('功能建议'),
          subtitle: const Text('说明使用场景和期望方案'),
          onTap: () => Navigator.of(dialogContext).pop(FeedbackKind.feature),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ),
        ),
      ],
    ),
  );

  if (kind == null || !context.mounted) {
    return;
  }

  final result = await coordinator.open(kind);
  if (!context.mounted || result == FeedbackOpenResult.opened) {
    return;
  }

  final message = switch (result) {
    FeedbackOpenResult.opened => null,
    FeedbackOpenResult.copiedOnly => '无法打开浏览器，反馈地址已复制',
    FeedbackOpenResult.failed => '无法打开反馈入口',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message!)));
}

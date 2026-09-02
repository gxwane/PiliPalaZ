import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/constants.dart';

enum FeedbackKind { bug, feature }

enum FeedbackOpenResult { opened, copiedOnly, failed }

typedef FeedbackUriLauncher = Future<bool> Function(Uri uri);
typedef FeedbackClipboardWriter = Future<void> Function(String text);

class FeedbackCoordinator {
  const FeedbackCoordinator({
    FeedbackUriLauncher? launchExternal,
    FeedbackClipboardWriter? writeClipboard,
  }) : _launchExternal = launchExternal,
       _writeClipboard = writeClipboard;

  final FeedbackUriLauncher? _launchExternal;
  final FeedbackClipboardWriter? _writeClipboard;

  Uri uriFor(FeedbackKind kind) {
    final template = switch (kind) {
      FeedbackKind.bug => ProjectLinks.bugIssueTemplate,
      FeedbackKind.feature => ProjectLinks.featureIssueTemplate,
    };
    return Uri.parse(
      ProjectLinks.newIssue,
    ).replace(queryParameters: <String, String>{'template': template});
  }

  Future<FeedbackOpenResult> open(
    FeedbackKind kind, {
    String? diagnosticReport,
  }) async {
    final uri = uriFor(kind);
    if (diagnosticReport != null) {
      try {
        await _copy(diagnosticReport);
      } catch (_) {
        return FeedbackOpenResult.failed;
      }
    }

    try {
      if (await _launch(uri)) {
        return FeedbackOpenResult.opened;
      }
    } catch (_) {}

    if (diagnosticReport != null) {
      return FeedbackOpenResult.copiedOnly;
    }

    try {
      await _copy(uri.toString());
      return FeedbackOpenResult.copiedOnly;
    } catch (_) {
      return FeedbackOpenResult.failed;
    }
  }

  Future<bool> _launch(Uri uri) {
    final launcher = _launchExternal;
    if (launcher != null) {
      return launcher(uri);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copy(String text) {
    final writer = _writeClipboard;
    if (writer != null) {
      return writer(text);
    }
    return Clipboard.setData(ClipboardData(text: text));
  }
}

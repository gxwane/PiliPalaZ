import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:pilipalaz/models/github/latest.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pili_html_widget_factory.dart';

typedef ReleaseNotesLinkOpener = Future<void> Function(Uri uri);

class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({required this.release, this.openLink, super.key});

  final LatestDataModel release;
  final ReleaseNotesLinkOpener? openLink;

  @override
  Widget build(BuildContext context) {
    final html = releaseNotesHtml(release);
    if (html.isEmpty) {
      return const SizedBox.shrink();
    }
    return SelectionArea(
      child: HtmlWidget(
        html,
        factoryBuilder: SafeNetworkHtmlWidgetFactory.new,
        onTapUrl: (url) {
          final uri = resolveReleaseNotesUri(url, release.htmlUrl);
          if (uri != null) {
            unawaited((openLink ?? _openLinkExternally)(uri));
          }
          return true;
        },
      ),
    );
  }
}

String releaseNotesHtml(LatestDataModel release) {
  final bodyHtml = release.bodyHtml.trim();
  if (bodyHtml.isNotEmpty) {
    return bodyHtml;
  }
  final body = release.body.trim();
  if (body.isEmpty) {
    return '';
  }
  return markdown.markdownToHtml(
    body,
    extensionSet: markdown.ExtensionSet.gitHubWeb,
    encodeHtml: true,
    enableTagfilter: true,
  );
}

Uri? resolveReleaseNotesUri(String? value, String? releaseUrl) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  var uri = Uri.tryParse(value.trim());
  if (uri == null) {
    return null;
  }
  if (!uri.hasScheme) {
    final baseUri = Uri.tryParse(releaseUrl ?? '');
    if (baseUri == null || !_isWebUri(baseUri)) {
      return null;
    }
    uri = baseUri.resolveUri(uri);
  }
  return _isWebUri(uri) ? uri : null;
}

bool _isWebUri(Uri uri) {
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

Future<void> _openLinkExternally(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

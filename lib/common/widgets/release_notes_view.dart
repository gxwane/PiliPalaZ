import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:pilipalaz/models/github/latest.dart';
import 'package:url_launcher/url_launcher.dart';

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
      child: Html(
        data: html,
        onLinkTap: (url, attributes, element) {
          final uri = resolveReleaseNotesUri(url, release.htmlUrl);
          if (uri != null) {
            unawaited((openLink ?? _openLinkExternally)(uri));
          }
        },
        style: <String, Style>{
          'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
          'a': Style(
            color: Theme.of(context).colorScheme.primary,
            textDecoration: TextDecoration.none,
          ),
          'p': Style(margin: Margins.only(bottom: 8)),
          'li': Style(padding: HtmlPaddings.only(bottom: 4)),
          'li > p': Style(display: Display.inline),
          'h1,h2': Style(
            fontSize: FontSize.xLarge,
            fontWeight: FontWeight.bold,
            margin: Margins.only(top: 8, bottom: 8),
          ),
          'h3,h4,h5,h6': Style(
            fontSize: FontSize.large,
            fontWeight: FontWeight.bold,
            margin: Margins.only(top: 8, bottom: 4),
          ),
          'pre': Style(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            padding: HtmlPaddings.all(8),
          ),
          'blockquote': Style(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 4,
              ),
            ),
            margin: Margins.only(left: 4, top: 4, bottom: 4),
            padding: HtmlPaddings.only(left: 8),
          ),
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

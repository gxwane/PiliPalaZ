import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'network_img_layer.dart';

/// Restricts HTML images to remote web resources.
class SafeNetworkHtmlWidgetFactory extends WidgetFactory {
  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    return isSafeHtmlImageUrl(src.url)
        ? super.buildImageWidget(tree, src)
        : const SizedBox.shrink();
  }
}

/// Keeps article images on PiliPalaZ's existing cache and quality pipeline.
class PiliHtmlWidgetFactory extends SafeNetworkHtmlWidgetFactory {
  PiliHtmlWidgetFactory({
    required this.constrainedWidth,
    required this.textScale,
  });

  final double constrainedWidth;
  final double textScale;

  @override
  void parse(BuildTree tree) {
    if (tree.element.localName == 'img') {
      final attributes = tree.element.attributes;
      if (attributes['src']?.trim().isNotEmpty != true) {
        final dataSource = attributes['data-src']?.trim();
        if (dataSource?.isNotEmpty == true) {
          attributes['src'] = dataSource!;
        }
      }
    }
    super.parse(tree);
  }

  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    final imageUrl = normalizeHtmlImageUrl(src.url);
    if (imageUrl == null || imageUrl.contains('/mall/')) {
      return const SizedBox.shrink();
    }

    final isEmote = imageUrl.contains('/emote/');
    final effectiveTextScale = textScale > 0 ? textScale : 1.0;
    final semanticLabel = src.image?.alt ?? src.image?.title;
    return NetworkImgLayer(
      width: isEmote
          ? 22
          : math.max(0, (constrainedWidth - 23) / effectiveTextScale),
      height: isEmote ? 22 : 200,
      src: imageUrl,
      semanticsLabel: semanticLabel?.trim().isNotEmpty == true
          ? semanticLabel
          : null,
      ignoreHeight: !isEmote,
    );
  }
}

String? normalizeHtmlImageUrl(String source) {
  var value = source.trim();
  if (value.isEmpty) {
    return null;
  }
  value = value.split('@').first;
  if (value.startsWith('//')) {
    value = 'https:$value';
  }

  final uri = Uri.tryParse(value);
  if (uri == null || !_isWebUri(uri)) {
    return null;
  }
  return uri.scheme == 'http' ? uri.replace(scheme: 'https').toString() : value;
}

bool isSafeHtmlImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && _isWebUri(uri);
}

bool _isWebUri(Uri uri) {
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

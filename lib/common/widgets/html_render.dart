import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'pili_html_widget_factory.dart';

// ignore: must_be_immutable
class HtmlRender extends StatelessWidget {
  const HtmlRender({
    this.htmlContent,
    this.imgCount,
    this.imgList,
    required this.constrainedWidth,
    super.key,
  });

  final String? htmlContent;
  final int? imgCount;
  final List<String>? imgList;
  final double constrainedWidth;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: _buildHtmlWidget(
        context,
        renderMode: const ListViewMode(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
        ),
      ),
    );
  }

  HtmlWidget _buildHtmlWidget(
    BuildContext context, {
    required RenderMode renderMode,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return HtmlWidget(
      htmlContent ?? '',
      factoryBuilder: () => PiliHtmlWidgetFactory(
        constrainedWidth: constrainedWidth,
        textScale: textScale,
      ),
      onTapUrl: (_) => true,
      renderMode: renderMode,
    );
  }
}

class HtmlRenderSliver extends HtmlRender {
  const HtmlRenderSliver({
    super.htmlContent,
    super.imgCount,
    super.imgList,
    required super.constrainedWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _buildHtmlWidget(context, renderMode: RenderMode.sliverList);
  }
}

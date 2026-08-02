import 'package:flutter/widgets.dart';

const double _emptyLineWidthTolerance = 0.01;

class ReplyPreviewText extends StatelessWidget {
  const ReplyPreviewText({
    required this.message,
    required this.text,
    required this.style,
    required this.shouldCollapse,
    super.key,
  });

  final String message;
  final InlineSpan text;
  final TextStyle style;
  final bool shouldCollapse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int maxLines =
            shouldCollapse &&
                constraints.hasBoundedWidth &&
                constraints.maxWidth > 0
            ? resolveReplyPreviewMaxLines(
                message: message,
                style: style,
                maxWidth: constraints.maxWidth,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.maybeLocaleOf(context),
              )
            : shouldCollapse
            ? 6
            : 999;

        return Text.rich(
          text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

int resolveReplyPreviewMaxLines({
  required String message,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
  TextScaler textScaler = TextScaler.noScaling,
  Locale? locale,
  int maxLines = 6,
}) {
  assert(maxWidth > 0);
  assert(maxLines > 0);

  final TextPainter textPainter = TextPainter(
    text: TextSpan(text: message, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  )..layout(maxWidth: maxWidth);
  final List<LineMetrics> lineMetrics = textPainter.computeLineMetrics();
  textPainter.dispose();

  if (lineMetrics.length <= maxLines) {
    return maxLines;
  }

  int effectiveMaxLines = maxLines;
  while (effectiveMaxLines > 1 &&
      lineMetrics[effectiveMaxLines - 1].width <= _emptyLineWidthTolerance) {
    effectiveMaxLines--;
  }
  return effectiveMaxLines;
}

import 'package:flutter/widgets.dart';

const double _emptyLineWidthTolerance = 0.01;

@immutable
class ReplyPreviewLayout {
  const ReplyPreviewLayout({required this.maxLines, this.truncationOffset});

  final int maxLines;
  final int? truncationOffset;
}

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
        final ReplyPreviewLayout layout =
            shouldCollapse &&
                constraints.hasBoundedWidth &&
                constraints.maxWidth > 0
            ? resolveReplyPreviewLayout(
                message: message,
                style: style,
                maxWidth: constraints.maxWidth,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.maybeLocaleOf(context),
              )
            : shouldCollapse
            ? const ReplyPreviewLayout(maxLines: 6)
            : const ReplyPreviewLayout(maxLines: 999);

        final InlineSpan displayText = layout.truncationOffset == null
            ? text
            : _truncateInlineSpanWithEllipsis(
                text: text,
                message: message,
                messageOffset: layout.truncationOffset!,
              );

        return Text.rich(
          displayText,
          style: style,
          maxLines: layout.maxLines,
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
  return resolveReplyPreviewLayout(
    message: message,
    style: style,
    maxWidth: maxWidth,
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: maxLines,
  ).maxLines;
}

ReplyPreviewLayout resolveReplyPreviewLayout({
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

  if (lineMetrics.length <= maxLines) {
    textPainter.dispose();
    return ReplyPreviewLayout(maxLines: maxLines);
  }

  int effectiveMaxLines = maxLines;
  while (effectiveMaxLines > 1 &&
      lineMetrics[effectiveMaxLines - 1].width <= _emptyLineWidthTolerance) {
    effectiveMaxLines--;
  }

  if ((effectiveMaxLines == maxLines &&
          lineMetrics[maxLines].width > _emptyLineWidthTolerance) ||
      lineMetrics[effectiveMaxLines - 1].width <= _emptyLineWidthTolerance) {
    textPainter.dispose();
    return ReplyPreviewLayout(maxLines: effectiveMaxLines);
  }

  final LineMetrics lastVisibleLine = lineMetrics[effectiveMaxLines - 1];
  final TextPosition linePosition = textPainter.getPositionForOffset(
    Offset(
      lastVisibleLine.left + lastVisibleLine.width / 2,
      lastVisibleLine.baseline - lastVisibleLine.ascent / 2,
    ),
  );
  final TextRange lineRange = textPainter.getLineBoundary(linePosition);
  textPainter.dispose();

  int truncationOffset = lineRange.end;
  while (truncationOffset > lineRange.start &&
      _isLineBreak(message.codeUnitAt(truncationOffset - 1))) {
    truncationOffset--;
  }
  final int? fittedOffset = _fitEllipsisOnLastLine(
    message: message,
    style: style,
    maxWidth: maxWidth,
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: effectiveMaxLines,
    minimumOffset: lineRange.start,
    initialOffset: truncationOffset,
  );

  return ReplyPreviewLayout(
    maxLines: effectiveMaxLines,
    truncationOffset: fittedOffset,
  );
}

bool _isLineBreak(int codeUnit) => codeUnit == 0x0A || codeUnit == 0x0D;

int? _fitEllipsisOnLastLine({
  required String message,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
  required int maxLines,
  required int minimumOffset,
  required int initialOffset,
}) {
  int offset = initialOffset;
  while (offset >= minimumOffset) {
    final TextPainter candidatePainter = TextPainter(
      text: TextSpan(text: '${message.substring(0, offset)}…', style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
    )..layout(maxWidth: maxWidth);
    final bool fits = candidatePainter.computeLineMetrics().length <= maxLines;
    candidatePainter.dispose();
    if (fits) {
      return offset;
    }
    if (offset == minimumOffset) {
      break;
    }
    offset = _previousCodePointOffset(message, offset);
  }
  return null;
}

int _previousCodePointOffset(String value, int offset) {
  int previousOffset = offset - 1;
  if (previousOffset > 0 &&
      _isLowSurrogate(value.codeUnitAt(previousOffset)) &&
      _isHighSurrogate(value.codeUnitAt(previousOffset - 1))) {
    previousOffset--;
  }
  return previousOffset;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

InlineSpan _truncateInlineSpanWithEllipsis({
  required InlineSpan text,
  required String message,
  required int messageOffset,
}) {
  final String plainText = text.toPlainText(includeSemanticsLabels: false);
  final String visiblePrefix = message.substring(0, messageOffset);
  final int messageStart = plainText.indexOf(visiblePrefix);
  if (messageStart < 0) {
    return text;
  }

  final (InlineSpan? span, _) = _takeInlineSpan(
    text,
    messageStart + visiblePrefix.length,
  );
  if (span == null) {
    return text;
  }
  return TextSpan(
    children: <InlineSpan>[
      span,
      const TextSpan(text: '…'),
    ],
  );
}

(InlineSpan?, int) _takeInlineSpan(InlineSpan span, int maxLength) {
  if (maxLength <= 0) {
    return (null, 0);
  }

  final int fullLength = span.toPlainText(includeSemanticsLabels: false).length;
  if (fullLength <= maxLength) {
    return (span, fullLength);
  }
  if (span is! TextSpan) {
    return (null, 0);
  }

  int remaining = maxLength;
  int consumed = 0;
  String? slicedText;
  if (span.text case final String value) {
    final int takeLength = value.length < remaining ? value.length : remaining;
    slicedText = value.substring(0, takeLength);
    remaining -= takeLength;
    consumed += takeLength;
  }

  final List<InlineSpan> slicedChildren = <InlineSpan>[];
  for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
    if (remaining <= 0) {
      break;
    }
    final (InlineSpan? slicedChild, int childLength) = _takeInlineSpan(
      child,
      remaining,
    );
    if (slicedChild != null) {
      slicedChildren.add(slicedChild);
    }
    remaining -= childLength;
    consumed += childLength;
  }

  if (consumed == 0) {
    return (null, 0);
  }
  return (
    TextSpan(
      text: slicedText,
      children: slicedChildren.isEmpty ? null : slicedChildren,
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      semanticsIdentifier: span.semanticsIdentifier,
      locale: span.locale,
      spellOut: span.spellOut,
    ),
    consumed,
  );
}

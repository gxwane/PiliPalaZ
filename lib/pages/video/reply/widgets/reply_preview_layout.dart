import 'package:characters/characters.dart' as character;
import 'package:flutter/widgets.dart';

const double _emptyLineWidthTolerance = 0.01;

@immutable
class ReplyPreviewLayout {
  const ReplyPreviewLayout({
    required this.text,
    required this.maxLines,
    required this.isTruncated,
  });

  final InlineSpan text;
  final int? maxLines;
  final bool isTruncated;
}

class ReplyPreviewWidgetSpan extends WidgetSpan {
  factory ReplyPreviewWidgetSpan({
    required Widget child,
    required Size size,
    PlaceholderAlignment alignment = PlaceholderAlignment.bottom,
    TextBaseline? baseline,
    double? baselineOffset,
  }) {
    return ReplyPreviewWidgetSpan._(
      child: SizedBox(width: size.width, height: size.height, child: child),
      dimensions: PlaceholderDimensions(
        size: size,
        alignment: alignment,
        baseline: baseline,
        baselineOffset: baselineOffset,
      ),
      alignment: alignment,
      baseline: baseline,
    );
  }

  const ReplyPreviewWidgetSpan._({
    required super.child,
    required this.dimensions,
    super.alignment,
    super.baseline,
  });

  final PlaceholderDimensions dimensions;
}

class ReplyPreviewText extends StatelessWidget {
  const ReplyPreviewText({
    required this.text,
    required this.style,
    required this.shouldCollapse,
    super.key,
  });

  final InlineSpan text;
  final TextStyle style;
  final bool shouldCollapse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!shouldCollapse) {
          return Text.rich(text, style: style);
        }

        if (constraints.maxWidth <= 0) {
          return Text.rich(
            text,
            style: style,
            maxLines: 6,
            overflow: TextOverflow.clip,
          );
        }

        final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
          text: text,
          style: style,
          maxWidth: constraints.hasBoundedWidth
              ? constraints.maxWidth
              : double.infinity,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        );

        return Text.rich(
          layout.text,
          style: style,
          maxLines: layout.maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

ReplyPreviewLayout resolveReplyPreviewLayout({
  required InlineSpan text,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
  TextScaler textScaler = TextScaler.noScaling,
  Locale? locale,
  int maxLines = 6,
}) {
  assert(maxWidth > 0);
  assert(maxLines > 0);

  final _PlaceholderCollection placeholders = _collectPlaceholders(text);
  assert(
    placeholders.isSupported,
    'Collapsible reply previews require ReplyPreviewWidgetSpan for every '
    'inline widget.',
  );
  if (!placeholders.isSupported) {
    return ReplyPreviewLayout(text: text, maxLines: null, isTruncated: false);
  }

  final TextPainter textPainter = _createTextPainter(
    text: text,
    style: style,
    placeholderDimensions: placeholders.dimensions,
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  )..layout(maxWidth: maxWidth);
  final List<LineMetrics> lineMetrics = textPainter.computeLineMetrics();

  if (lineMetrics.length <= maxLines) {
    textPainter.dispose();
    return ReplyPreviewLayout(
      text: text,
      maxLines: maxLines,
      isTruncated: false,
    );
  }

  int effectiveMaxLines = maxLines;
  while (effectiveMaxLines > 1 &&
      lineMetrics[effectiveMaxLines - 1].width <= _emptyLineWidthTolerance) {
    effectiveMaxLines--;
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

  final String plainText = text.toPlainText(
    includeSemanticsLabels: false,
    includePlaceholders: true,
  );
  int initialOffset = lineRange.end;
  while (initialOffset > lineRange.start &&
      _isLineBreak(plainText.codeUnitAt(initialOffset - 1))) {
    initialOffset--;
  }

  final InlineSpan displayText = _fitInlineSpanWithEllipsis(
    text: text,
    plainText: plainText,
    style: style,
    maxWidth: maxWidth,
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: effectiveMaxLines,
    minimumOffset: lineRange.start,
    initialOffset: initialOffset,
  );

  return ReplyPreviewLayout(
    text: displayText,
    maxLines: effectiveMaxLines,
    isTruncated: true,
  );
}

bool _isLineBreak(int codeUnit) => codeUnit == 0x0A || codeUnit == 0x0D;

InlineSpan _fitInlineSpanWithEllipsis({
  required InlineSpan text,
  required String plainText,
  required TextStyle style,
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
  required int maxLines,
  required int minimumOffset,
  required int initialOffset,
}) {
  for (final int offset in _graphemeOffsetsDescending(
    plainText,
    minimumOffset,
    initialOffset,
  )) {
    final (InlineSpan? visibleText, _) = _takeInlineSpan(text, offset);
    final InlineSpan candidate = TextSpan(
      children: <InlineSpan>[
        ?visibleText,
        const TextSpan(text: '…'),
      ],
    );
    final _PlaceholderCollection placeholders = _collectPlaceholders(candidate);
    final TextPainter candidatePainter = _createTextPainter(
      text: candidate,
      style: style,
      placeholderDimensions: placeholders.dimensions,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
    )..layout(maxWidth: maxWidth);
    final bool fits = candidatePainter.computeLineMetrics().length <= maxLines;
    candidatePainter.dispose();
    if (fits) {
      return candidate;
    }
  }

  return const TextSpan(text: '…');
}

Iterable<int> _graphemeOffsetsDescending(
  String value,
  int minimumOffset,
  int initialOffset,
) sync* {
  final List<int> offsets = <int>[minimumOffset];
  int offset = minimumOffset;
  for (final String grapheme in character.Characters(
    value.substring(minimumOffset, initialOffset),
  )) {
    offset += grapheme.length;
    offsets.add(offset);
  }
  for (final int candidate in offsets.reversed) {
    yield candidate;
  }
}

TextPainter _createTextPainter({
  required InlineSpan text,
  required TextStyle style,
  required List<PlaceholderDimensions> placeholderDimensions,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
}) {
  final TextPainter painter = TextPainter(
    text: TextSpan(style: style, children: <InlineSpan>[text]),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  );
  painter.setPlaceholderDimensions(placeholderDimensions);
  return painter;
}

_PlaceholderCollection _collectPlaceholders(InlineSpan span) {
  final List<PlaceholderDimensions> dimensions = <PlaceholderDimensions>[];
  bool isSupported = true;

  void visit(InlineSpan current) {
    if (current is ReplyPreviewWidgetSpan) {
      dimensions.add(current.dimensions);
      return;
    }
    if (current is PlaceholderSpan) {
      isSupported = false;
      return;
    }
    if (current is TextSpan) {
      for (final InlineSpan child in current.children ?? const <InlineSpan>[]) {
        visit(child);
      }
      return;
    }
    isSupported = false;
  }

  visit(span);
  return _PlaceholderCollection(
    dimensions: dimensions,
    isSupported: isSupported,
  );
}

@immutable
class _PlaceholderCollection {
  const _PlaceholderCollection({
    required this.dimensions,
    required this.isSupported,
  });

  final List<PlaceholderDimensions> dimensions;
  final bool isSupported;
}

(InlineSpan?, int) _takeInlineSpan(InlineSpan span, int maxLength) {
  if (maxLength <= 0) {
    return (null, 0);
  }

  final int fullLength = span
      .toPlainText(includeSemanticsLabels: false, includePlaceholders: true)
      .length;
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

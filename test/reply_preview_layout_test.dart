import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/reply/widgets/reply_preview_layout.dart';

void main() {
  const TextStyle style = TextStyle(fontSize: 14, height: 1.75);
  const String reportedComment =
      '1. low hanging fruit\n'
      '2. 人类技术的凸包罢了\n'
      '3. 只会做构造举反例\n'
      '4. 反例数学界已经想的差不多了，ai就是给出了个close\n'
      '\n'
      '有其它想法请补充[doge]';

  group('resolveReplyPreviewMaxLines', () {
    test('handles the reported mixed-language comment', () {
      final int maxLines = resolveReplyPreviewMaxLines(
        message: reportedComment,
        style: style,
        maxWidth: 280,
        textDirection: TextDirection.ltr,
      );

      expect(maxLines, 5);
    });

    test('moves the ellipsis before a blank truncation line', () {
      final int maxLines = resolveReplyPreviewMaxLines(
        message: 'one\ntwo\nthree\nfour\nfive\n\nhidden',
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(maxLines, 5);
    });

    test('keeps six lines when the truncation line contains text', () {
      final int maxLines = resolveReplyPreviewMaxLines(
        message: 'one\ntwo\nthree\nfour\nfive\nsix\nhidden',
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(maxLines, 6);
    });

    test('keeps six lines when a blank line is not the truncation line', () {
      final int maxLines = resolveReplyPreviewMaxLines(
        message: 'one\n\ntwo\nthree\nfour\nfive',
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(maxLines, 6);
    });

    test('keeps six lines for short comments', () {
      final int maxLines = resolveReplyPreviewMaxLines(
        message: 'one\ntwo',
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(maxLines, 6);
    });

    test('reserves enough width for the literal ellipsis', () {
      const String message = 'a\na\na\na\nfifth\n\nhidden';
      final TextPainter linePainter = TextPainter(
        text: const TextSpan(text: 'fifth', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final double maxWidth = linePainter.width;
      linePainter.dispose();

      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        message: message,
        style: style,
        maxWidth: maxWidth,
        textDirection: TextDirection.ltr,
        maxLines: 6,
      );

      expect(layout.maxLines, 5);
      expect(layout.truncationOffset, isNotNull);
      expect(layout.truncationOffset, lessThan(message.indexOf('\n\n')));

      final TextPainter previewPainter = TextPainter(
        text: TextSpan(
          text: '${message.substring(0, layout.truncationOffset!)}…',
          style: style,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      expect(previewPainter.computeLineMetrics(), hasLength(5));
      previewPainter.dispose();
    });
  });

  testWidgets('renders a literal ellipsis before a blank truncation line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 280,
            child: ReplyPreviewText(
              message: reportedComment,
              text: TextSpan(text: reportedComment),
              style: style,
              shouldCollapse: true,
            ),
          ),
        ),
      ),
    );

    final Text text = tester.widget<Text>(
      find.descendant(
        of: find.byType(ReplyPreviewText),
        matching: find.byType(Text),
      ),
    );
    expect(text.maxLines, 5);
    expect(text.overflow, TextOverflow.ellipsis);

    final RichText richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(ReplyPreviewText),
        matching: find.byType(RichText),
      ),
    );
    final String renderedText = richText.text.toPlainText();
    expect(renderedText, endsWith('close…'));
    expect(renderedText, isNot(contains('有其它想法请补充')));
  });

  testWidgets('keeps the native overflow path for a non-empty boundary', (
    WidgetTester tester,
  ) async {
    const String message = 'one\ntwo\nthree\nfour\nfive\nsix\nhidden';
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1000,
            child: ReplyPreviewText(
              message: message,
              text: TextSpan(text: message),
              style: style,
              shouldCollapse: true,
            ),
          ),
        ),
      ),
    );

    final RichText richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(ReplyPreviewText),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.text.toPlainText(), message);
  });

  testWidgets('preserves rich text spans before the explicit ellipsis', (
    WidgetTester tester,
  ) async {
    const String visibleMessage = 'one\ntwo\nthree\nfour\nfive';
    const String message = '$visibleMessage\n\nhidden';
    const TextStyle emphasizedStyle = TextStyle(fontWeight: FontWeight.bold);
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1000,
            child: ReplyPreviewText(
              message: message,
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: visibleMessage, style: emphasizedStyle),
                  TextSpan(text: '\n\nhidden'),
                ],
              ),
              style: style,
              shouldCollapse: true,
            ),
          ),
        ),
      ),
    );

    final RichText richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(ReplyPreviewText),
        matching: find.byType(RichText),
      ),
    );
    final TextSpan displayRoot = richText.text as TextSpan;
    expect(_containsTextStyle(displayRoot, emphasizedStyle), isTrue);
    expect(richText.text.toPlainText(), '$visibleMessage…');
  });

  testWidgets('truncates when the hidden suffix contains a widget span', (
    WidgetTester tester,
  ) async {
    const String messageBeforeEmote =
        '1. low hanging fruit\n'
        '2. 人类技术的凸包罢了\n'
        '3. 只会做构造举反例\n'
        '4. 反例数学界已经想的差不多了，ai就是给出了个close\n'
        '\n'
        '有其它想法请补充';
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 280,
            child: ReplyPreviewText(
              message: reportedComment,
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: messageBeforeEmote),
                  WidgetSpan(child: SizedBox(width: 20, height: 20)),
                ],
              ),
              style: style,
              shouldCollapse: true,
            ),
          ),
        ),
      ),
    );

    final RichText richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(ReplyPreviewText),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.text.toPlainText(), endsWith('close…'));
    expect(richText.text.toPlainText(), isNot(contains('\uFFFC')));
  });
}

bool _containsTextStyle(InlineSpan span, TextStyle style) {
  if (span is! TextSpan) {
    return false;
  }
  if (span.style == style) {
    return true;
  }
  return span.children?.any(
        (InlineSpan child) => _containsTextStyle(child, style),
      ) ??
      false;
}

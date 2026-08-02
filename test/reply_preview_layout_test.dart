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
  });

  testWidgets('renders the reported comment with a five-line ellipsis', (
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
  });
}

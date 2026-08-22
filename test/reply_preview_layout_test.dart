import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  setUpAll(() async {
    final FontLoader loader = FontLoader('Jura-Bold')
      ..addFont(rootBundle.load('assets/fonts/Jura-Bold.ttf'));
    await loader.load();
  });

  group('resolveReplyPreviewLayout', () {
    test('handles the reported mixed-language comment', () {
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: const TextSpan(text: reportedComment),
        style: style,
        maxWidth: 280,
        textDirection: TextDirection.ltr,
      );

      expect(layout.maxLines, 5);
      expect(layout.isTruncated, isTrue);
      expect(layout.text.toPlainText(), endsWith('close…'));
      expect(layout.text.toPlainText(), isNot(contains('有其它想法请补充')));
    });

    test('moves the ellipsis before a blank visible boundary line', () {
      const String message = 'one\ntwo\nthree\nfour\nfive\n\nhidden';
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: const TextSpan(text: message),
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(layout.maxLines, 5);
      expect(layout.text.toPlainText(), 'one\ntwo\nthree\nfour\nfive…');
    });

    test('backs up across consecutive blank visible boundary lines', () {
      const String message = 'one\ntwo\nthree\nfour\n\n\nhidden';
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: const TextSpan(text: message),
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(layout.maxLines, 4);
      expect(layout.text.toPlainText(), 'one\ntwo\nthree\nfour…');
    });

    test('adds the ellipsis when the first hidden line is empty', () {
      const String message = 'one\ntwo\nthree\nfour\nfive\nsix\n\nhidden';
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: const TextSpan(text: message),
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(layout.maxLines, 6);
      expect(layout.text.toPlainText(), 'one\ntwo\nthree\nfour\nfive\nsix…');
    });

    test('uses the explicit ellipsis for a non-empty boundary', () {
      const String message = 'one\ntwo\nthree\nfour\nfive\nsix\nhidden';
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: const TextSpan(text: message),
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(layout.maxLines, 6);
      expect(layout.text.toPlainText(), 'one\ntwo\nthree\nfour\nfive\nsix…');
    });

    test('truncates ordinary auto-wrapped text without spaces', () {
      final String message = List<String>.filled(
        8,
        '这是一段没有空格的普通评论用于验证自动换行省略号',
      ).join();
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: TextSpan(text: message),
        style: style,
        maxWidth: 180,
        textDirection: TextDirection.ltr,
        maxLines: 3,
      );

      expect(layout.maxLines, 3);
      expect(layout.isTruncated, isTrue);
      expect(layout.text.toPlainText(), endsWith('…'));
    });

    test('keeps short comments unchanged', () {
      const TextSpan text = TextSpan(text: 'one\ntwo');
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: text,
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.ltr,
      );

      expect(layout.maxLines, 6);
      expect(layout.isTruncated, isFalse);
      expect(layout.text, same(text));
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
        text: const TextSpan(text: message),
        style: style,
        maxWidth: maxWidth,
        textDirection: TextDirection.ltr,
      );

      expect(layout.maxLines, 5);
      expect(layout.text.toPlainText(), endsWith('…'));
      expect(layout.text.toPlainText(), isNot(contains('hidden')));

      final TextPainter previewPainter = TextPainter(
        text: TextSpan(style: style, children: <InlineSpan>[layout.text]),
        textDirection: TextDirection.ltr,
        maxLines: layout.maxLines,
      )..layout(maxWidth: maxWidth);
      expect(previewPainter.didExceedMaxLines, isFalse);
      previewPainter.dispose();
    });

    test('does not split an extended grapheme to fit the ellipsis', () {
      const String family = '👨‍👩‍👧‍👦';
      const String lastVisibleLine = 'family $family';
      const String message =
          'one\ntwo\nthree\nfour\nfive\n$lastVisibleLine\nhidden';
      final TextPainter linePainter = TextPainter(
        text: const TextSpan(text: lastVisibleLine, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final double maxWidth = linePainter.width;
      linePainter.dispose();

      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: const TextSpan(text: message),
        style: style,
        maxWidth: maxWidth,
        textDirection: TextDirection.ltr,
      );

      final String rendered = layout.text.toPlainText();
      expect(rendered, endsWith('…'));
      expect(rendered, isNot(contains(family)));
      expect(rendered, isNot(contains('\u200D')));
    });

    test('supports RTL layout and scaled text', () {
      const String message = 'واحد\nاثنان\nثلاثة\nأربعة\nخمسة\nستة\n\nمخفي';
      final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
        text: const TextSpan(text: message),
        style: style,
        maxWidth: 1000,
        textDirection: TextDirection.rtl,
        textScaler: const TextScaler.linear(1.5),
      );

      expect(layout.maxLines, 6);
      expect(layout.text.toPlainText(), endsWith('ستة…'));
      expect(layout.text.toPlainText(), isNot(contains('مخفي')));
    });

    test('rejects unmeasured widget spans in collapsible content', () {
      expect(
        () => resolveReplyPreviewLayout(
          text: const TextSpan(
            children: <InlineSpan>[
              WidgetSpan(child: SizedBox(width: 20, height: 20)),
              TextSpan(text: '\none\ntwo\nthree\nfour\nfive\nsix\nhidden'),
            ],
          ),
          style: style,
          maxWidth: 1000,
          textDirection: TextDirection.ltr,
        ),
        throwsAssertionError,
      );
    });
  });

  testWidgets('renders the reported comment without painter overflow', (
    WidgetTester tester,
  ) async {
    await _pumpPreview(
      tester,
      width: 280,
      text: const TextSpan(text: reportedComment),
    );

    final RichText richText = tester.widget<RichText>(_richTextFinder);
    expect(richText.maxLines, 5);
    expect(richText.overflow, TextOverflow.ellipsis);
    expect(richText.text.toPlainText(), endsWith('close…'));
    expect(richText.text.toPlainText(), isNot(contains('有其它想法请补充')));
    expect(_renderParagraph(tester).didExceedMaxLines, isFalse);
  });

  testWidgets(
    'renders a fitted ellipsis when a visible emote precedes a hidden blank line',
    (WidgetTester tester) async {
      await _pumpPreview(
        tester,
        width: 1000,
        text: TextSpan(
          children: <InlineSpan>[
            const TextSpan(text: 'one\n'),
            ReplyPreviewWidgetSpan(
              size: const Size.square(20),
              child: const ColoredBox(color: Colors.red),
            ),
            const TextSpan(text: ' two\nthree\nfour\nfive\nsix\n\nhidden'),
          ],
        ),
      );

      final RichText richText = tester.widget<RichText>(_richTextFinder);
      expect(richText.text.toPlainText(), endsWith('six…'));
      expect(richText.text.toPlainText(), isNot(contains('hidden')));
      expect(_containsSpanType<ReplyPreviewWidgetSpan>(richText.text), isTrue);
      expect(_renderParagraph(tester).didExceedMaxLines, isFalse);
    },
  );

  testWidgets(
    'keeps measured TOP, emote, and link placeholders before the ellipsis',
    (WidgetTester tester) async {
      await _pumpPreview(
        tester,
        width: 1000,
        text: TextSpan(
          children: <InlineSpan>[
            ReplyPreviewWidgetSpan(
              size: const Size(24, 13),
              alignment: PlaceholderAlignment.middle,
              child: const ColoredBox(color: Colors.blue),
            ),
            const TextSpan(text: ' one\n'),
            ReplyPreviewWidgetSpan(
              size: const Size.square(20),
              child: const ColoredBox(color: Colors.red),
            ),
            const TextSpan(text: ' two\n'),
            ReplyPreviewWidgetSpan(
              size: const Size.square(19),
              child: const ColoredBox(color: Colors.green),
            ),
            const TextSpan(text: ' three\nfour\nfive\nsix\n\nhidden'),
          ],
        ),
      );

      final RichText richText = tester.widget<RichText>(_richTextFinder);
      expect(_countSpanType<ReplyPreviewWidgetSpan>(richText.text), 3);
      expect(richText.text.toPlainText(), endsWith('six…'));
      expect(richText.text.toPlainText(), isNot(contains('hidden')));
      expect(_renderParagraph(tester).didExceedMaxLines, isFalse);
    },
  );

  testWidgets(
    'preserves rich text styles and recognizers before the ellipsis',
    (WidgetTester tester) async {
      const TextStyle emphasizedStyle = TextStyle(fontWeight: FontWeight.bold);
      final TapGestureRecognizer recognizer = TapGestureRecognizer();
      addTearDown(recognizer.dispose);

      await _pumpPreview(
        tester,
        width: 1000,
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: 'one\ntwo\nthree\nfour\nfive\nsix',
              style: emphasizedStyle,
              recognizer: recognizer,
            ),
            const TextSpan(text: '\n\nhidden'),
          ],
        ),
      );

      final RichText richText = tester.widget<RichText>(_richTextFinder);
      expect(_containsTextStyle(richText.text, emphasizedStyle), isTrue);
      expect(_containsRecognizer(richText.text, recognizer), isTrue);
      expect(richText.text.toPlainText(), endsWith('six…'));
      expect(_renderParagraph(tester).didExceedMaxLines, isFalse);
    },
  );

  testWidgets('truncates when the hidden suffix contains a measured widget', (
    WidgetTester tester,
  ) async {
    const String messageBeforeEmote =
        '1. low hanging fruit\n'
        '2. 人类技术的凸包罢了\n'
        '3. 只会做构造举反例\n'
        '4. 反例数学界已经想的差不多了，ai就是给出了个close\n'
        '\n'
        '有其它想法请补充';
    await _pumpPreview(
      tester,
      width: 280,
      text: TextSpan(
        children: <InlineSpan>[
          const TextSpan(text: messageBeforeEmote),
          ReplyPreviewWidgetSpan(
            size: const Size.square(20),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );

    final RichText richText = tester.widget<RichText>(_richTextFinder);
    expect(richText.text.toPlainText(), endsWith('close…'));
    expect(richText.text.toPlainText(), isNot(contains('\uFFFC')));
    expect(_renderParagraph(tester).didExceedMaxLines, isFalse);
  });

  testWidgets('does not truncate when collapsing is disabled', (
    WidgetTester tester,
  ) async {
    const String message = 'one\ntwo\nthree\nfour\nfive\nsix\n\nhidden';
    await _pumpPreview(
      tester,
      width: 1000,
      text: const TextSpan(text: message),
      shouldCollapse: false,
    );

    final RichText richText = tester.widget<RichText>(_richTextFinder);
    expect(richText.maxLines, isNull);
    expect(richText.text.toPlainText(), message);
    expect(_renderParagraph(tester).didExceedMaxLines, isFalse);
  });

  testWidgets(
    'paints the renderer ellipsis fallback when inherited rich text wraps differently',
    (WidgetTester tester) async {
      const double width = 160;
      const TextStyle previewStyle = TextStyle(
        fontFamily: 'Jura-Bold',
        fontSize: 14,
        height: 1,
      );
      const TextSpan text = TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),
        ],
      );
      final ReplyPreviewLayout predictedLayout = resolveReplyPreviewLayout(
        text: text,
        style: previewStyle,
        maxWidth: width,
        textDirection: TextDirection.ltr,
      );
      expect(predictedLayout.isTruncated, isFalse);
      expect(predictedLayout.text, same(text));

      const Key productionKey = ValueKey<String>('production-preview');
      const Key clipControlKey = ValueKey<String>('clip-control-preview');
      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultTextStyle(
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Jura-Bold',
              fontSize: 14,
              height: 1,
              letterSpacing: 14,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  RepaintBoundary(
                    key: productionKey,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SizedBox(
                        width: width,
                        child: ReplyPreviewText(
                          text: text,
                          style: previewStyle,
                          shouldCollapse: true,
                        ),
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    key: clipControlKey,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SizedBox(
                        width: width,
                        child: _ClipReplyPreviewText(
                          text: text,
                          style: previewStyle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final Finder productionText = find.descendant(
        of: find.byKey(productionKey),
        matching: find.byType(RichText),
      );
      final Finder clipControlText = find.descendant(
        of: find.byKey(clipControlKey),
        matching: find.byType(RichText),
      );
      final RenderParagraph productionParagraph = tester
          .renderObject<RenderParagraph>(productionText);
      final RenderParagraph clipControlParagraph = tester
          .renderObject<RenderParagraph>(clipControlText);
      expect(productionParagraph.didExceedMaxLines, isTrue);
      expect(clipControlParagraph.didExceedMaxLines, isTrue);

      final _CapturedImage productionImage = await _captureImage(
        tester,
        productionKey,
      );
      final _CapturedImage clipControlImage = await _captureImage(
        tester,
        clipControlKey,
      );
      expect(productionImage.width, clipControlImage.width);
      expect(productionImage.height, clipControlImage.height);
      expect(_countNonWhitePixels(productionImage), greaterThan(0));
      expect(_countNonWhitePixels(clipControlImage), greaterThan(0));

      final int lastLineStart = productionImage.height * 5 ~/ 6;
      expect(
        _countDifferentPixels(
          productionImage,
          clipControlImage,
          endRow: lastLineStart,
        ),
        0,
      );
      expect(
        _countDifferentPixels(
          productionImage,
          clipControlImage,
          startRow: lastLineStart,
        ),
        greaterThan(0),
      );
    },
  );
}

Finder get _richTextFinder => find.descendant(
  of: find.byType(ReplyPreviewText),
  matching: find.byType(RichText),
);

RenderParagraph _renderParagraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(_richTextFinder);

Future<void> _pumpPreview(
  WidgetTester tester, {
  required double width,
  required InlineSpan text,
  bool shouldCollapse = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: width,
          child: ReplyPreviewText(
            text: text,
            style: const TextStyle(fontSize: 14, height: 1.75),
            shouldCollapse: shouldCollapse,
          ),
        ),
      ),
    ),
  );
}

class _ClipReplyPreviewText extends StatelessWidget {
  const _ClipReplyPreviewText({required this.text, required this.style});

  final InlineSpan text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ReplyPreviewLayout layout = resolveReplyPreviewLayout(
          text: text,
          style: style,
          maxWidth: constraints.maxWidth,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        );
        return Text.rich(
          layout.text,
          style: style,
          maxLines: layout.maxLines,
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}

class _CapturedImage {
  const _CapturedImage({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;
  final Uint8List pixels;
}

Future<_CapturedImage> _captureImage(WidgetTester tester, Key key) async {
  final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(key));
  return (await tester.runAsync<_CapturedImage>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final _CapturedImage captured = _CapturedImage(
      width: image.width,
      height: image.height,
      pixels: Uint8List.fromList(byteData!.buffer.asUint8List()),
    );
    image.dispose();
    return captured;
  }))!;
}

int _countDifferentPixels(
  _CapturedImage first,
  _CapturedImage second, {
  int startRow = 0,
  int? endRow,
}) {
  assert(first.width == second.width);
  assert(first.height == second.height);
  final int lastRow = endRow ?? first.height;
  int count = 0;
  for (int y = startRow; y < lastRow; y++) {
    for (int x = 0; x < first.width; x++) {
      final int offset = (y * first.width + x) * 4;
      if (first.pixels[offset] != second.pixels[offset] ||
          first.pixels[offset + 1] != second.pixels[offset + 1] ||
          first.pixels[offset + 2] != second.pixels[offset + 2] ||
          first.pixels[offset + 3] != second.pixels[offset + 3]) {
        count++;
      }
    }
  }
  return count;
}

int _countNonWhitePixels(_CapturedImage image) {
  int count = 0;
  for (int offset = 0; offset < image.pixels.length; offset += 4) {
    if (image.pixels[offset] != 0xFF ||
        image.pixels[offset + 1] != 0xFF ||
        image.pixels[offset + 2] != 0xFF ||
        image.pixels[offset + 3] != 0xFF) {
      count++;
    }
  }
  return count;
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

bool _containsRecognizer(InlineSpan span, GestureRecognizer recognizer) {
  if (span is! TextSpan) {
    return false;
  }
  if (identical(span.recognizer, recognizer)) {
    return true;
  }
  return span.children?.any(
        (InlineSpan child) => _containsRecognizer(child, recognizer),
      ) ??
      false;
}

bool _containsSpanType<T extends InlineSpan>(InlineSpan span) {
  if (span is T) {
    return true;
  }
  return span is TextSpan &&
      (span.children?.any(_containsSpanType<T>) ?? false);
}

int _countSpanType<T extends InlineSpan>(InlineSpan span) {
  final int current = span is T ? 1 : 0;
  if (span is! TextSpan) {
    return current;
  }
  return current +
      (span.children?.fold<int>(
            0,
            (int count, InlineSpan child) => count + _countSpanType<T>(child),
          ) ??
          0);
}

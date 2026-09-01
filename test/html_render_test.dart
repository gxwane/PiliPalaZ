import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:pilipalaz/common/widgets/html_render.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/common/widgets/pili_html_widget_factory.dart';

import 'support/html_render_fixtures.dart';

void main() {
  group('normalizeHtmlImageUrl', () {
    test('upgrades Bilibili image URLs and removes processing suffixes', () {
      expect(
        normalizeHtmlImageUrl('//i0.hdslb.com/bfs/article/a.png@640w.webp'),
        'https://i0.hdslb.com/bfs/article/a.png',
      );
      expect(
        normalizeHtmlImageUrl('http://i0.hdslb.com/bfs/emote/a.png'),
        'https://i0.hdslb.com/bfs/emote/a.png',
      );
    });

    test('rejects relative, local, data, and script image URLs', () {
      expect(normalizeHtmlImageUrl('/relative.png'), isNull);
      expect(normalizeHtmlImageUrl('file:///tmp/image.png'), isNull);
      expect(normalizeHtmlImageUrl('data:image/png;base64,AA=='), isNull);
      expect(normalizeHtmlImageUrl('javascript:alert(1)'), isNull);
    });
  });

  test('safe generic HTML images only allow absolute HTTP URLs', () {
    expect(isSafeHtmlImageUrl('https://github.com/image.png'), isTrue);
    expect(isSafeHtmlImageUrl('http://example.com/image.png'), isTrue);
    expect(isSafeHtmlImageUrl('data:image/png;base64,AA=='), isFalse);
    expect(isSafeHtmlImageUrl('file:///tmp/image.png'), isFalse);
    expect(isSafeHtmlImageUrl('javascript:alert(1)'), isFalse);
    expect(isSafeHtmlImageUrl('/relative.png'), isFalse);
  });

  testWidgets('uses the app image pipeline and preserves alt semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HtmlRender(
            constrainedWidth: 360,
            htmlContent: '''
              <p>正文</p>
              <img data-src="//i0.hdslb.com/bfs/article/a.png@640w.webp" alt="配图说明">
              <img src="https://i0.hdslb.com/bfs/mall/ad.png">
              <img src="javascript:alert(1)">
            ''',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HtmlWidget), findsOneWidget);
    expect(find.byType(NetworkImgLayer), findsOneWidget);
    final image = tester.widget<NetworkImgLayer>(find.byType(NetworkImgLayer));
    expect(image.src, 'https://i0.hdslb.com/bfs/article/a.png');
    expect(image.semanticsLabel, '配图说明');
    expect(
      find.descendant(
        of: find.byType(NetworkImgLayer),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '配图说明',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('hides scripts and treats article links as handled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HtmlRender(
            constrainedWidth: 360,
            htmlContent: '''
              <script>alert('unsafe')</script>
              <p>安全正文</p>
              <a href="javascript:alert(1)">危险链接</a>
            ''',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining("alert('unsafe')"), findsNothing);
    expect(find.textContaining('安全正文', findRichText: true), findsOneWidget);
    final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
    expect(
      await Future<bool>.value(html.onTapUrl!('javascript:alert(1)')),
      isTrue,
    );
  });

  testWidgets('renders a long malformed article through its final content', (
    tester,
  ) async {
    final html =
        '${buildHtmlRenderFixture(100 * 1024)}'
        '<p>长文档结束标记</p>';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HtmlRender(htmlContent: html, constrainedWidth: 360),
          ),
        ),
      ),
    );
    final endMarker = find.textContaining('长文档结束标记', findRichText: true);
    for (
      var attempt = 0;
      attempt < 50 && endMarker.evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    expect(find.textContaining('兼容性', findRichText: true), findsWidgets);
    expect(endMarker, findsOneWidget);
  });

  testWidgets('lazily renders a long article as slivers', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final html =
        '<p>Sliver 开始标记</p>'
        '${buildHtmlRenderFixture(100 * 1024)}'
        '<p>Sliver 结束标记</p>';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: CustomScrollView(
              controller: controller,
              slivers: [
                HtmlRenderSliver(htmlContent: html, constrainedWidth: 360),
              ],
            ),
          ),
        ),
      ),
    );
    final startMarker = find.textContaining('Sliver 开始标记', findRichText: true);
    for (
      var attempt = 0;
      attempt < 50 && startMarker.evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(startMarker, findsOneWidget);

    final endMarker = find.textContaining('Sliver 结束标记', findRichText: true);
    for (
      var attempt = 0;
      attempt < 20 && endMarker.evaluate().isEmpty;
      attempt++
    ) {
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    expect(endMarker, findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('renders at 200% text scale in ${brightness.name} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: HtmlRender(
                  constrainedWidth: 320,
                  htmlContent: '<h2>可访问性标题</h2><p>放大后的中文正文仍然完整可读。</p>',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('放大后的中文正文', findRichText: true),
        findsOneWidget,
      );
    });
  }
}

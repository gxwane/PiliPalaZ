import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pilipalaz/common/widgets/release_notes_view.dart';
import 'package:pilipalaz/models/github/latest.dart';

void main() {
  group('releaseNotesHtml', () {
    test('converts GitHub-flavored Markdown without dropping formatting', () {
      const release = LatestDataModel(
        body: '## 修复\n\n- 支持 **粗体**\n- 支持 ~~删除线~~',
      );

      final html = releaseNotesHtml(release);

      expect(html, matches(RegExp(r'<h2[^>]*>修复</h2>')));
      expect(html, contains('<li>支持 <strong>粗体</strong></li>'));
      expect(html, contains('<del>删除线</del>'));
    });

    test('prefers the raw HTML retained from an Atom response', () {
      const release = LatestDataModel(
        body: '纯文本后备',
        bodyHtml: '<h3>修复</h3><ul><li>Atom 内容</li></ul>',
      );

      expect(releaseNotesHtml(release), '<h3>修复</h3><ul><li>Atom 内容</li></ul>');
    });

    test('encodes raw HTML embedded in Markdown release notes', () {
      const release = LatestDataModel(body: '<script>alert(1)</script>');

      final html = releaseNotesHtml(release);

      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script>'));
      expect(html_parser.parseFragment(html).querySelector('script'), isNull);
    });
  });

  group('resolveReleaseNotesUri', () {
    const releaseUrl =
        'https://github.com/gxwane/PiliPalaZ/releases/tag/v1.3.0';

    test('accepts absolute HTTP links and resolves relative links', () {
      expect(
        resolveReleaseNotesUri('https://example.com/notes', releaseUrl),
        Uri.parse('https://example.com/notes'),
      );
      expect(
        resolveReleaseNotesUri('/gxwane/PiliPalaZ/issues/1', releaseUrl),
        Uri.parse('https://github.com/gxwane/PiliPalaZ/issues/1'),
      );
    });

    test('rejects non-web schemes and malformed links', () {
      expect(resolveReleaseNotesUri('javascript:alert(1)', releaseUrl), isNull);
      expect(resolveReleaseNotesUri('file:///tmp/release', releaseUrl), isNull);
      expect(resolveReleaseNotesUri('relative', 'not a URL'), isNull);
    });
  });

  testWidgets('renders complete long notes without adding an ellipsis', (
    tester,
  ) async {
    final body = List<String>.generate(
      60,
      (index) => '- 第 ${index + 1} 项更新内容',
    ).join('\n');
    final release = LatestDataModel(body: body);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReleaseNotesView(release: release),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
    expect(html.html, contains('第 60 项更新内容'));
    expect(find.text('…'), findsNothing);
  });

  testWidgets('opens only resolved web links', (tester) async {
    final opened = <Uri>[];
    const release = LatestDataModel(
      body: '[相对链接](/gxwane/PiliPalaZ/issues/1)',
      htmlUrl: 'https://github.com/gxwane/PiliPalaZ/releases/tag/v1.3.0',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReleaseNotesView(
            release: release,
            openLink: (uri) async => opened.add(uri),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
    expect(
      await Future<bool>.value(html.onTapUrl!('javascript:alert(1)')),
      isTrue,
    );
    expect(opened, isEmpty);

    expect(
      await Future<bool>.value(html.onTapUrl!('/gxwane/PiliPalaZ/issues/1')),
      isTrue,
    );
    await tester.pump();
    expect(opened, <Uri>[
      Uri.parse('https://github.com/gxwane/PiliPalaZ/issues/1'),
    ]);
  });
}

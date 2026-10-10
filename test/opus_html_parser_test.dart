import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/html.dart';

import 'support/http_test_harness.dart';

void main() {
  group('HtmlHttp.contentFromModule', () {
    test('renders headings with correct level tags', () {
      final moduleContent = {
        'paragraphs': [
          {
            'para_type': 8,
            'heading': {
              'level': 3,
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': '序曲：沙漏的刻度与热红茶'},
                },
              ],
            },
          },
          {
            'para_type': 8,
            'heading': {
              'level': 2,
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': '第一幕：雨林的狂言'},
                },
              ],
            },
          },
        ],
      };

      final html = HtmlHttp.contentFromModule(moduleContent);
      expect(html, contains('<h3>序曲：沙漏的刻度与热红茶</h3>'));
      expect(html, contains('<h2>第一幕：雨林的狂言</h2>'));
    });

    test('renders horizontal dividers for para_type 3', () {
      final moduleContent = {
        'paragraphs': [
          {
            'para_type': 1,
            'text': {
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': '上一段'},
                },
              ],
            },
          },
          {
            'para_type': 3,
            'line': {'line_type': 1},
          },
          {
            'para_type': 1,
            'text': {
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': '下一段'},
                },
              ],
            },
          },
        ],
      };

      final html = HtmlHttp.contentFromModule(moduleContent);
      expect(html, '<p>上一段</p><hr/><p>下一段</p>');
    });

    test('preserves rich text formatting and escapes unsafe HTML', () {
      final moduleContent = {
        'paragraphs': [
          {
            'para_type': 1,
            'format': {'align': 1},
            'text': {
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {
                    'words': '粗体',
                    'style': {'bold': true},
                  },
                },
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {
                    'words': '与斜体',
                    'style': {'italic': true},
                  },
                },
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {
                    'words': '与删除线',
                    'style': {'strikethrough': true},
                  },
                },
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {
                    'words': '与下划线',
                    'style': {'underline': true},
                  },
                },
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': '带颜色<script>', 'color': '#ff0000'},
                },
              ],
            },
          },
        ],
      };

      final html = HtmlHttp.contentFromModule(moduleContent);
      expect(
        html,
        '<p style="text-align: center;"><strong>粗体</strong><em>与斜体</em><del>与删除线</del><u>与下划线</u><span style="color: #ff0000;">带颜色&lt;script&gt;</span></p>',
      );
    });

    test('renders blockquote, code block, list, and link card', () {
      final moduleContent = {
        'paragraphs': [
          {
            'para_type': 4,
            'blockquote': {
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': '这是一段引用'},
                },
              ],
            },
          },
          {
            'para_type': 5,
            'code': {'code': 'const a = 1 < 2;'},
          },
          {
            'para_type': 6,
            'list': {
              'type': 1,
              'items': [
                {
                  'nodes': [
                    {
                      'type': 'TEXT_NODE_TYPE_WORD',
                      'word': {'words': '列表项一'},
                    },
                  ],
                },
                {
                  'nodes': [
                    {
                      'type': 'TEXT_NODE_TYPE_WORD',
                      'word': {'words': '列表项二'},
                    },
                  ],
                },
              ],
            },
          },
          {
            'para_type': 7,
            'link_card': {
              'url': 'https://www.bilibili.com/video/BV1xx411c7mD',
              'title': '参考视频',
            },
          },
        ],
      };

      final html = HtmlHttp.contentFromModule(moduleContent);
      expect(html, contains('<blockquote><p>这是一段引用</p></blockquote>'));
      expect(html, contains('<pre><code>const a = 1 &lt; 2;</code></pre>'));
      expect(html, contains('<ol><li>列表项一</li><li>列表项二</li></ol>'));
      expect(
        html,
        contains(
          '<p><a href="https://www.bilibili.com/video/BV1xx411c7mD">参考视频</a></p>',
        ),
      );
    });
  });

  group('HtmlHttp.reqHtml contract', () {
    test(
      'extracts title, author, headings, and dividers from Opus state',
      () async {
        final stateJson = jsonEncode({
          'detail': {
            'basic': {'comment_id_str': '12345678'},
            'modules': [
              {
                'module_type': 'MODULE_TYPE_TITLE',
                'module_title': {'text': '紫蔷薇的盛宴：图书管理员丽莎'},
              },
              {
                'module_type': 'MODULE_TYPE_AUTHOR',
                'module_author': {
                  'face': 'https://i0.hdslb.com/bfs/face/avatar.jpg',
                  'name': '杜默撰_',
                  'pub_time': '2026年10月10日 21:09',
                },
              },
              {
                'module_type': 'MODULE_TYPE_CONTENT',
                'module_content': {
                  'paragraphs': [
                    {
                      'para_type': 8,
                      'heading': {
                        'level': 3,
                        'nodes': [
                          {
                            'type': 'TEXT_NODE_TYPE_WORD',
                            'word': {'words': '序曲：沙漏的刻度与热红茶'},
                          },
                        ],
                      },
                    },
                    {
                      'para_type': 1,
                      'text': {
                        'nodes': [
                          {
                            'type': 'TEXT_NODE_TYPE_WORD',
                            'word': {'words': '在西风骑士团总部的深处...'},
                          },
                        ],
                      },
                    },
                    {
                      'para_type': 3,
                      'line': {'line_type': 1},
                    },
                    {
                      'para_type': 8,
                      'heading': {
                        'level': 3,
                        'nodes': [
                          {
                            'type': 'TEXT_NODE_TYPE_WORD',
                            'word': {'words': '第一幕：雨林的狂言与深渊的钥匙'},
                          },
                        ],
                      },
                    },
                  ],
                },
              },
            ],
          },
        });

        final htmlPage =
            '''
<!DOCTYPE html>
<html>
<head>
<script>
window.__INITIAL_STATE__ = $stateJson;
</script>
</head>
<body></body>
</html>
''';

        final harness = HttpTestHarness(
          (_) => ResponseBody.fromString(
            htmlPage,
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.textPlainContentType],
            },
          ),
        );

        final result = await harness.run(
          () => HtmlHttp.reqHtml('1257563830145253385', 'opus'),
        );

        expect(result, isA<ApiSuccess<HtmlArticleData>>());
        final data = (result as ApiSuccess<HtmlArticleData>).data;
        expect(data.title, '紫蔷薇的盛宴：图书管理员丽莎');
        expect(data.userName, '杜默撰_');
        expect(data.avatar, 'https://i0.hdslb.com/bfs/face/avatar.jpg');
        expect(data.updateTime, '2026年10月10日 21:09');
        expect(data.commentId, 12345678);
        expect(data.content, contains('<h3>序曲：沙漏的刻度与热红茶</h3>'));
        expect(data.content, contains('<p>在西风骑士团总部的深处...</p>'));
        expect(data.content, contains('<hr/>'));
        expect(data.content, contains('<h3>第一幕：雨林的狂言与深渊的钥匙</h3>'));
      },
    );

    test(
      'parses full multi-act Opus article preserving all 6 act titles and dividers',
      () {
        final acts = [
          '序曲：沙漏的刻度与热红茶',
          '第一幕：雨林的狂言与深渊的钥匙',
          '第二幕：第八小队的决斗与自制的艺术',
          '第三幕：雷霆的惩戒与林间的幼狼',
          '第四幕：日光下的海风与重着的旧袍',
          '尾声：永恒的午后四点',
        ];
        final paragraphs = <Map<String, dynamic>>[];
        for (int i = 0; i < acts.length; i++) {
          if (i > 0) {
            paragraphs.add({
              'para_type': 3,
              'line': {'line_type': 1},
            });
          }
          paragraphs.add({
            'para_type': 8,
            'heading': {
              'level': 3,
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': acts[i]},
                },
              ],
            },
          });
          paragraphs.add({
            'para_type': 1,
            'text': {
              'nodes': [
                {
                  'type': 'TEXT_NODE_TYPE_WORD',
                  'word': {'words': '正文段落 $i'},
                },
              ],
            },
          });
        }

        final html = HtmlHttp.contentFromModule({'paragraphs': paragraphs});
        for (final act in acts) {
          expect(html, contains('<h3>$act</h3>'));
        }
        expect(RegExp(r'<hr/>').allMatches(html).length, 5);
        expect(RegExp(r'<p>正文段落 \d</p>').allMatches(html).length, 6);
      },
    );
  });
}

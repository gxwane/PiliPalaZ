import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/pages/dynamics/widgets/content_panel.dart';
import 'package:pilipalaz/pages/dynamics/widgets/rich_node_panel.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  group('richNode Generation and Model Tests', () {
    test('parses rich text nodes with jumpUrl', () {
      final json = {
        'text': '这是一个商品推荐',
        'rich_text_nodes': [
          {
            'type': 'RICH_TEXT_NODE_TYPE_GOODS',
            'text': '原神手办',
            'orig_text': '原神手办',
            'jump_url': 'https://mall.bilibili.com/item/1',
          },
          {
            'type': 'RICH_TEXT_NODE_TYPE_LOTTERY',
            'text': '互动抽奖',
            'orig_text': '互动抽奖',
            'jump_url':
                'https://t.bilibili.com/lottery/h5/index/#/result?notice_id=123',
            'rid': '123',
          },
          {
            'type': 'RICH_TEXT_NODE_TYPE_TOPIC',
            'text': '#崩坏星穹铁道#',
            'orig_text': '#崩坏星穹铁道#',
          },
        ],
      };

      final desc = DynamicDescModel.fromJson(json);
      expect(desc.richTextNodes, hasLength(3));
      expect(
        desc.richTextNodes![0].jumpUrl,
        'https://mall.bilibili.com/item/1',
      );
      expect(desc.richTextNodes![1].jumpUrl, contains('notice_id=123'));
      expect(desc.richTextNodes![2].text, '#崩坏星穹铁道#');
    });

    testWidgets(
      'richNode generates WidgetSpans for topic, goods, lottery, web',
      (tester) async {
        final item = DynamicItemModel.fromJson({
          'id_str': '12345678',
          'modules': {
            'module_dynamic': {
              'desc': {
                'text': '测试动态',
                'rich_text_nodes': [
                  {
                    'type': 'RICH_TEXT_NODE_TYPE_TOPIC',
                    'text': '#测试话题#',
                    'orig_text': '#测试话题#',
                  },
                  {
                    'type': 'RICH_TEXT_NODE_TYPE_WEB',
                    'text': '官方链接',
                    'orig_text': 'https://www.bilibili.com',
                  },
                  {
                    'type': 'RICH_TEXT_NODE_TYPE_LOTTERY',
                    'text': '抽奖福利',
                    'orig_text': '抽奖福利',
                    'jump_url': 'https://t.bilibili.com/lottery/1',
                  },
                  {
                    'type': 'RICH_TEXT_NODE_TYPE_GOODS',
                    'text': '特惠周边',
                    'orig_text': '特惠周边',
                    'jump_url': 'https://mall.bilibili.com/1',
                  },
                ],
              },
            },
          },
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final span = richNode(item, context);
                  return Text.rich(span!);
                },
              ),
            ),
          ),
        );

        expect(find.text('#测试话题#'), findsOneWidget);
        expect(find.text('官方链接'), findsOneWidget);
        expect(find.text('抽奖福利 '), findsOneWidget);
        expect(find.text('特惠周边 '), findsOneWidget);
      },
    );
  });

  group('Content Panel Gesture & IgnorePointer Tests', () {
    testWidgets(
      'feed mode (source != detail) does NOT wrap in IgnorePointer(ignoring: true)',
      (tester) async {
        final item = DynamicItemModel.fromJson({
          'id_str': '12345678',
          'modules': {
            'module_dynamic': {
              'topic': {'id': 1, 'name': '置顶话题'},
              'desc': {
                'text': '动态正文内容',
                'rich_text_nodes': [
                  {'type': 'RICH_TEXT_NODE_TYPE_TEXT', 'orig_text': '普通文本内容'},
                ],
              },
            },
          },
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Content(
                item: item,
                source: null, // Feed stream mode
              ),
            ),
          ),
        );

        // In feed mode, IgnorePointer with ignoring == true must NOT exist around the text
        final ignorePointers = tester.widgetList<IgnorePointer>(
          find.byType(IgnorePointer),
        );
        for (final ip in ignorePointers) {
          expect(
            ip.ignoring,
            isFalse,
            reason: 'IgnorePointer should not block gestures in feed mode',
          );
        }

        // SelectableRegion must NOT be mounted in feed mode
        expect(find.byType(SelectableRegion), findsNothing);

        // Text must be present
        expect(find.text('#置顶话题'), findsOneWidget);
        expect(find.text('普通文本内容'), findsOneWidget);
      },
    );

    testWidgets(
      'detail mode (source == detail) mounts SelectableRegion for text selection',
      (tester) async {
        final item = DynamicItemModel.fromJson({
          'id_str': '12345678',
          'modules': {
            'module_dynamic': {
              'desc': {
                'text': '详情页文本',
                'rich_text_nodes': [
                  {
                    'type': 'RICH_TEXT_NODE_TYPE_TEXT',
                    'orig_text': '可长按选中的详情文本',
                  },
                ],
              },
            },
          },
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Content(
                item: item,
                source: 'detail', // Detail mode
              ),
            ),
          ),
        );

        // SelectableRegion MUST be mounted in detail mode
        expect(find.byType(SelectableRegion), findsOneWidget);
        expect(find.text('可长按选中的详情文本'), findsOneWidget);
      },
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:pilipalaz/pages/dynamics/widgets/forward_panel.dart';
import 'package:pilipalaz/pages/dynamics/widgets/nine_grid_gallery.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz_article_panel_test_',
    );
    Hive.init(hiveDirectory.path);
    GStorage.userInfo = await Hive.openBox<dynamic>('userInfo');
    GStorage.setting = await Hive.openBox<dynamic>('setting');
    GStorage.localCache = await Hive.openBox<dynamic>('localCache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('DYNAMIC_TYPE_ARTICLE Rendering Tests', () {
    final articleDynamicJson = {
      'id_str': '10001',
      'type': 'DYNAMIC_TYPE_ARTICLE',
      'modules': {
        'module_author': {
          'mid': 12345,
          'name': '杜默撰_',
          'face': 'https://i0.hdslb.com/bfs/face/test.jpg',
          'pub_action': '投稿了文章',
          'pub_time': '昨天 19:17',
          'pub_ts': 1711080000,
        },
        'module_stat': {
          'comment': {'count': 10, 'forbidden': false},
          'forward': {'count': 5, 'forbidden': false},
          'like': {'count': 100, 'status': false},
        },
        'module_dynamic': {
          'topic': {'id': 99, 'name': '原神'},
          'desc': null,
          'major': {
            'type': 'MAJOR_TYPE_OPUS',
            'opus': {
              'title': '冰霜与余烬的独行者：骑兵队长凯亚',
              'jump_url': '//www.bilibili.com/opus/123456789',
              'summary': {
                'text': '在蒙德城喧嚣褪尽的午夜，“天使的馈赠”酒馆二楼最幽暗的角落里...',
                'rich_text_nodes': [
                  {
                    'type': 'RICH_TEXT_NODE_TYPE_TEXT',
                    'orig_text': '在蒙德城喧嚣褪尽的午夜，“天使的馈赠”酒馆二楼最幽暗的角落里...',
                    'text': '在蒙德城喧嚣褪尽的午夜，“天使的馈赠”酒馆二楼最幽暗的角落里...',
                  },
                ],
              },
              'pics': [
                {
                  'url': 'https://i0.hdslb.com/bfs/article/cover.jpg',
                  'width': 1080,
                  'height': 600,
                  'size': 123456,
                },
              ],
            },
          },
        },
      },
    };

    testWidgets(
      'floor == 1: DynamicPanel renders article title and summary exactly ONCE without duplicate gray card',
      (WidgetTester tester) async {
        final item = DynamicItemModel.fromJson(articleDynamicJson);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DynamicPanel(item: item, source: null),
              ),
            ),
          ),
        );
        await tester.pump();

        // 1. Topic tag rendered
        expect(find.text('#原神'), findsOneWidget);

        // 2. Article Title rendered exactly ONCE (no double card)
        expect(find.textContaining('冰霜与余烬的独行者：骑兵队长凯亚'), findsOneWidget);

        // 3. Article Summary rendered exactly ONCE
        expect(
          find.textContaining('在蒙德城喧嚣褪尽的午夜，“天使的馈赠”酒馆二楼最幽暗的角落里...'),
          findsOneWidget,
        );

        // 4. NineGridGallery rendered for the cover pic
        expect(find.byType(NineGridGallery), findsOneWidget);

        // 5. forWard(item, ...) must return SizedBox.shrink() at floor == 1, not duplicate articlePanel
        final forwardWidget = forWard(
          item,
          tester.element(find.byType(DynamicPanel)),
          null,
          null,
          floor: 1,
        );
        expect(forwardWidget, isA<SizedBox>());
      },
    );

    testWidgets(
      'floor == 2: forWard renders articlePanel with author, title, summary, and opus cover gallery',
      (WidgetTester tester) async {
        final item = DynamicItemModel.fromJson(articleDynamicJson);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return forWard(item, context, null, null, floor: 2);
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // At floor == 2 (forwarded article):
        // 1. Shows original author
        expect(find.textContaining('@杜默撰_'), findsOneWidget);

        // 2. Shows article title
        expect(find.text('冰霜与余烬的独行者：骑兵队长凯亚'), findsOneWidget);

        // 3. Shows article summary
        expect(
          find.textContaining('在蒙德城喧嚣褪尽的午夜，“天使的馈赠”酒馆二楼最幽暗的角落里...'),
          findsOneWidget,
        );

        // 4. Shows cover gallery for floor == 2
        expect(find.byType(NineGridGallery), findsOneWidget);
      },
    );

    testWidgets(
      'supports legacy MAJOR_TYPE_ARTICLE in Content panel gracefully',
      (WidgetTester tester) async {
        final legacyArticleJson = {
          'id_str': '10002',
          'type': 'DYNAMIC_TYPE_ARTICLE',
          'modules': {
            'module_author': {
              'mid': 54321,
              'name': '老专栏UP',
              'face': 'https://i0.hdslb.com/bfs/face/old.jpg',
              'pub_action': '投稿了文章',
              'pub_time': '2023-01-01',
            },
            'module_stat': {
              'comment': {'count': 0, 'forbidden': false},
              'forward': {'count': 0, 'forbidden': false},
              'like': {'count': 0, 'status': false},
            },
            'module_dynamic': {
              'desc': null,
              'major': {
                'type': 'MAJOR_TYPE_ARTICLE',
                'article': {
                  'id': 8888,
                  'title': '经典专栏回顾',
                  'desc': '这是旧版专栏的描述摘要文本',
                  'covers': ['https://i0.hdslb.com/bfs/article/old_cover.jpg'],
                },
              },
            },
          },
        };

        final item = DynamicItemModel.fromJson(legacyArticleJson);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DynamicPanel(item: item, source: null),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('经典专栏回顾'), findsOneWidget);
        expect(find.textContaining('这是旧版专栏的描述摘要文本'), findsOneWidget);
        expect(find.byType(NineGridGallery), findsOneWidget);
      },
    );
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/pages/dynamics/widgets/forward_panel.dart';
import 'package:pilipalaz/pages/dynamics/widgets/nine_grid_gallery.dart';
import 'package:pilipalaz/pages/dynamics/widgets/pic_panel.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz_forward_model_test_',
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

  group('ItemOrigModel & Forward Dynamics Tests (Red-Green TDD)', () {
    final forwardDynamicJson = {
      'id_str': '999001',
      'type': 'DYNAMIC_TYPE_FORWARD',
      'basic': {'comment_id_str': '999001'},
      'modules': {
        'module_author': {
          'mid': 111,
          'name': '转发者A',
          'face': 'https://i0.hdslb.com/bfs/face/1.jpg',
          'pub_time': '10分钟前',
          'pub_ts': 1711080000,
        },
        'module_dynamic': {
          'desc': {'text': '看看这个好看的画！'},
        },
      },
      'orig': {
        'id_str': '888002',
        'type': 'DYNAMIC_TYPE_DRAW',
        'basic': {'comment_id_str': '888002'},
        'modules': {
          'module_author': {
            'mid': 222,
            'name': '原作者B',
            'face': 'https://i0.hdslb.com/bfs/face/2.jpg',
            'pub_time': '1小时前',
            'pub_ts': 1711076400,
          },
          'module_dynamic': {
            'desc': {'text': '今天画了一张插画'},
            'major': {
              'type': 'MAJOR_TYPE_OPUS',
              'opus': {
                'title': '插画测试',
                'jump_url': '//www.bilibili.com/opus/888002',
                'pics': [
                  {
                    'url': 'https://i0.hdslb.com/bfs/album/test1.jpg',
                    'width': 800,
                    'height': 600,
                    'size': 120,
                  },
                ],
              },
            },
          },
        },
      },
    };

    test(
      'ItemOrigModel should parse id_str as idStr and maintain isStr compatibility',
      () {
        final dynamicItem = DynamicItemModel.fromJson(forwardDynamicJson);
        expect(dynamicItem.orig, isNotNull);
        final dynamic origDynamic = dynamicItem.orig;

        // Expect orig to expose idStr getter with the parsed '888002'
        expect(origDynamic.idStr, equals('888002'));
        // Expect legacy isStr getter to also return '888002'
        expect(origDynamic.isStr, equals('888002'));
      },
    );

    testWidgets(
      'forWard renders forwarded DYNAMIC_TYPE_DRAW without NoSuchMethodError',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final dynamicItem = DynamicItemModel.fromJson(forwardDynamicJson);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) {
                    return forWard(
                      dynamicItem,
                      context,
                      null,
                      'feed',
                      floor: 1,
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Expect original author and forwarded NineGridGallery to be rendered
        expect(find.textContaining('@原作者B'), findsOneWidget);
        expect(find.byType(NineGridGallery), findsOneWidget);
        // Zero exceptions thrown during render
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'forWard falls back to basic["comment_id_str"] when idStr is null',
      (WidgetTester tester) async {
        final jsonWithoutIdStr = {
          'type': 'DYNAMIC_TYPE_DRAW',
          'basic': {'comment_id_str': '777003'},
          'modules': {
            'module_author': {
              'mid': 333,
              'name': '无ID原作者',
              'face': 'https://i0.hdslb.com/bfs/face/3.jpg',
              'pub_time': '2小时前',
              'pub_ts': 1711072800,
            },
            'module_dynamic': {
              'desc': {'text': '无主键测试'},
              'major': {
                'type': 'MAJOR_TYPE_OPUS',
                'opus': {
                  'title': '测试画册',
                  'pics': [
                    {
                      'url': 'https://i0.hdslb.com/bfs/album/test2.jpg',
                      'width': 600,
                      'height': 600,
                      'size': 90,
                    },
                  ],
                },
              },
            },
          },
        };

        final origItem = ItemOrigModel.fromJson(jsonWithoutIdStr);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return forWard(origItem, context, null, 'feed', floor: 2);
                },
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.textContaining('@无ID原作者'), findsOneWidget);
        expect(find.byType(NineGridGallery), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    test('ItemOrigModel constructor and backward compatibility assertions', () {
      // 1. Initialized via legacy isStr named parameter
      final legacyModel = ItemOrigModel(isStr: 'legacy_123');
      expect(legacyModel.idStr, equals('legacy_123'));
      expect(legacyModel.isStr, equals('legacy_123'));

      // 2. Initialized via new idStr named parameter
      final modernModel = ItemOrigModel(idStr: 'modern_456');
      expect(modernModel.idStr, equals('modern_456'));
      expect(modernModel.isStr, equals('modern_456'));

      // 3. Backward compatibility with legacy json['is_str'] only
      final jsonModel = ItemOrigModel.fromJson({'is_str': 'json_legacy_789'});
      expect(jsonModel.idStr, equals('json_legacy_789'));
      expect(jsonModel.isStr, equals('json_legacy_789'));

      // 4. Setter compatibility
      jsonModel.isStr = 'mutated_val';
      expect(jsonModel.idStr, equals('mutated_val'));
      expect(jsonModel.isStr, equals('mutated_val'));
    });

    testWidgets('picWidget handles ItemOrigModel directly without throwing', (
      WidgetTester tester,
    ) async {
      final origItem = ItemOrigModel.fromJson({
        'id_str': '666004',
        'type': 'DYNAMIC_TYPE_DRAW',
        'modules': {
          'module_dynamic': {
            'major': {
              'type': 'MAJOR_TYPE_DRAW',
              'draw': {
                'items': [
                  {
                    'src': 'https://i0.hdslb.com/bfs/album/pic3.jpg',
                    'width': 500,
                    'height': 500,
                  },
                ],
              },
            },
          },
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return picWidget(origItem, context, floor: 2);
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(NineGridGallery), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/pages/dynamics/widgets/additional_panel.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  group('DynamicAddModel Deserialization Tests', () {
    test('parses common card correctly', () {
      final json = {
        'type': 'ADDITIONAL_TYPE_COMMON',
        'common': {
          'cover': 'https://i0.hdslb.com/bfs/game/cover.png',
          'title': '原神',
          'desc1': '开放世界冒险RPG',
          'desc2': '4.8版本全新上线',
          'jump_url': 'https://game.bilibili.com/genshin',
          'button': {'text': '预约', 'type': 1},
        },
      };
      final model = DynamicAddModel.fromJson(json);
      expect(model.type, 'ADDITIONAL_TYPE_COMMON');
      expect(model.common, isNotNull);
      expect(model.common!.title, '原神');
      expect(model.common!.desc1, '开放世界冒险RPG');
      expect(model.common!.buttonText, '预约');
      expect(model.common!.jumpUrl, 'https://game.bilibili.com/genshin');
    });

    test(
      'parses match card correctly with nested match_info and dual-track',
      () {
        final json = {
          'type': 'ADDITIONAL_TYPE_MATCH',
          'match': {
            'title': '2026 LPL春季赛',
            'jump_url': 'https://www.bilibili.com/match/12345',
            'match_info': {
              'status': 2,
              'status_name': '进行中',
              'center_desc': 'BO3',
              'left_team': {
                'name': 'BLG',
                'cover': 'https://i0.hdslb.com/blg.png',
                'score': '1',
              },
              'right_team': {
                'team_name': 'TES',
                'pic': 'https://i0.hdslb.com/tes.png',
                'score': '0',
              },
            },
          },
        };
        final model = DynamicAddModel.fromJson(json);
        expect(model.type, 'ADDITIONAL_TYPE_MATCH');
        expect(model.match, isNotNull);
        expect(model.match!.title, '2026 LPL春季赛');
        expect(model.match!.status, 2);
        expect(model.match!.statusName, '进行中');
        expect(model.match!.leftTeam?.name, 'BLG');
        expect(model.match!.leftTeam?.score, '1');
        expect(model.match!.rightTeam?.name, 'TES');
        expect(model.match!.rightTeam?.cover, 'https://i0.hdslb.com/tes.png');
        expect(model.match!.rightTeam?.score, '0');
      },
    );

    test('parses vote card correctly with title and desc fallback', () {
      final json = {
        'type': 'ADDITIONAL_TYPE_VOTE',
        'vote': {
          'vote_id': 998877,
          'desc': '大家平时最喜欢哪个画质？',
          'join_num': 5432,
          'choice_cnt': 1,
          'status': 1,
          'end_time': 1750000000,
        },
      };
      final model = DynamicAddModel.fromJson(json);
      expect(model.type, 'ADDITIONAL_TYPE_VOTE');
      expect(model.vote, isNotNull);
      expect(model.vote!.voteId, 998877);
      expect(model.vote!.title, '大家平时最喜欢哪个画质？');
      expect(model.vote!.joinNum, 5432);
      expect(model.vote!.status, 1);
    });

    test('parses goods card correctly', () {
      final json = {
        'type': 'ADDITIONAL_TYPE_GOODS',
        'goods': {
          'head_text': 'UP主好物推荐',
          'jump_url': 'https://mall.bilibili.com',
          'items': [
            {
              'name': '2233限量手办',
              'brief': '官方正品周边',
              'price': '299.00',
              'cover': 'https://i0.hdslb.com/figure.png',
              'jump_url': 'https://mall.bilibili.com/detail/1',
              'jump_desc': '立即购买',
            },
          ],
        },
      };
      final model = DynamicAddModel.fromJson(json);
      expect(model.type, 'ADDITIONAL_TYPE_GOODS');
      expect(model.goods, isNotNull);
      expect(model.goods!.items, hasLength(1));
      expect(model.goods!.items!.first.name, '2233限量手办');
      expect(model.goods!.items!.first.price, '299.00');
      expect(model.goods!.items!.first.jumpDesc, '立即购买');
    });

    test('handles dirty data and empty maps gracefully without throwing', () {
      final dirtyJson = <String, dynamic>{
        'type': 'ADDITIONAL_TYPE_UNKNOWN',
        'common': 'invalid_string',
        'match': null,
        'vote': {'vote_id': 'not_an_int'},
        'goods': {'items': 'not_a_list'},
      };
      final model = DynamicAddModel.fromJson(dirtyJson);
      expect(model.type, 'ADDITIONAL_TYPE_UNKNOWN');
      expect(model.common, isNull);
      expect(model.match, isNull);
      expect(model.vote?.voteId, isNull);
      expect(model.goods?.items, isEmpty);
    });
  });

  group('addWidget UI Rendering Tests', () {
    testWidgets('renders goods card with thumbnail, name and price', (
      tester,
    ) async {
      final item = DynamicItemModel.fromJson({
        'id_str': '12345678',
        'modules': {
          'module_dynamic': {
            'additional': {
              'type': 'ADDITIONAL_TYPE_GOODS',
              'goods': {
                'items': [
                  {
                    'name': 'PiliPalaZ定制马克杯',
                    'brief': '陶瓷材质，精美印花',
                    'price': '59.00',
                    'cover': 'https://i0.hdslb.com/mug.png',
                    'jump_url': 'https://mall.bilibili.com/detail/123',
                    'jump_desc': '立即抢购',
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
              builder: (context) =>
                  addWidget(item, context, 'ADDITIONAL_TYPE_GOODS', floor: 1),
            ),
          ),
        ),
      );

      expect(find.text('PiliPalaZ定制马克杯'), findsOneWidget);
      expect(find.text('陶瓷材质，精美印花'), findsOneWidget);
      expect(find.text('¥59.00'), findsOneWidget);
      expect(find.text('立即抢购'), findsOneWidget);
    });

    testWidgets('renders common card with icon, title and action button', (
      tester,
    ) async {
      final item = DynamicItemModel.fromJson({
        'id_str': '12345678',
        'modules': {
          'module_dynamic': {
            'additional': {
              'type': 'ADDITIONAL_TYPE_COMMON',
              'common': {
                'cover': 'https://i0.hdslb.com/game.png',
                'title': '绝区零',
                'desc1': '米哈游全新动作游戏',
                'jump_url': 'https://zzz.mihoyo.com',
                'button': {'text': '进入官网'},
              },
            },
          },
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  addWidget(item, context, 'ADDITIONAL_TYPE_COMMON', floor: 1),
            ),
          ),
        ),
      );

      expect(find.text('绝区零'), findsOneWidget);
      expect(find.text('米哈游全新动作游戏'), findsOneWidget);
      expect(find.text('进入官网'), findsOneWidget);
    });

    testWidgets('renders match card with team names, score and status', (
      tester,
    ) async {
      final item = DynamicItemModel.fromJson({
        'id_str': '12345678',
        'modules': {
          'module_dynamic': {
            'additional': {
              'type': 'ADDITIONAL_TYPE_MATCH',
              'match': {
                'title': '英雄联盟全球总决赛',
                'jump_url': 'https://www.bilibili.com/s14',
                'match_info': {
                  'status': 2,
                  'status_name': '进行中',
                  'left_team': {'name': 'T1', 'score': '2'},
                  'right_team': {'name': 'GEN', 'score': '1'},
                },
              },
            },
          },
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  addWidget(item, context, 'ADDITIONAL_TYPE_MATCH', floor: 1),
            ),
          ),
        ),
      );

      expect(find.text('英雄联盟全球总决赛'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget);
      expect(find.text('T1'), findsOneWidget);
      expect(find.text('GEN'), findsOneWidget);
      expect(find.text('2 : 1'), findsOneWidget);
    });

    testWidgets('renders vote card with title, participants and status', (
      tester,
    ) async {
      final item = DynamicItemModel.fromJson({
        'id_str': '12345678',
        'basic': {'comment_id_str': '888888'},
        'modules': {
          'module_dynamic': {
            'additional': {
              'type': 'ADDITIONAL_TYPE_VOTE',
              'vote': {
                'vote_id': 6666,
                'title': '你最期待哪个动漫更新？',
                'join_num': 8848,
                'status': 1,
              },
            },
          },
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  addWidget(item, context, 'ADDITIONAL_TYPE_VOTE', floor: 2),
            ),
          ),
        ),
      );

      expect(find.text('你最期待哪个动漫更新？'), findsOneWidget);
      expect(find.text('8848 人参与 · 进行中'), findsOneWidget);
      expect(find.text('去投票'), findsOneWidget);
    });

    testWidgets('never renders Text(11) on unknown additional types', (
      tester,
    ) async {
      final item = DynamicItemModel.fromJson({
        'id_str': '12345678',
        'modules': {
          'module_dynamic': {
            'additional': {'type': 'ADDITIONAL_TYPE_UNKNOWN_XYZ'},
          },
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  addWidget(item, context, 'ADDITIONAL_TYPE_UNKNOWN_XYZ'),
            ),
          ),
        ),
      );

      expect(find.text('11'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
      'gracefully handles null additional or missing fields without crash',
      (tester) async {
        final itemNull = DynamicItemModel.fromJson({});

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    addWidget(itemNull, context, 'ADDITIONAL_TYPE_GOODS'),
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/season.dart';

void main() {
  testWidgets('SeasonPanel renders nothing when sections is empty or null', (
    WidgetTester tester,
  ) async {
    final ugcSeason = UgcSeason.fromJson(<String, dynamic>{
      'id': 1,
      'title': '测试合集',
      'stat': <String, dynamic>{},
      'sections': <dynamic>[],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeasonPanel(
            ugcSeason: ugcSeason,
            cid: 100,
            changeFuc: (dynamic bvid, dynamic cid, dynamic aid) {},
            heroTag: 'testTagEmpty',
          ),
        ),
      ),
    );

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets(
    'SeasonPanel renders single section card with correct title and progress',
    (WidgetTester tester) async {
      final ugcSeason = UgcSeason.fromJson(<String, dynamic>{
        'id': 1,
        'title': 'Flutter入门指南',
        'stat': <String, dynamic>{},
        'sections': <dynamic>[
          <String, dynamic>{
            'season_id': 1,
            'id': 10,
            'title': '第一季',
            'episodes': <dynamic>[
              <String, dynamic>{
                'cid': 101,
                'aid': 1,
                'title': '环境安装',
                'page': <String, dynamic>{'cid': 101, 'page': 1, 'part': 'P1'},
              },
              <String, dynamic>{
                'cid': 102,
                'aid': 1,
                'title': '基础组件',
                'page': <String, dynamic>{'cid': 102, 'page': 2, 'part': 'P2'},
              },
            ],
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonPanel(
              ugcSeason: ugcSeason,
              cid: 101,
              changeFuc: (dynamic bvid, dynamic cid, dynamic aid) {},
              heroTag: 'testTagSingle',
            ),
          ),
        ),
      );

      // Single card
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.text('合集：Flutter入门指南'), findsOneWidget);
      // Shows current playing progress (1/2)
      expect(find.text('1/2'), findsOneWidget);
    },
  );

  testWidgets(
    'SeasonPanel renders multiple section cards with playing state and total counts',
    (WidgetTester tester) async {
      final ugcSeason = UgcSeason.fromJson(<String, dynamic>{
        'id': 2,
        'title': '全栈开发教程',
        'stat': <String, dynamic>{},
        'sections': <dynamic>[
          <String, dynamic>{
            'season_id': 2,
            'id': 20,
            'title': '前端篇',
            'episodes': <dynamic>[
              <String, dynamic>{
                'cid': 201,
                'aid': 2,
                'title': 'HTML基础',
                'page': <String, dynamic>{'cid': 201, 'page': 1, 'part': 'P1'},
              },
              <String, dynamic>{
                'cid': 202,
                'aid': 2,
                'title': 'CSS入门',
                'page': <String, dynamic>{'cid': 202, 'page': 2, 'part': 'P2'},
              },
              <String, dynamic>{
                'cid': 203,
                'aid': 2,
                'title': 'JS进阶',
                'page': <String, dynamic>{'cid': 203, 'page': 3, 'part': 'P3'},
              },
            ],
          },
          <String, dynamic>{
            'season_id': 2,
            'id': 21,
            'title': '后端篇',
            'episodes': <dynamic>[
              <String, dynamic>{
                'cid': 301,
                'aid': 3,
                'title': 'Node.js',
                'page': <String, dynamic>{'cid': 301, 'page': 1, 'part': 'P1'},
              },
              <String, dynamic>{
                'cid': 302,
                'aid': 3,
                'title': 'Database',
                'page': <String, dynamic>{'cid': 302, 'page': 2, 'part': 'P2'},
              },
            ],
          },
        ],
      });

      // Playing cid 202 in section 1 (前端篇)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonPanel(
              ugcSeason: ugcSeason,
              cid: 202,
              changeFuc: (dynamic bvid, dynamic cid, dynamic aid) {},
              heroTag: 'testTagMulti',
            ),
          ),
        ),
      );

      // Should find 2 section cards
      expect(find.byType(InkWell), findsNWidgets(2));

      // Section 1: Front-end (playing 2/3)
      expect(find.text('合集：全栈开发教程 · 前端篇'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);

      // Section 2: Back-end (not currently playing, showing total count: 共2集)
      expect(find.text('合集：全栈开发教程 · 后端篇'), findsOneWidget);
      expect(find.text('共2集'), findsOneWidget);
    },
  );
}

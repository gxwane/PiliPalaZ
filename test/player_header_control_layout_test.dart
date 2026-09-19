import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/widgets/player_header_action_row.dart';

Widget _button(String key, {double width = 48, double height = 48}) {
  return SizedBox(key: ValueKey(key), width: width, height: height);
}

Widget _buildLandscapeActionRow({
  required String timeText,
  required List<Widget> actions,
}) {
  return Row(
    children: [
      Text(
        "   $timeText",
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets(
    'player header fits the 340dp portrait title area in compact mode',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 340,
                child: PlayerHeaderActionRow(
                  backButton: _button('back'),
                  homeButton: _button('home'),
                  isEquivalentFullScreen: false,
                  compactActions: [
                    _button('danmaku-input'),
                    _button('danmaku-switch'),
                    _button('pip'),
                  ],
                  moreButton: _button('more'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('more')), findsOneWidget);
      expect(find.byKey(const ValueKey('pip')), findsOneWidget);
    },
  );

  testWidgets(
    'player header fits the 340dp portrait title area in expanded title mode',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 340,
                child: PlayerHeaderActionRow(
                  backButton: _button('back'),
                  homeButton: _button('home'),
                  isEquivalentFullScreen: true,
                  expandedTitle: const Text(
                    '这是一个非常非常长的视频标题，用于测试在竖屏全屏模式下的文本截断与弹性适配能力',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  compactActions: const [],
                  moreButton: _button('more'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('back')), findsOneWidget);
      expect(find.byKey(const ValueKey('home')), findsOneWidget);
      expect(find.byKey(const ValueKey('more')), findsOneWidget);
      expect(find.textContaining('这是一个非常非常长'), findsOneWidget);
    },
  );

  testWidgets(
    'guarded second action row renders cleanly without overflow in 800dp landscape',
    (tester) async {
      final actions = [
        _button('like'),
        _button('coin'),
        _button('shoot-danmaku'),
        _button('danmaku-switch'),
        _button('pip'),
        _button('share'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: _buildLandscapeActionRow(
                timeText: '22:31',
                actions: actions,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('   22:31'), findsOneWidget);
      for (final key in [
        'like',
        'coin',
        'shoot-danmaku',
        'danmaku-switch',
        'pip',
        'share',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
    },
  );

  testWidgets(
    'guarded second action row never overflows even under 340dp or 320dp constraints',
    (tester) async {
      final actions = [
        _button('like'),
        _button('coin'),
        _button('shoot-danmaku'),
        _button('danmaku-switch'),
        _button('pip'),
        _button('share'),
      ];

      for (final width in [360.0, 340.0, 320.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: _buildLandscapeActionRow(
                  timeText: '22:31',
                  actions: actions,
                ),
              ),
            ),
          ),
        );

        // Must never trigger RenderFlex overflow exception
        expect(
          tester.takeException(),
          isNull,
          reason: 'Must not throw RenderFlex overflow at width $width',
        );
      }
    },
  );
}

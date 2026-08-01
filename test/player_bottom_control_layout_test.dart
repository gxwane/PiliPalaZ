import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/models/bottom_control_type.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/bottom_control.dart';

const _allControls = <BottomControlType>[
  BottomControlType.playOrPause,
  BottomControlType.pre,
  BottomControlType.next,
  BottomControlType.subtitle,
  BottomControlType.episode,
  BottomControlType.fit,
  BottomControlType.speed,
  BottomControlType.fullscreen,
];

void main() {
  group('resolveBottomControlLayout', () {
    test('keeps every control when the row is wide enough', () {
      final layout = resolveBottomControlLayout(
        maxWidth: 8 * bottomControlItemExtent,
        controls: _allControls,
      );

      expect(layout.visible, _allControls);
      expect(layout.overflow, isEmpty);
      expect(layout.showOverflow, isFalse);
    });

    test('moves settings to overflow before playback navigation', () {
      final layout = resolveBottomControlLayout(
        maxWidth: 330,
        controls: _allControls,
      );

      expect(layout.visible, const [
        BottomControlType.playOrPause,
        BottomControlType.pre,
        BottomControlType.next,
        BottomControlType.episode,
        BottomControlType.speed,
        BottomControlType.fullscreen,
      ]);
      expect(layout.overflow, const [
        BottomControlType.subtitle,
        BottomControlType.fit,
      ]);
      expect(layout.showOverflow, isTrue);
    });

    test('keeps next playback action when only one optional slot remains', () {
      final layout = resolveBottomControlLayout(
        maxWidth: 168,
        controls: _allControls,
      );

      expect(layout.visible, const [
        BottomControlType.playOrPause,
        BottomControlType.next,
        BottomControlType.fullscreen,
      ]);
      expect(layout.showOverflow, isTrue);
    });

    test('keeps only core controls when overflow itself cannot fit', () {
      final layout = resolveBottomControlLayout(
        maxWidth: 84,
        controls: _allControls,
      );

      expect(layout.visible, const [
        BottomControlType.playOrPause,
        BottomControlType.fullscreen,
      ]);
      expect(layout.showOverflow, isFalse);
    });
  });

  test(
    'default controls omit unavailable subtitles and spacer placeholders',
    () {
      final controls = buildDefaultBottomControlTypes(
        hasEpisodes: false,
        isEquivalentFullScreen: false,
        hasSubtitles: false,
      );

      expect(controls, const [
        BottomControlType.playOrPause,
        BottomControlType.speed,
        BottomControlType.fullscreen,
      ]);
      expect(controls, isNot(contains(BottomControlType.space)));
      expect(controls, isNot(contains(BottomControlType.spaceButton)));
      expect(controls, isNot(contains(BottomControlType.subtitle)));
    },
  );

  testWidgets('adaptive row does not overflow at a narrow player width', (
    tester,
  ) async {
    final controls = _allControls
        .map(
          (type) => BottomControlItem(
            type: type,
            child: SizedBox(
              key: ValueKey(type),
              width: bottomControlItemExtent,
              height: 38,
            ),
          ),
        )
        .toList();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 330,
              child: AdaptiveBottomControlRow(
                controls: controls,
                overflowButtonBuilder: (_, hidden) => SizedBox(
                  key: const ValueKey('more'),
                  width: bottomControlItemExtent,
                  height: 38,
                  child: Text('${hidden.length}'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('more')), findsOneWidget);
    expect(find.byKey(const ValueKey(BottomControlType.pre)), findsOneWidget);
    expect(
      find.byKey(const ValueKey(BottomControlType.subtitle)),
      findsNothing,
    );
    expect(find.byKey(const ValueKey(BottomControlType.fit)), findsNothing);
  });
}

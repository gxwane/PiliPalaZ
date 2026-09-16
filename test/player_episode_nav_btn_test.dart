import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/bottom_control_type.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/bottom_control.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/episode_nav_btn.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EpisodeNavButtons Safe Obx Tests (No 0-Rx Assertion)', () {
    testWidgets(
      'PreEpisodeButton renders safely when queueController is null',
      (WidgetTester tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PreEpisodeButton(
                queueController: null,
                onPlay: () => tapped = true,
              ),
            ),
          ),
        );

        // Verify no exception was thrown by GetX
        expect(tester.takeException(), isNull);
        expect(find.byType(PreEpisodeButton), findsOneWidget);
        expect(find.byIcon(Icons.skip_previous), findsOneWidget);

        await tester.tap(find.byIcon(Icons.skip_previous));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'NextEpisodeButton renders safely when queueController is null',
      (WidgetTester tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NextEpisodeButton(
                queueController: null,
                onPlay: () => tapped = true,
              ),
            ),
          ),
        );

        // Verify no exception was thrown by GetX
        expect(tester.takeException(), isNull);
        expect(find.byType(NextEpisodeButton), findsOneWidget);
        expect(find.byIcon(Icons.skip_next), findsOneWidget);

        await tester.tap(find.byIcon(Icons.skip_next));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'PreEpisodeButton responds reactively to hasPrevious when queueController is present',
      (WidgetTester tester) async {
        final qc = PlaybackQueueController(heroTag: 'test_pre_tag');
        qc.hasPrevious.value = false;
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PreEpisodeButton(
                queueController: qc,
                onPlay: () => tapped = true,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final iconFinder = find.byIcon(Icons.skip_previous);
        expect(iconFinder, findsOneWidget);
        Icon iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.color, Colors.white38);

        // Tap when disabled should not invoke onPlay
        await tester.tap(iconFinder);
        expect(tapped, isFalse);

        // Enable hasPrevious
        qc.hasPrevious.value = true;
        await tester.pump();

        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.color, Colors.white);

        // Tap when enabled invokes onPlay
        await tester.tap(iconFinder);
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'NextEpisodeButton responds reactively to hasNext when queueController is present',
      (WidgetTester tester) async {
        final qc = PlaybackQueueController(heroTag: 'test_next_tag');
        qc.hasNext.value = false;
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NextEpisodeButton(
                queueController: qc,
                onPlay: () => tapped = true,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final iconFinder = find.byIcon(Icons.skip_next);
        expect(iconFinder, findsOneWidget);
        Icon iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.color, Colors.white38);

        // Tap when disabled should not invoke onPlay
        await tester.tap(iconFinder);
        expect(tapped, isFalse);

        // Enable hasNext
        qc.hasNext.value = true;
        await tester.pump();

        iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.color, Colors.white);

        // Tap when enabled invokes onPlay
        await tester.tap(iconFinder);
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'AdaptiveBottomControlRow with Pre and Next buttons inside nested LayoutBuilders throws 0 GetX exceptions',
      (WidgetTester tester) async {
        // Replicate exact crash stack:
        // LayoutBuilder (outer) -> Scaffold -> LayoutBuilder (inside AdaptiveBottomControlRow)
        await tester.pumpWidget(
          MaterialApp(
            home: LayoutBuilder(
              builder: (context, constraints) {
                return Scaffold(
                  body: AdaptiveBottomControlRow(
                    overflowButtonBuilder: (context, hiddenControls) =>
                        const SizedBox(),
                    controls: [
                      BottomControlItem(
                        type: BottomControlType.pre,
                        child: PreEpisodeButton(
                          queueController: null,
                          onPlay: () {},
                        ),
                      ),
                      BottomControlItem(
                        type: BottomControlType.next,
                        child: NextEpisodeButton(
                          queueController: null,
                          onPlay: () {},
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(PreEpisodeButton), findsOneWidget);
        expect(find.byType(NextEpisodeButton), findsOneWidget);
      },
    );
  });
}

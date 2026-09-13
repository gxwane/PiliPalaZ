import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pilipalaz/models/home/rcmd/result.dart';
import 'package:pilipalaz/common/widgets/video_card_v.dart';
import 'package:pilipalaz/pages/home/view.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/action_item.dart';
import 'package:pilipalaz/pages/video/widgets/player_header_action_row.dart';
import 'package:pilipalaz/plugin/pl_player/models/bottom_control_type.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/bottom_control.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/common_btn.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/play_pause_btn.dart';

import '../journeys/support/journey_test_environment.dart';

Widget _wrapInTestApp(Widget child, {Size? surfaceSize, Color? canvasColor}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: surfaceSize ?? const Size(800, 600)),
      child: Scaffold(
        backgroundColor: canvasColor ?? Colors.black,
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('Accessibility Guidelines Baseline Suite', () {
    setUpAll(() async {
      await initTestStorage();
    });
    // -------------------------------------------------------------------------
    // TC-A11Y-01: Player Bottom Controls Meet Touch Target & Label Guidelines
    // -------------------------------------------------------------------------
    testWidgets(
      'TC-A11Y-01: ComBtn meets androidTapTargetGuideline and labeledTapTargetGuideline',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _wrapInTestApp(
            ComBtn(
              semanticsLabel: '上一集',
              icon: const Icon(Icons.skip_previous, size: 22, color: Colors.white),
              fuc: () {},
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        // Check semantics node traits
        final semanticsNode = tester.getSemantics(find.byType(ComBtn));
        final data = semanticsNode.getSemanticsData();
        expect(data.label, equals('上一集'));
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);

        handle.dispose();
      },
    );

    testWidgets(
      'TC-A11Y-01: PlayOrPauseButton meets androidTapTargetGuideline & labeledTapTargetGuideline',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _wrapInTestApp(
            const PlayOrPauseButton(
              iconSize: 24,
              iconColor: Colors.white,
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        handle.dispose();
      },
    );

    testWidgets(
      'TC-A11Y-01: AdaptiveBottomControlRow with 48dp items meets guidelines',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        final controls = [
          BottomControlItem(
            type: BottomControlType.playOrPause,
            child: ComBtn(
              semanticsLabel: '播放',
              icon: const Icon(Icons.play_arrow, size: 22, color: Colors.white),
              fuc: () {},
            ),
          ),
          BottomControlItem(
            type: BottomControlType.next,
            child: ComBtn(
              semanticsLabel: '下一集',
              icon: const Icon(Icons.skip_next, size: 22, color: Colors.white),
              fuc: () {},
            ),
          ),
          BottomControlItem(
            type: BottomControlType.fullscreen,
            child: ComBtn(
              semanticsLabel: '全屏',
              icon: const Icon(Icons.fullscreen, size: 22, color: Colors.white),
              fuc: () {},
            ),
          ),
        ];

        await tester.pumpWidget(
          _wrapInTestApp(
            SizedBox(
              width: 300,
              height: 48,
              child: AdaptiveBottomControlRow(
                controls: controls,
                overflowButtonBuilder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        handle.dispose();
      },
    );

    // -------------------------------------------------------------------------
    // TC-A11Y-02: Player Header Controls Meet Tap Target, Labels & Text Contrast
    // -------------------------------------------------------------------------
    testWidgets(
      'TC-A11Y-02: PlayerHeaderActionRow meets androidTapTargetGuideline and labeledTapTargetGuideline',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        final headerRow = PlayerHeaderActionRow(
          backButton: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: '返回',
              icon: const FaIcon(
                FontAwesomeIcons.arrowLeft,
                size: 16,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
          ),
          homeButton: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: '返回主页',
              icon: const FaIcon(
                FontAwesomeIcons.house,
                size: 16,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
          ),
          isEquivalentFullScreen: true,
          expandedTitle: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '无障碍测试视频标题',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          compactActions: [
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: '画中画',
                onPressed: () {},
                icon: Icon(
                  MdiIcons.pictureInPictureBottomRight,
                  size: 21.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          moreButton: SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: '更多设置',
              onPressed: () {},
              icon: const Icon(
                Icons.more_vert_outlined,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        );

        await tester.pumpWidget(_wrapInTestApp(headerRow, canvasColor: Colors.black));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        handle.dispose();
      },
    );

    // -------------------------------------------------------------------------
    // TC-A11Y-03: Home Header Controls (DefaultUser & Search) Meet Guidelines
    // -------------------------------------------------------------------------
    testWidgets(
      'TC-A11Y-03: DefaultUser meets androidTapTargetGuideline and labeledTapTargetGuideline',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _wrapInTestApp(
            DefaultUser(callback: () {}),
            canvasColor: Colors.black87,
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        handle.dispose();
      },
    );

    // -------------------------------------------------------------------------
    // TC-A11Y-04: ActionItem & VideoCard Semantics Verification
    // -------------------------------------------------------------------------
    testWidgets(
      'TC-A11Y-04: ActionItem exposes button, selected state, and long press hint',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        bool tapped = false;
        bool longPressed = false;

        await tester.pumpWidget(
          _wrapInTestApp(
            Row(
              children: [
                ActionItem(
                  icon: const Icon(Icons.thumb_up_outlined),
                  selectIcon: const Icon(Icons.thumb_up),
                  selectStatus: true,
                  text: '1.2万',
                  semanticsLabel: '点赞',
                  loadingStatus: false,
                  onTap: () => tapped = true,
                  onLongPress: () => longPressed = true,
                ),
              ],
            ),
          ),
        );

        // Tap test
        await tester.tap(find.byType(ActionItem));
        expect(tapped, isTrue);

        await tester.longPress(find.byType(ActionItem));
        expect(longPressed, isTrue);

        // Verify semantics traits
        final semanticsNode = tester.getSemantics(find.byType(ActionItem));
        final data = semanticsNode.getSemanticsData();
        expect(data.label, equals('1.2万已点赞'));
        expect(data.hint, equals('长按一键三连'));
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasFlag(SemanticsFlag.isSelected), isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hasAction(SemanticsAction.longPress), isTrue);

        handle.dispose();
      },
    );

    testWidgets(
      'TC-A11Y-04: VideoCardV has button: true and onTap semantics action',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        final mockItem = RecVideoItemAppModel(
          title: '无障碍端到端测试视频',
          pic: 'https://example.com/pic.jpg',
          bvid: 'BV1a11yTest',
          aid: 123456,
          duration: 360,
          stat: RcmdStat(view: '10000', danmu: '500'),
          owner: RcmdOwner(name: '无障碍UP主', mid: 999),
          goto: 'av',
        );

        await tester.pumpWidget(
          _wrapInTestApp(
            SizedBox(
              width: 240,
              height: 280,
              child: VideoCardV(videoItem: mockItem),
            ),
          ),
        );

        final semantics = tester.getSemantics(
          find.descendant(
            of: find.byType(VideoCardV),
            matching: find.byType(Semantics),
          ).first,
        );
        final cardData = semantics.getSemanticsData();
        expect(cardData.flagsCollection.isButton, isTrue);
        expect(cardData.hasAction(SemanticsAction.tap), isTrue);

        handle.dispose();
      },
    );

    // -------------------------------------------------------------------------
    // TC-A11Y-05: ExcludeSemantics & ExcludeFocus Guard When Controls are Hidden
    // -------------------------------------------------------------------------
    testWidgets(
      'TC-A11Y-05: Hidden controls are pruned from semantics and focus trees',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        bool showControls = false;

        Widget buildOverlay() {
          return StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showControls = !showControls;
                      });
                    },
                    child: const Text('切换浮层显示'),
                  ),
                  ExcludeFocus(
                    excluding: !showControls,
                    child: ExcludeSemantics(
                      excluding: !showControls,
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: ComBtn(
                          semanticsLabel: '浮层中的播放按键',
                          icon: const Icon(Icons.play_arrow),
                          fuc: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        await tester.pumpWidget(_wrapInTestApp(buildOverlay()));

        // When showControls is false: ComBtn should NOT exist in the semantics tree
        expect(
          find.bySemanticsLabel('浮层中的播放按键'),
          findsNothing,
          reason: 'Hidden controls must be excluded from TalkBack semantics tree',
        );

        // Tap toggle button to show controls
        await tester.tap(find.text('切换浮层显示'));
        await tester.pumpAndSettle();

        // When showControls is true: ComBtn appears in the semantics tree
        expect(
          find.bySemanticsLabel('浮层中的播放按键'),
          findsOneWidget,
          reason: 'Visible controls must be discoverable by TalkBack',
        );

        handle.dispose();
      },
    );
  });
}

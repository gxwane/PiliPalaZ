import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/common_btn.dart';

void main() {
  testWidgets(
    'Lock button render test in Stack with Positioned width constraint',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Container(color: Colors.black),
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    width: 44,
                    child: Center(
                      child: Visibility(
                        visible: true,
                        child: ComBtn(
                          size: 44.0,
                          backgroundColor: const Color(0x73000000),
                          shape: const CircleBorder(),
                          icon: const FaIcon(
                            FontAwesomeIcons.lockOpen,
                            size: 16,
                            color: Colors.white,
                          ),
                          fuc: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ComBtn), findsOneWidget);
      expect(find.byType(FaIcon), findsOneWidget);

      bool tapped = false;
      // 重建或者直接在部件上加回调
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Container(color: Colors.black),
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    width: 44,
                    child: Center(
                      child: Visibility(
                        visible: true,
                        child: ComBtn(
                          size: 44.0,
                          backgroundColor: const Color(0x73000000),
                          shape: const CircleBorder(),
                          icon: const FaIcon(
                            FontAwesomeIcons.lockOpen,
                            size: 16,
                            color: Colors.white,
                          ),
                          fuc: () {
                            tapped = true;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final RenderBox renderBox = tester.renderObject(find.byType(ComBtn));
      final Offset globalPos = renderBox.localToGlobal(Offset.zero);
      final Size size = renderBox.size;
      expect(size, const Size(44.0, 44.0));
      expect(globalPos.dx, 16.0);
      expect(globalPos.dy, 78.0);

      await tester.tap(find.byType(ComBtn));
      expect(tapped, isTrue);
    },
  );
}

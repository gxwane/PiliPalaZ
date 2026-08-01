import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/app_bar_ani.dart';

void main() {
  testWidgets(
    'hidden controls start off-screen without a visible first frame',
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
      addTearDown(controller.dispose);

      Widget buildPlayerBar({required bool visible}) {
        return MaterialApp(
          home: AppBarAni(
            controller: controller,
            visible: visible,
            position: 'bottom',
            child: const PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Text('controls'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildPlayerBar(visible: false));

      expect(controller.value, 1);

      await tester.pumpWidget(buildPlayerBar(visible: true));
      expect(controller.status, AnimationStatus.reverse);
      await tester.pumpAndSettle();
      expect(controller.value, 0);

      await tester.pumpWidget(buildPlayerBar(visible: false));
      expect(controller.status, AnimationStatus.forward);
      await tester.pumpAndSettle();
      expect(controller.value, 1);
    },
  );
}

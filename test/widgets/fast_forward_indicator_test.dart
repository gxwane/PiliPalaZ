import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/fast_forward_indicator.dart';

void main() {
  group('FastForwardIndicator Widget Tests', () {
    testWidgets('renders SizedBox.shrink when speed is 0.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FastForwardIndicator(speed: 0.0)),
        ),
      );

      expect(find.textContaining('X'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FastForwardIndicator),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
      );
    });

    testWidgets('renders formatted speed and pill when speed is 2.0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FastForwardIndicator(speed: 2.0)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('2.0X'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FastForwardIndicator),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
      expect(find.byType(IgnorePointer), findsWidgets);

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(FastForwardIndicator),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('formats non-integer speeds correctly (e.g. 2.3X)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FastForwardIndicator(speed: 2.3)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('2.30X'), findsOneWidget);
    });

    testWidgets('smoothly animates in when speed changes from 0 to 3.0', (
      tester,
    ) async {
      double currentSpeed = 0.0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(body: FastForwardIndicator(speed: currentSpeed)),
            );
          },
        ),
      );

      expect(find.textContaining('X'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FastForwardIndicator(speed: 3.0)),
        ),
      );

      // Animation midway
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text('3.0X'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('3.0X'), findsOneWidget);
    });

    testWidgets('smoothly animates out when speed changes from 2.0 to 0.0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FastForwardIndicator(speed: 2.0)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('2.0X'), findsOneWidget);

      // Speed resets to 0.0
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FastForwardIndicator(speed: 0.0)),
        ),
      );

      // Midway through exit animation: text is still retained
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.text('2.0X'), findsOneWidget);

      // After exit animation finishes
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('X'), findsNothing);
    });
  });
}

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/member/info.dart';

Widget _buildProfileHeaderRow(Card? card) {
  return MaterialApp(
    home: Scaffold(
      body: Row(
        children: [
          Flexible(
            child: Text(
              card?.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (card?.level case final level? when level >= 0 && level <= 6) ...[
            const SizedBox(width: 4),
            Image.asset(
              'assets/images/lv/lv$level.png',
              height: 11,
              semanticLabel: '等级$level',
            ),
          ],
          if (card?.vip?.status == 1) ...[const SizedBox(width: 6)],
        ],
      ),
    ),
  );
}

void main() {
  group('Member level header widget rendering tests', () {
    testWidgets('renders lv6.png and 4dp spacing for level 6 user', (
      tester,
    ) async {
      final card = Card(name: '测试用户', level: 6);
      await tester.pumpWidget(_buildProfileHeaderRow(card));

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(
        (imageWidget.image as AssetImage).assetName,
        'assets/images/lv/lv6.png',
      );
      expect(imageWidget.semanticLabel, '等级6');

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((box) => box.width == 4), isTrue);
    });

    testWidgets('renders lv0.png and 4dp spacing for level 0 user', (
      tester,
    ) async {
      final card = Card(name: '零级用户', level: 0);
      await tester.pumpWidget(_buildProfileHeaderRow(card));

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(
        (imageWidget.image as AssetImage).assetName,
        'assets/images/lv/lv0.png',
      );
      expect(imageWidget.semanticLabel, '等级0');
    });

    testWidgets(
      'omits level image and 4dp spacing when level is null (no phantom spacing)',
      (tester) async {
        final card = Card(name: '无等级用户', level: null);
        await tester.pumpWidget(_buildProfileHeaderRow(card));

        expect(find.byType(Image), findsNothing);
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.any((box) => box.width == 4), isFalse);
      },
    );

    testWidgets(
      'safely omits level image when level is out of bounds (level 7)',
      (tester) async {
        final card = Card(name: '超阶用户', level: 7);
        await tester.pumpWidget(_buildProfileHeaderRow(card));

        expect(find.byType(Image), findsNothing);
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.any((box) => box.width == 4), isFalse);
      },
    );
  });
}

import 'package:dismissible_page/dismissible_page.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/pages/preview/view.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('ImagePreview renders DismissiblePage and single image UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImagePreview(
          initialPage: 0,
          imgList: ['https://example.com/single.jpg'],
          heroTags: ['hero_single_0'],
        ),
      ),
    );
    await tester.pump();

    // Verifies DismissiblePage wraps the view
    expect(find.byType(DismissiblePage), findsOneWidget);
    final DismissiblePage dismissible =
        tester.widget(find.byType(DismissiblePage));
    expect(dismissible.direction, equals(DismissiblePageDismissDirection.down));
    expect(dismissible.disabled, isFalse);

    // Verifies ExtendedImageGesturePageView is used
    expect(find.byType(ExtendedImageGesturePageView), findsOneWidget);

    // Verifies Close button exists
    expect(find.byTooltip('关闭'), findsOneWidget);

    // Single image does not show page counter
    expect(find.text(' / '), findsNothing);
  });

  testWidgets('ImagePreview renders multiple images and page counter',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImagePreview(
          initialPage: 0,
          imgList: [
            'https://example.com/1.jpg',
            'https://example.com/2.jpg',
            'https://example.com/3.jpg',
          ],
          heroTags: [
            'hero_1',
            'hero_2',
            'hero_3',
          ],
        ),
      ),
    );
    await tester.pump();

    // Verifies Page indicator shows '1 / 3'
    expect(find.text('1 / 3'), findsOneWidget);
  });
}

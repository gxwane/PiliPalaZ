import 'package:dismissible_page/dismissible_page.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('ImagePreview renders DismissiblePage and single image UI', (
    WidgetTester tester,
  ) async {
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
    final DismissiblePage dismissible = tester.widget(
      find.byType(DismissiblePage),
    );
    expect(dismissible.direction, equals(DismissiblePageDismissDirection.down));
    expect(dismissible.disabled, isFalse);

    // Verifies ExtendedImageGesturePageView is used
    expect(find.byType(ExtendedImageGesturePageView), findsOneWidget);

    // Verifies Close button exists
    expect(find.byTooltip('关闭'), findsOneWidget);

    // Single image does not show page counter
    expect(find.text(' / '), findsNothing);
  });

  testWidgets('ImagePreview renders multiple images and page counter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImagePreview(
          initialPage: 0,
          imgList: [
            'https://example.com/1.jpg',
            'https://example.com/2.jpg',
            'https://example.com/3.jpg',
          ],
          heroTags: ['hero_1', 'hero_2', 'hero_3'],
        ),
      ),
    );
    await tester.pump();

    // Verifies Page indicator shows '1 / 3'
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets(
    'ImagePreview toggles DismissiblePage.disabled on multi-pointer touch',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImagePreview(
            initialPage: 0,
            imgList: ['https://example.com/test_pointer.jpg'],
          ),
        ),
      );
      await tester.pump();

      DismissiblePage dismissible = tester.widget<DismissiblePage>(
        find.byType(DismissiblePage),
      );
      expect(dismissible.disabled, isFalse);
      expect(dismissible.dragStartBehavior, equals(DragStartBehavior.start));

      // Multi-touch simulation
      final TestGesture gesture1 = await tester.startGesture(
        tester.getCenter(find.byType(ImagePreview)),
      );
      await tester.pump();

      dismissible = tester.widget<DismissiblePage>(
        find.byType(DismissiblePage),
      );
      // Single finger should NOT disable dismiss
      expect(dismissible.disabled, isFalse);

      final TestGesture gesture2 = await tester.startGesture(
        tester.getCenter(find.byType(ImagePreview)) + const Offset(50, 50),
      );
      await tester.pump();

      dismissible = tester.widget<DismissiblePage>(
        find.byType(DismissiblePage),
      );
      // 2 fingers MUST disable dismiss to avoid gesture conflict
      expect(dismissible.disabled, isTrue);

      // Release second finger
      await gesture2.up();
      await tester.pump();

      dismissible = tester.widget<DismissiblePage>(
        find.byType(DismissiblePage),
      );
      // Returned to 1 finger unzoomed -> dismiss re-enabled
      expect(dismissible.disabled, isFalse);

      await gesture1.up();
      await tester.pump();
    },
  );

  testWidgets(
    'ImagePreview handles PointerCancelEvent cleanly without pointer leak',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImagePreview(
            initialPage: 0,
            imgList: ['https://example.com/test_cancel.jpg'],
          ),
        ),
      );
      await tester.pump();

      final TestGesture gesture1 = await tester.startGesture(
        tester.getCenter(find.byType(ImagePreview)),
      );
      final TestGesture gesture2 = await tester.startGesture(
        tester.getCenter(find.byType(ImagePreview)) + const Offset(50, 50),
      );
      await tester.pump();

      DismissiblePage dismissible = tester.widget<DismissiblePage>(
        find.byType(DismissiblePage),
      );
      expect(dismissible.disabled, isTrue);

      // Cancel gesture2 (e.g. system interrupt / palm rejection)
      await gesture2.cancel();
      await tester.pump();

      dismissible = tester.widget<DismissiblePage>(
        find.byType(DismissiblePage),
      );
      // Pointer cleanly removed -> disabled is false
      expect(dismissible.disabled, isFalse);

      await gesture1.cancel();
      await tester.pump();
    },
  );

  testWidgets(
    'ImagePreview wraps child in KeyedSubtree with a GlobalKey',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImagePreview(
            initialPage: 0,
            imgList: ['https://example.com/test_key.jpg'],
          ),
        ),
      );
      await tester.pump();

      final Finder keyedSubtreeFinder = find.byType(KeyedSubtree);
      expect(keyedSubtreeFinder, findsWidgets);

      // Verify at least one KeyedSubtree has a GlobalKey protecting Scaffold
      final Iterable<KeyedSubtree> subtrees =
          tester.widgetList<KeyedSubtree>(keyedSubtreeFinder);
      final bool hasGlobalKey = subtrees.any((s) => s.key is GlobalKey);
      expect(hasGlobalKey, isTrue);
    },
  );

  testWidgets(
    'ExtendedImage receives gestureDetailsIsChanged in GestureConfig',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImagePreview(
            initialPage: 0,
            imgList: ['https://example.com/test_scale_config.jpg'],
          ),
        ),
      );
      await tester.pump();

      final ExtendedImage imageWidget =
          tester.widget<ExtendedImage>(find.byType(ExtendedImage));
      expect(imageWidget.initGestureConfigHandler, isNotNull);

      final ExtendedImageState state =
          tester.state(find.byType(ExtendedImage)) as ExtendedImageState;
      final GestureConfig config =
          imageWidget.initGestureConfigHandler!(state);

      expect(config.gestureDetailsIsChanged, isNotNull);
      expect(config.maxScale, equals(15.0));

      // Simulate scale change > 1.001
      config.gestureDetailsIsChanged!(GestureDetails(totalScale: 2.0));
      await tester.pump();
      await tester.pump();

      DismissiblePage dismissible =
          tester.widget<DismissiblePage>(find.byType(DismissiblePage));
      expect(dismissible.disabled, isTrue);

      // Simulate scale change back to 1.0
      config.gestureDetailsIsChanged!(GestureDetails(totalScale: 1.0));
      await tester.pump();
      await tester.pump();

      dismissible =
          tester.widget<DismissiblePage>(find.byType(DismissiblePage));
      expect(dismissible.disabled, isFalse);
    },
  );
}

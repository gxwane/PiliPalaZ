import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/utils/screen_utils.dart';
import 'package:pilipalaz/utils/storage.dart';
import '../journeys/support/journey_test_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenUtils Tests', () {
    setUpAll(() async {
      await initTestStorage();
    });

    testWidgets('isTablet correctly identifies phone vs tablet breakpoints', (
      WidgetTester tester,
    ) async {
      // 1. Standard mobile phone (390 x 844)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (BuildContext context) {
              expect(ScreenUtils.isTablet(context), isFalse);
              return const SizedBox();
            },
          ),
        ),
      );

      // 2. Near breakpoint boundary (599 x 900)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(599, 900)),
          child: Builder(
            builder: (BuildContext context) {
              expect(ScreenUtils.isTablet(context), isFalse);
              return const SizedBox();
            },
          ),
        ),
      );

      // 3. Exact tablet breakpoint (600 x 960)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(600, 960)),
          child: Builder(
            builder: (BuildContext context) {
              expect(ScreenUtils.isTablet(context), isTrue);
              return const SizedBox();
            },
          ),
        ),
      );

      // 4. Large landscape tablet (1280 x 800)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: Builder(
            builder: (BuildContext context) {
              expect(ScreenUtils.isTablet(context), isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('shouldUseLandscapeDualColumn protects regular phones', (
      WidgetTester tester,
    ) async {
      // Ensure horizontalScreen setting is false
      GStorage.setting.put(SettingBoxKey.horizontalScreen, false);

      // 1. Regular smartphone in landscape (850 x 390, ratio 2.17, shortestSide 390)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(850, 390)),
          child: Builder(
            builder: (BuildContext context) {
              final BoxConstraints phoneLandscape = const BoxConstraints(
                maxWidth: 850,
                maxHeight: 390,
              );
              expect(
                ScreenUtils.shouldUseLandscapeDualColumn(
                  context,
                  phoneLandscape,
                ),
                isFalse,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      // 2. Tablet in landscape (1280 x 800, shortestSide 800 >= 600)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: Builder(
            builder: (BuildContext context) {
              final BoxConstraints tabletLandscape = const BoxConstraints(
                maxWidth: 1280,
                maxHeight: 800,
              );
              expect(
                ScreenUtils.shouldUseLandscapeDualColumn(
                  context,
                  tabletLandscape,
                ),
                isTrue,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      // 3. Ultra-wide or desktop freeform window (maxWidth >= 900)
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(960, 500)),
          child: Builder(
            builder: (BuildContext context) {
              final BoxConstraints desktopWindow = const BoxConstraints(
                maxWidth: 960,
                maxHeight: 500,
              );
              expect(
                ScreenUtils.shouldUseLandscapeDualColumn(
                  context,
                  desktopWindow,
                ),
                isTrue,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      // 4. Smartphone with user-opted horizontalScreen setting
      GStorage.setting.put(SettingBoxKey.horizontalScreen, true);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(850, 390)),
          child: Builder(
            builder: (BuildContext context) {
              final BoxConstraints phoneLandscape = const BoxConstraints(
                maxWidth: 850,
                maxHeight: 390,
              );
              expect(
                ScreenUtils.shouldUseLandscapeDualColumn(
                  context,
                  phoneLandscape,
                ),
                isTrue,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      GStorage.setting.put(SettingBoxKey.horizontalScreen, false);
    });

    test('isSquarish correctly detects foldable unfolded dimensions', () {
      // Foldable unfolded (e.g. Galaxy Z Fold: 700 x 800, ratio 0.875)
      expect(
        ScreenUtils.isSquarish(
          const BoxConstraints(maxWidth: 700, maxHeight: 800),
        ),
        isTrue,
      );

      // Square window (800 x 800, ratio 1.0)
      expect(
        ScreenUtils.isSquarish(
          const BoxConstraints(maxWidth: 800, maxHeight: 800),
        ),
        isTrue,
      );

      // Standard mobile portrait (390 x 844, ratio 0.46, maxWidth < 600)
      expect(
        ScreenUtils.isSquarish(
          const BoxConstraints(maxWidth: 390, maxHeight: 844),
        ),
        isFalse,
      );

      // Standard landscape tablet (1280 x 800, ratio 1.6 >= 1.25)
      expect(
        ScreenUtils.isSquarish(
          const BoxConstraints(maxWidth: 1280, maxHeight: 800),
        ),
        isFalse,
      );
    });

    test(
      'isTabletDevice executes safely without throwing in headless mode',
      () {
        // Must not throw StateError or unhandled exception
        expect(() => ScreenUtils.isTabletDevice(), returnsNormally);
      },
    );
  });
}

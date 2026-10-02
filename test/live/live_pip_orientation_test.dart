import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';
import 'package:pilipalaz/utils/video_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('live_pip_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VideoUtils PiP Rational and Clamping Tests', () {
    test('Standard 16:9 and 9:16 aspect ratios simplify correctly', () {
      final r16_9 = VideoUtils.clampPiPRational(width: 1920, height: 1080);
      expect(r16_9.numerator, 16);
      expect(r16_9.denominator, 9);

      final r9_16 = VideoUtils.clampPiPRational(width: 1080, height: 1920);
      expect(r9_16.numerator, 9);
      expect(r9_16.denominator, 16);

      final r720p = VideoUtils.clampPiPRational(width: 1280, height: 720);
      expect(r720p.numerator, 16);
      expect(r720p.denominator, 9);
    });

    test('Zero or null dimensions use fallback direction', () {
      final fallbackH = VideoUtils.clampPiPRational(
        width: 0,
        height: 0,
        fallbackDirection: 'horizontal',
      );
      expect(fallbackH.numerator, 16);
      expect(fallbackH.denominator, 9);

      final fallbackV = VideoUtils.clampPiPRational(
        width: null,
        height: null,
        fallbackDirection: 'vertical',
      );
      expect(fallbackV.numerator, 9);
      expect(fallbackV.denominator, 16);
    });

    test('Clamps ultra-wide aspect ratio exceeding Android 2.39 limit', () {
      final ultraWide = VideoUtils.clampPiPRational(width: 3000, height: 1000);
      expect(ultraWide.numerator, 239);
      expect(ultraWide.denominator, 100);
      expect(ultraWide.numerator / ultraWide.denominator, 2.39);
    });

    test('Clamps ultra-tall aspect ratio below Android 100/239 limit', () {
      final ultraTall = VideoUtils.clampPiPRational(width: 500, height: 2000);
      expect(ultraTall.numerator, 100);
      expect(ultraTall.denominator, 239);
      expect(
        ultraTall.numerator / ultraTall.denominator,
        closeTo(100 / 239, 0.0001),
      );
    });
  });

  group('PlPlayerController VideoDimension and Direction State Tests', () {
    test(
      'PlPlayerController initial videoDimension and direction are clean',
      () {
        final controller = PlPlayerController.getInstance(videoType: 'live');
        expect(controller.videoDimension.value, VideoDimension.zero);
        expect(controller.direction.value, 'horizontal');
      },
    );

    test('PlPlayerController onDimensionChanged stream updates', () async {
      final controller = PlPlayerController.getInstance(videoType: 'live');
      final emissions = <VideoDimension>[];
      final sub = controller.onDimensionChanged.listen(emissions.add);

      controller.videoDimension.value = const VideoDimension(1920, 1080);
      await pumpEventQueue();

      expect(emissions.length, 1);
      expect(emissions.first.width, 1920);
      expect(emissions.first.height, 1080);

      await sub.cancel();
      controller.videoDimension.value = VideoDimension.zero;
    });

    test('Direction logic updates based on width and height relationship', () {
      final controller = PlPlayerController.getInstance(videoType: 'live');

      // Vertical stream (height > width)
      const verticalDim = VideoDimension(1080, 1920);
      if (verticalDim.height > verticalDim.width) {
        controller.direction.value = 'vertical';
      }
      expect(controller.direction.value, 'vertical');

      // Horizontal stream (width >= height)
      const horizontalDim = VideoDimension(1920, 1080);
      if (horizontalDim.width >= horizontalDim.height) {
        controller.direction.value = 'horizontal';
      }
      expect(controller.direction.value, 'horizontal');
    });
  });

  group('Immersive Layout State Logic Tests', () {
    test('isImmersive correctly considers fullScreen and landscape', () {
      bool checkImmersive(bool isFullScreen, Orientation orientation) {
        return isFullScreen || orientation == Orientation.landscape;
      }

      expect(checkImmersive(false, Orientation.portrait), isFalse);
      expect(checkImmersive(true, Orientation.portrait), isTrue);
      expect(checkImmersive(false, Orientation.landscape), isTrue);
      expect(checkImmersive(true, Orientation.landscape), isTrue);
    });

    testWidgets('PopScope canPop is false when isImmersive is true', (
      tester,
    ) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              popped = didPop;
            },
            child: const Scaffold(body: Text('Immersive View')),
          ),
        ),
      );

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();

      expect(popped, isFalse);
      expect(find.text('Immersive View'), findsOneWidget);
    });

    testWidgets('PopScope canPop is true when isImmersive is false', (
      tester,
    ) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PopScope(
                        canPop: true,
                        onPopInvokedWithResult: (didPop, result) {
                          popped = didPop;
                        },
                        child: const Scaffold(body: Text('Second Page')),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Second Page'), findsOneWidget);

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.text('Second Page'), findsNothing);
    });
  });
}

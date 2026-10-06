import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/video/play/chapter.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/services/audio_handler.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';
import 'package:pilipalaz/utils/utils.dart';

final class _TestPlaybackAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    audioSessionHandler = _TestPlaybackAudioSession();
    tempDir = await Directory.systemTemp.createTemp(
      'pilipalaz-chapter-integration-test-',
    );
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
    videoPlayerServiceHandler = VideoPlayerServiceHandler(
      settingBox: GStorage.setting,
    );
  });

  tearDownAll(() async {
    await PlPlayerController.disposeIfExists();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PlPlayerController Chapter Reactive State Tests', () {
    late PlPlayerController controller;

    setUp(() {
      Get.testMode = true;
      PlPlayerController.isHeadlessTestMode = true;
      controller = PlPlayerController.getInstance();
    });

    tearDown(() async {
      await PlPlayerController.disposeIfExists();
      Get.reset();
    });

    test('initial chapter state is empty and safe', () {
      expect(controller.chapters, isEmpty);
      expect(controller.currentChapter.value, isNull);
      expect(controller.chapterSplitPoints, isEmpty);
    });

    test(
      'updateCurrentChapter accurately tracks chapter intervals and boundaries',
      () {
        final chapters = [
          const VideoChapter(from: 0, to: 60, title: '第1章: 开场'),
          const VideoChapter(from: 60, to: 150, title: '第2章: 核心架构'),
          const VideoChapter(from: 150, to: 300, title: '第3章: 总结与展望'),
        ];

        controller.chapters.assignAll(chapters);
        controller.durationSeconds.value = 300;

        expect(controller.chapterSplitPoints, [
          const Duration(seconds: 60),
          const Duration(seconds: 150),
        ]);

        // At second 0 (start of chapter 1)
        controller.updateCurrentChapter(0);
        expect(controller.currentChapter.value?.title, '第1章: 开场');

        // At second 59 (end of chapter 1)
        controller.updateCurrentChapter(59);
        expect(controller.currentChapter.value?.title, '第1章: 开场');

        // At second 60 (start of chapter 2)
        controller.updateCurrentChapter(60);
        expect(controller.currentChapter.value?.title, '第2章: 核心架构');

        // At second 149
        controller.updateCurrentChapter(149);
        expect(controller.currentChapter.value?.title, '第2章: 核心架构');

        // At second 150 (start of chapter 3)
        controller.updateCurrentChapter(150);
        expect(controller.currentChapter.value?.title, '第3章: 总结与展望');

        // At second 300 (inclusive end of last chapter)
        controller.updateCurrentChapter(300);
        expect(controller.currentChapter.value?.title, '第3章: 总结与展望');

        // Beyond duration
        controller.updateCurrentChapter(301);
        expect(controller.currentChapter.value, isNull);
      },
    );

    test('clearing chapters resets currentChapter gracefully', () {
      controller.chapters.assignAll([
        const VideoChapter(from: 0, to: 100, title: '唯一分段'),
      ]);
      controller.durationSeconds.value = 100;
      controller.updateCurrentChapter(50);
      expect(controller.currentChapter.value?.title, '唯一分段');

      controller.chapters.clear();
      controller.updateCurrentChapter(50);
      expect(controller.currentChapter.value, isNull);
      expect(controller.chapterSplitPoints, isEmpty);
    });
  });

  group('Chapter Seek HUD Widget Reactive Tests', () {
    testWidgets('renders chapter title in seek HUD when chapter is active', (
      tester,
    ) async {
      PlPlayerController.isHeadlessTestMode = true;
      final controller = PlPlayerController.getInstance();
      controller.chapters.assignAll([
        const VideoChapter(from: 0, to: 100, title: '测试分段标题'),
      ]);
      controller.durationSeconds.value = 100;
      controller.sliderPositionSeconds.value = 45;
      controller.updateCurrentChapter(45);

      const textStyle = TextStyle(color: Colors.white, fontSize: 12);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => Text(
                      Utils.timeFormat(controller.sliderPositionSeconds.value),
                      style: textStyle,
                    ),
                  ),
                  const Text(' / ', style: textStyle),
                  Obx(
                    () => Text(
                      Utils.timeFormat(controller.durationSeconds.value),
                      style: textStyle,
                    ),
                  ),
                  Obx(() {
                    final chapter = controller.currentChapter.value;
                    if (chapter == null || chapter.title.isEmpty) {
                      return const SizedBox();
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 6),
                        const Text('·', style: textStyle),
                        const SizedBox(width: 6),
                        Text(chapter.title, style: textStyle),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('01:40'), findsOneWidget);
      expect(find.text('测试分段标题'), findsOneWidget);

      // Switching to a second without chapter clears the title
      controller.updateCurrentChapter(150);
      await tester.pump();
      expect(find.text('测试分段标题'), findsNothing);
      await PlPlayerController.disposeIfExists();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/pages/live_room/controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_audio_only_card.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/services/audio_handler.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('live_audio_mode_test_');
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

  group('VideoPlayerServiceHandler Live Controls Tests', () {
    test(
      'onLiveDetailChange sets isLiveStream and live mediaItem metadata',
      () {
        final handler = VideoPlayerServiceHandler(settingBox: GStorage.setting);
        handler.onLiveDetailChange(
          title: '测试直播间标题',
          anchorName: '测试主播',
          coverUrl: 'https://example.com/cover.jpg',
          roomId: '12345',
        );

        expect(handler.isLiveStream, isTrue);
        expect(handler.mediaItem.value, isNotNull);
        expect(handler.mediaItem.value!.title, '测试直播间标题');
        expect(handler.mediaItem.value!.artist, '测试主播');
        expect(handler.mediaItem.value!.album, '直播间 12345');
        expect(handler.mediaItem.value!.duration, Duration.zero);
      },
    );

    test('Live playback state trims controls to play/pause only', () {
      final handler = VideoPlayerServiceHandler(settingBox: GStorage.setting);
      handler.onLiveDetailChange(
        title: '正在直播',
        anchorName: '主播A',
        coverUrl: '',
        roomId: '888',
      );

      handler.onStatusChange(PlayerStatus.playing, false);

      final state = handler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.androidCompactActionIndices, [0]);
      expect(state.controls.length, 2);
      expect(state.controls[0], MediaControl.pause);
      expect(state.controls[1], MediaControl.stop);
      expect(state.systemActions, contains(MediaAction.pause));
      expect(state.systemActions, contains(MediaAction.stop));
      expect(state.systemActions.contains(MediaAction.seek), isFalse);
      expect(state.systemActions.contains(MediaAction.seekForward), isFalse);
    });

    test(
      'onVideoDetailChange resets isLiveStream and restores full controls',
      () {
        final handler = VideoPlayerServiceHandler(settingBox: GStorage.setting);
        // First in live state
        handler.onLiveDetailChange(
          title: '直播',
          anchorName: '主播',
          coverUrl: '',
          roomId: '1',
        );
        expect(handler.isLiveStream, isTrue);

        // Transition to video
        handler.onVideoDetailChange(
          '普通视频',
          'UP主',
          const Duration(minutes: 5),
          null,
        );
        expect(handler.isLiveStream, isFalse);

        handler.onStatusChange(PlayerStatus.playing, false);
        final state = handler.playbackState.value;
        expect(state.androidCompactActionIndices, [0, 1, 2]);
        expect(state.systemActions, contains(MediaAction.seek));
      },
    );

    test('clearImpl and stop reset isLiveStream to false', () async {
      final handler = VideoPlayerServiceHandler(settingBox: GStorage.setting);
      handler.onLiveDetailChange(
        title: '直播',
        anchorName: '主播',
        coverUrl: '',
        roomId: '99',
      );
      expect(handler.isLiveStream, isTrue);

      handler.clearImpl();
      expect(handler.isLiveStream, isFalse);
      expect(handler.mediaItem.value, isNull);

      handler.onLiveDetailChange(
        title: '直播2',
        anchorName: '主播2',
        coverUrl: '',
        roomId: '100',
      );
      expect(handler.isLiveStream, isTrue);

      await handler.stop();
      expect(handler.isLiveStream, isFalse);
    });
  });

  group('LiveRoomController Audio-Only State Machine Tests', () {
    test('isAudioOnly defaults to false and toggles correctly', () {
      final controller = LiveRoomController();
      expect(controller.isAudioOnly.value, isFalse);

      controller.toggleAudioOnly();
      expect(controller.isAudioOnly.value, isTrue);
      expect(controller.plPlayerController.onlyPlayAudio.value, isTrue);

      controller.toggleAudioOnly();
      expect(controller.isAudioOnly.value, isFalse);
      expect(controller.plPlayerController.onlyPlayAudio.value, isFalse);

      controller.onClose();
    });

    test('switchRoom resets isAudioOnly and onlyPlayAudio', () async {
      final controller = LiveRoomController();
      controller.toggleAudioOnly();
      expect(controller.isAudioOnly.value, isTrue);

      await controller.switchRoom(
        999,
        item: LiveItemModel(roomId: 999, uname: '新主播'),
      );
      expect(controller.isAudioOnly.value, isFalse);
      expect(controller.plPlayerController.onlyPlayAudio.value, isFalse);

      controller.onClose();
    });

    test('onClose cleans up onlyPlayAudio safely', () {
      final controller = LiveRoomController();
      controller.toggleAudioOnly();
      expect(controller.plPlayerController.onlyPlayAudio.value, isTrue);

      controller.onClose();
      expect(controller.plPlayerController.onlyPlayAudio.value, isFalse);
    });
  });

  group('LiveAudioOnlyCard Widget Tests', () {
    testWidgets('renders anchor name, audio status badge and restore button', (
      WidgetTester tester,
    ) async {
      final controller = LiveRoomController();
      controller.cover = 'https://example.com/cover.jpg';
      controller.liveItem = LiveItemModel(
        roomId: 1001,
        uname: '测试歌手主播',
        cover: 'https://example.com/cover.jpg',
      );

      final plPlayerController = PlPlayerController.getInstance(
        videoType: 'live',
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 240,
              child: LiveAudioOnlyCard(
                controller: controller,
                playerController: plPlayerController,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('测试歌手主播'), findsOneWidget);
      expect(find.text('听直播模式 · 低功耗运行'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('restore_video_button')),
        findsOneWidget,
      );

      // Test tapping restore video button
      await tester.tap(find.byKey(const ValueKey('restore_video_button')));
      await tester.pump();

      expect(
        controller.isAudioOnly.value,
        isTrue,
      ); // toggled from false to true

      controller.onClose();
    });

    testWidgets('renders exit fullscreen button when player is in fullscreen', (
      WidgetTester tester,
    ) async {
      final controller = LiveRoomController();
      final plPlayerController = PlPlayerController.getInstance(
        videoType: 'live',
      );
      plPlayerController.isFullScreen.value = true;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: LiveAudioOnlyCard(
                controller: controller,
                playerController: plPlayerController,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.byKey(const ValueKey('audio_mode_exit_fullscreen')),
        findsOneWidget,
      );

      controller.onClose();
      plPlayerController.isFullScreen.value = false;
    });
  });
}

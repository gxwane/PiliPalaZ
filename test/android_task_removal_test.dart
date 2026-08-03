import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/services/audio_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android task removal', () {
    late Directory hiveDirectory;
    late Box<dynamic> settingBox;

    setUpAll(() async {
      hiveDirectory = await Directory.systemTemp.createTemp(
        'pilipalaz_android_task_removal_test_',
      );
      Hive.init(hiveDirectory.path);
      settingBox = await Hive.openBox<dynamic>('settings');
    });

    tearDownAll(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    test('releases the player and stops the media service', () async {
      var releaseCount = 0;
      final handler = VideoPlayerServiceHandler(
        settingBox: settingBox,
        releasePlayer: () async {
          releaseCount++;
        },
      );
      handler.playbackState.add(
        handler.playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
      handler.mediaItem.add(
        const MediaItem(id: 'test-video', title: 'Test video'),
      );

      await handler.onTaskRemoved();

      expect(releaseCount, 1);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.mediaItem.value, isNull);
    });

    test('stops the media service when no player exists', () async {
      final handler = VideoPlayerServiceHandler(
        settingBox: settingBox,
        releasePlayer: () async {},
      );
      handler.playbackState.add(
        handler.playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );

      await handler.onTaskRemoved();

      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      expect(handler.playbackState.value.playing, isFalse);
    });

    test('still stops the service when player release fails', () async {
      final releaseError = StateError('release failed');
      final handler = VideoPlayerServiceHandler(
        settingBox: settingBox,
        releasePlayer: () async => throw releaseError,
      );
      handler.playbackState.add(
        handler.playbackState.value.copyWith(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
      handler.mediaItem.add(
        const MediaItem(id: 'test-video', title: 'Test video'),
      );

      await expectLater(handler.onTaskRemoved(), throwsA(same(releaseError)));

      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
      expect(handler.playbackState.value.playing, isFalse);
      expect(handler.mediaItem.value, isNull);
    });

    test('disposing a missing player is safe', () async {
      expect(PlPlayerController.instanceExists(), isFalse);

      await PlPlayerController.disposeIfExists();

      expect(PlPlayerController.instanceExists(), isFalse);
    });
  });
}

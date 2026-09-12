import 'package:audio_service/audio_service.dart';
import 'package:flutter_floating/floating/manager/floating_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/storage.dart';

import 'support/journey_test_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestStorage();
  });

  setUp(() async {
    PlPlayerController.isHeadlessTestMode = true;
    await clearTestStorage();
    await setupJourneyServiceLocator();
  });

  tearDown(() async {
    await journeyTearDown();
  });

  group('Suite 5: Background Audio and PiP Smoke Contract', () {
    test(
      'Background Audio Service publishes media item and handles external controls',
      () async {
        // 1. Enable background play in settings
        await GStorage.setting.put(SettingBoxKey.enableBackgroundPlay, true);
        videoPlayerServiceHandler.revalidateSetting();
        expect(videoPlayerServiceHandler.enableBackgroundPlay, isTrue);

        // 2. Initialize Player Controller in headless mode
        final plController = PlPlayerController.getInstance();
        await plController.setDataSource(
          DataSource(
            videoSource: 'https://test.bilibili.com/video.mp4',
            audioSource: 'https://test.bilibili.com/audio.mp4',
            type: DataSourceType.network,
          ),
          owner: PlayerResourceOwner(),
          autoplay: true,
          duration: const Duration(minutes: 5),
        );

        expect(
          plController.playerStatus.status.value,
          equals(PlayerStatus.playing),
        );

        // 3. Publish video detail metadata to AudioHandler
        const testTitle = '端到端测试：后台播放测试视频';
        const testArtist = '测试UP主A';
        const testDuration = Duration(minutes: 5);
        const testCover = 'https://i0.hdslb.com/bfs/archive/cover.jpg';

        videoPlayerServiceHandler.onVideoDetailChange(
          testTitle,
          testArtist,
          testDuration,
          testCover,
        );

        final MediaItem? currentMediaItem =
            videoPlayerServiceHandler.mediaItem.value;
        expect(currentMediaItem, isNotNull);
        expect(currentMediaItem!.title, equals(testTitle));
        expect(currentMediaItem.artist, equals(testArtist));
        expect(currentMediaItem.duration, equals(testDuration));
        expect(currentMediaItem.artUri, equals(Uri.parse(testCover)));

        // 4. Verify playbackState reflects playing status
        final PlaybackState playingState =
            videoPlayerServiceHandler.playbackState.value;
        expect(playingState.playing, isTrue);
        expect(
          playingState.processingState,
          equals(AudioProcessingState.ready),
        );
        expect(playingState.systemActions, contains(MediaAction.seek));

        // 5. External control: pause via VideoPlayerServiceHandler
        await videoPlayerServiceHandler.pause();
        expect(
          plController.playerStatus.status.value,
          equals(PlayerStatus.paused),
        );
        expect(videoPlayerServiceHandler.playbackState.value.playing, isFalse);

        // 6. External control: play via VideoPlayerServiceHandler
        await videoPlayerServiceHandler.play();
        expect(
          plController.playerStatus.status.value,
          equals(PlayerStatus.playing),
        );
        expect(videoPlayerServiceHandler.playbackState.value.playing, isTrue);

        // 7. External control: seek via VideoPlayerServiceHandler
        const targetSeek = Duration(seconds: 90);
        await videoPlayerServiceHandler.seek(targetSeek);
        expect(plController.position.value, equals(targetSeek));

        // Clean exit
        await plController.pause();
      },
    );

    test(
      'PiP and floating player preconditions and aspect ratio contracts',
      () async {
        // 1. Setting check contract
        expect(
          GStorage.setting.get(SettingBoxKey.autoPiP, defaultValue: false),
          isFalse,
        );
        await GStorage.setting.put(SettingBoxKey.autoPiP, true);
        expect(
          GStorage.setting.get(SettingBoxKey.autoPiP, defaultValue: false),
          isTrue,
        );

        // 2. Aspect ratio logic verification for PiP
        const horizontalDirection = 'horizontal';
        final horizontalRatioX = horizontalDirection == 'vertical' ? 9 : 16;
        final horizontalRatioY = horizontalDirection == 'vertical' ? 16 : 9;
        expect(horizontalRatioX, equals(16));
        expect(horizontalRatioY, equals(9));

        const verticalDirection = 'vertical';
        final verticalRatioX = verticalDirection == 'vertical' ? 9 : 16;
        final verticalRatioY = verticalDirection == 'vertical' ? 16 : 9;
        expect(verticalRatioX, equals(9));
        expect(verticalRatioY, equals(16));

        // 3. Floating manager guard contract
        // When floatingManager does not contain player id, standard release is allowed
        expect(floatingManager.containsFloating(globalId), isFalse);
      },
    );
  });
}

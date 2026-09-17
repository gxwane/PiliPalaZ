import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/bottom_control_type.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_status.dart';
import 'package:pilipalaz/plugin/pl_player/playback_lifecycle.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/bottom_control.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/episode_nav_btn.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/play_pause_btn.dart';
import 'package:pilipalaz/services/audio_handler.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

final class _NoOpPlaybackAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late PlPlayerController playerController;

  setUpAll(() async {
    audioSessionHandler = _NoOpPlaybackAudioSession();
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-play-pause-btn-test-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
    videoPlayerServiceHandler = VideoPlayerServiceHandler(
      settingBox: GStorage.setting,
    );

    PlPlayerController.isHeadlessTestMode = true;
    playerController = PlPlayerController.getInstance();
  });

  tearDownAll(() async {
    await PlPlayerController.disposeIfExists();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('PlayOrPauseButton 0-Rx Safety & Reactivity Tests', () {
    testWidgets(
      'PlayOrPauseButton renders safely with null controller (0-Rx safe)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: PlayOrPauseButton(controller: null)),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(PlayOrPauseButton), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
        expect(icon.color, Colors.white54);
      },
    );

    testWidgets(
      'PlayOrPauseButton does NOT throw 0-Rx assertion when controller is not ready (idle/loading)',
      (WidgetTester tester) async {
        // Reset controller to unready state
        playerController.playbackLifecycleState.value =
            PlaybackLifecycleState.idle;
        playerController.playerStatus.status.value = PlayerStatus.paused;

        expect(playerController.canControlPlayback, isFalse);
        expect(playerController.isPlaying, isFalse);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlayOrPauseButton(controller: playerController),
            ),
          ),
        );

        // Crucial check: Must not throw GetX 0-Rx exception
        expect(tester.takeException(), isNull);
        expect(find.byType(PlayOrPauseButton), findsOneWidget);

        final iconFinder = find.byIcon(Icons.play_arrow);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.color, Colors.white54);
      },
    );

    testWidgets(
      'PlayOrPauseButton reactively updates icon and color on ready and playing state transitions',
      (WidgetTester tester) async {
        playerController.playbackLifecycleState.value =
            PlaybackLifecycleState.loading;
        playerController.playerStatus.status.value = PlayerStatus.paused;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlayOrPauseButton(controller: playerController),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        Icon icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
        expect(icon.color, Colors.white54);

        // Transition to ready via setDataSource in headless test mode
        await playerController.setDataSource(
          DataSource(
            videoSource: 'https://test.bilibili.com/video.mp4',
            type: DataSourceType.network,
          ),
          owner: PlayerResourceOwner(),
          seekTo: Duration.zero,
          duration: const Duration(minutes: 5),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(playerController.canControlPlayback, isTrue);

        // Pause to verify play_arrow icon with active white color
        await playerController.pause();
        await tester.pump();

        expect(playerController.isPlaying, isFalse);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
        expect(icon.color, Colors.white);

        // Play to verify pause icon with active white color
        await playerController.play();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(playerController.isPlaying, isTrue);
        expect(find.byIcon(Icons.pause), findsOneWidget);
        icon = tester.widget<Icon>(find.byIcon(Icons.pause));
        expect(icon.color, Colors.white);

        // Transition back to paused
        await playerController.pause();
        await tester.pump();

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
        expect(icon.color, Colors.white);
      },
    );

    testWidgets(
      'AdaptiveBottomControlRow with PlayOrPause, Pre, and Next buttons inside nested LayoutBuilders (reproducing tablet crash hierarchy) throws 0 exceptions',
      (WidgetTester tester) async {
        // Reproduce exact SM-T875 crash hierarchy:
        // LayoutBuilder (ScreenUtils) -> Scaffold -> AdaptiveBottomControlRow (LayoutBuilder) -> Row -> PlayOrPauseButton
        playerController.playbackLifecycleState.value =
            PlaybackLifecycleState.idle;
        playerController.playerStatus.status.value = PlayerStatus.paused;

        final qc = PlaybackQueueController(heroTag: 'test_tablet_tag');

        await tester.pumpWidget(
          MaterialApp(
            home: LayoutBuilder(
              builder: (context, constraints) {
                return Scaffold(
                  body: AdaptiveBottomControlRow(
                    overflowButtonBuilder: (context, hiddenControls) =>
                        const SizedBox(),
                    controls: [
                      BottomControlItem(
                        type: BottomControlType.playOrPause,
                        child: PlayOrPauseButton(controller: playerController),
                      ),
                      BottomControlItem(
                        type: BottomControlType.pre,
                        child: PreEpisodeButton(queueController: qc),
                      ),
                      BottomControlItem(
                        type: BottomControlType.next,
                        child: NextEpisodeButton(queueController: qc),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(PlayOrPauseButton), findsOneWidget);
        expect(find.byType(PreEpisodeButton), findsOneWidget);
        expect(find.byType(NextEpisodeButton), findsOneWidget);
      },
    );
  });
}

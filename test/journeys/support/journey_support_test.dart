import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_status.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_status.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';

import 'journey_test_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestStorage();
  });

  setUp(() async {
    await clearTestStorage();
    await setupJourneyServiceLocator();
  });

  tearDown(() async {
    await journeyTearDown();
  });

  test('journey infrastructure initializes cleanly in headless mode', () async {
    PlPlayerController.isHeadlessTestMode = true;
    final controller = PlPlayerController.getInstance();

    expect(controller.canControlPlayback, isFalse);
    expect(PlPlayerController.isHeadlessTestMode, isTrue);

    final harness = setupJourneyHarness();
    expect(harness.requests, isEmpty);

    await controller.setDataSource(
      DataSource(
        videoSource: 'https://test.bilibili.com/video.mp4',
        type: DataSourceType.network,
      ),
      owner: PlayerResourceOwner(),
      seekTo: Duration.zero,
      duration: const Duration(minutes: 5),
    );

    expect(controller.canControlPlayback, isTrue);
    expect(controller.dataStatus.status.value, DataStatus.loaded);
    expect(controller.duration.value, const Duration(minutes: 5));

    await controller.play();
    expect(controller.playerStatus.status.value, PlayerStatus.playing);

    await controller.pause();
    expect(controller.playerStatus.status.value, PlayerStatus.paused);

    await controller.seekTo(const Duration(seconds: 42));
    expect(controller.position.value, const Duration(seconds: 42));
  });
}

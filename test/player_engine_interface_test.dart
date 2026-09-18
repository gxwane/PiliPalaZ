import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/engine/impl/headless_player_engine.dart';
import 'package:pilipalaz/plugin/pl_player/engine/player_engine_interface.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
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

  group('VideoDimension Model Tests', () {
    test(
      'VideoDimension calculates aspect ratio and detects size correctly',
      () {
        const zero = VideoDimension(0, 0);
        expect(zero.hasSize, isFalse);
        expect(zero.aspectRatio, closeTo(16 / 9, 0.001));

        const hd = VideoDimension(1920, 1080);
        expect(hd.hasSize, isTrue);
        expect(hd.aspectRatio, closeTo(16 / 9, 0.001));

        const square = VideoDimension(1080, 1080);
        expect(square.hasSize, isTrue);
        expect(square.aspectRatio, 1.0);

        const vertical = VideoDimension(1080, 1920);
        expect(vertical.hasSize, isTrue);
        expect(vertical.aspectRatio, closeTo(9 / 16, 0.001));

        expect(const VideoDimension(1920, 1080), equals(hd));
        expect(hd.toString(), '1920x1080');
      },
    );
  });

  group('PlayerMediaItem Model Tests', () {
    test(
      'PlayerMediaItem.fromDataSource converts network source accurately',
      () {
        final source = DataSource(
          videoSource: 'https://example.com/video.m4s',
          audioSource: 'https://example.com/audio.m4s',
          type: DataSourceType.network,
          httpHeaders: {'User-Agent': 'TestAgent'},
        );

        final item = PlayerMediaItem.fromDataSource(source, isLive: true);
        expect(item.videoUri, Uri.parse('https://example.com/video.m4s'));
        expect(item.audioUri, Uri.parse('https://example.com/audio.m4s'));
        expect(item.type, DataSourceType.network);
        expect(item.httpHeaders?['User-Agent'], 'TestAgent');
        expect(item.isLive, isTrue);
      },
    );

    test(
      'PlayerMediaItem.fromDataSource handles single-stream without audio',
      () {
        final source = DataSource(
          videoSource: 'https://example.com/single.mp4',
          type: DataSourceType.network,
        );

        final item = PlayerMediaItem.fromDataSource(source);
        expect(item.videoUri, Uri.parse('https://example.com/single.mp4'));
        expect(item.audioUri, isNull);
        expect(item.isLive, isFalse);
      },
    );
  });

  group('HeadlessPlayerEngine Contract Implementation Tests', () {
    late HeadlessPlayerEngine engine;

    setUp(() {
      engine = HeadlessPlayerEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('initialize transitions state to ready', () async {
      expect(engine.playbackState.value, EnginePlaybackState.idle);
      await engine.initialize();
      expect(engine.playbackState.value, EnginePlaybackState.ready);
    });

    test('open media emits streams and sets dimensions', () async {
      await engine.initialize();

      Duration? emittedPosition;
      Duration? emittedDuration;
      Duration? emittedBuffer;
      VideoDimension? emittedDimension;

      engine.positionStream.listen((pos) => emittedPosition = pos);
      engine.durationStream.listen((dur) => emittedDuration = dur);
      engine.bufferedPositionStream.listen((buf) => emittedBuffer = buf);
      engine.dimensionStream.listen((dim) => emittedDimension = dim);

      final item = PlayerMediaItem(
        videoUri: Uri.parse('https://example.com/test.mp4'),
        startPosition: const Duration(seconds: 15),
      );

      await engine.open(item, autoPlay: true);

      expect(engine.isPlaying, isTrue);
      expect(engine.currentPosition, const Duration(seconds: 15));
      expect(emittedPosition, const Duration(seconds: 15));
      expect(emittedDuration, const Duration(minutes: 10));
      expect(emittedBuffer, const Duration(minutes: 10));
      expect(emittedDimension, const VideoDimension(1920, 1080));
    });

    test('playback commands update state and notify callbacks', () async {
      bool? playingState;
      final notifiedEngine = HeadlessPlayerEngine(
        onPlayingChanged: (playing) => playingState = playing,
      );

      await notifiedEngine.play();
      expect(notifiedEngine.isPlaying, isTrue);
      expect(playingState, isTrue);

      await notifiedEngine.pause();
      expect(notifiedEngine.isPlaying, isFalse);
      expect(playingState, isFalse);

      await notifiedEngine.seek(const Duration(seconds: 42));
      expect(notifiedEngine.currentPosition, const Duration(seconds: 42));

      await notifiedEngine.setRate(1.5);
      expect(notifiedEngine.rate, 1.5);

      await notifiedEngine.setVolume(0.8);
      expect(notifiedEngine.volume, 0.8);

      await notifiedEngine.setLooping(true);
      expect(notifiedEngine.looping, isTrue);

      await notifiedEngine.stop();
      expect(notifiedEngine.isPlaying, isFalse);
      expect(notifiedEngine.currentPosition, Duration.zero);

      await notifiedEngine.dispose();
    });

    testWidgets('buildVideoView produces headless placeholder widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: engine.buildVideoView())),
      );

      expect(
        find.byKey(const Key('headless_video_placeholder')),
        findsOneWidget,
      );
      expect(find.text('Headless Video Placeholder'), findsOneWidget);
    });

    test('getDiagnosticsInfo returns comprehensive metadata', () async {
      final info = await engine.getDiagnosticsInfo();
      expect(info['engine'], 'HeadlessPlayerEngine');
      expect(info['width'], 1920);
      expect(info['height'], 1080);
    });
  });

  group('PlPlayerController IPlayerEngine Integration Tests', () {
    late Directory hiveDirectory;
    late PlPlayerController controller;

    setUpAll(() async {
      audioSessionHandler = _NoOpPlaybackAudioSession();
      hiveDirectory = await Directory.systemTemp.createTemp(
        'pilipalaz-engine-integration-test-',
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
      controller = PlPlayerController.getInstance();
    });

    tearDownAll(() async {
      await PlPlayerController.disposeIfExists();
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    testWidgets(
      'PlPlayerController instantiates engine and builds video view safely',
      (tester) async {
        final source = DataSource(
          videoSource: 'https://example.com/test.mp4',
          type: DataSourceType.network,
        );

        await controller.setDataSource(
          source,
          owner: PlayerResourceOwner(),
          autoplay: false,
        );

        expect(controller.engine, isNotNull);
        expect(controller.engine is HeadlessPlayerEngine, isTrue);
        expect(controller.currentDimension.hasSize, isTrue);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: controller.buildVideoView())),
        );

        expect(
          find.byKey(const Key('headless_video_placeholder')),
          findsOneWidget,
        );
      },
    );
  });
}

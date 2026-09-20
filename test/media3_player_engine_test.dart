import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/engine/impl/media3_player_engine.dart';
import 'package:pilipalaz/plugin/pl_player/engine/player_engine_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> methodCalls;
  const MethodChannel methodChannel = MethodChannel(
    'io.github.gxwane.pilipalaz/media3',
  );

  setUp(() {
    methodCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'create':
              return 42; // mock textureId
            case 'open':
            case 'play':
            case 'pause':
            case 'stop':
            case 'seekTo':
            case 'setPlaybackSpeed':
            case 'setVolume':
            case 'setLooping':
            case 'dispose':
              return null;
            default:
              throw MissingPluginException();
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('Media3PlayerEngine Tests', () {
    test('initialize invokes create and acquires textureId', () async {
      final engine = Media3PlayerEngine();
      await engine.initialize();

      expect(engine.textureId, 42);
      expect(engine.playbackState.value, EnginePlaybackState.ready);
      expect(methodCalls.map((c) => c.method), contains('create'));

      await engine.dispose();
    });

    test('open formats dual-stream parameters correctly', () async {
      final engine = Media3PlayerEngine();
      await engine.initialize();

      final item = PlayerMediaItem(
        videoUri: Uri.parse('https://bilibili.com/video.m4s'),
        audioUri: Uri.parse('https://bilibili.com/audio.m4s'),
        httpHeaders: {'Referer': 'https://www.bilibili.com/'},
        startPosition: const Duration(seconds: 10),
      );

      await engine.open(item, autoPlay: true);

      final openCall = methodCalls.firstWhere((c) => c.method == 'open');
      expect(openCall.arguments['videoUrl'], 'https://bilibili.com/video.m4s');
      expect(openCall.arguments['audioUrl'], 'https://bilibili.com/audio.m4s');
      expect(openCall.arguments['headers'], {
        'Referer': 'https://www.bilibili.com/',
      });
      expect(openCall.arguments['startPositionMs'], 10000);
      expect(openCall.arguments['autoPlay'], isTrue);
      expect(engine.isPlaying, isTrue);

      await engine.dispose();
    });

    test('playback commands invoke corresponding platform channels', () async {
      final engine = Media3PlayerEngine();
      await engine.initialize();

      await engine.play();
      expect(methodCalls.last.method, 'play');
      expect(engine.isPlaying, isTrue);
      expect(engine.playbackState.value, EnginePlaybackState.playing);

      await engine.pause();
      expect(methodCalls.last.method, 'pause');
      expect(engine.isPlaying, isFalse);
      expect(engine.playbackState.value, EnginePlaybackState.paused);

      await engine.seek(const Duration(seconds: 30));
      expect(methodCalls.last.method, 'seekTo');
      expect(methodCalls.last.arguments['positionMs'], 30000);

      await engine.setRate(2.0);
      expect(methodCalls.last.method, 'setPlaybackSpeed');
      expect(methodCalls.last.arguments['speed'], 2.0);

      await engine.setVolume(0.5);
      expect(methodCalls.last.method, 'setVolume');
      expect(methodCalls.last.arguments['volume'], 0.5);

      await engine.setLooping(true);
      expect(methodCalls.last.method, 'setLooping');
      expect(methodCalls.last.arguments['looping'], isTrue);

      await engine.stop();
      expect(methodCalls.last.method, 'stop');
      expect(engine.isPlaying, isFalse);

      await engine.dispose();
      expect(methodCalls.last.method, 'dispose');
    });

    test(
      'buildVideoView returns reactive StreamBuilder when textureId is available',
      () async {
        final engine = Media3PlayerEngine();
        await engine.initialize();

        const testKey = ValueKey('test_key');
        final widget = engine.buildVideoView(key: testKey);
        expect(widget, isA<StreamBuilder<VideoDimension>>());
        expect(widget.key, testKey);

        await engine.dispose();
      },
    );

    test('getDiagnosticsInfo returns Media3 telemetry', () async {
      final engine = Media3PlayerEngine();
      await engine.initialize();

      final info = await engine.getDiagnosticsInfo();
      expect(info['engine'], 'Media3PlayerEngine');
      expect(info['textureId'], 42);

      await engine.dispose();
    });

    test(
      'eventChannel updates playbackState to paused on stateChanged event',
      () async {
        final engine = Media3PlayerEngine();
        await engine.initialize();

        const StandardMethodCodec codec = StandardMethodCodec();
        final ByteData message = codec.encodeSuccessEnvelope({
          'event': 'stateChanged',
          'state': 'paused',
        });
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'io.github.gxwane.pilipalaz/media3_events',
              message,
              (ByteData? reply) {},
            );

        expect(engine.playbackState.value, EnginePlaybackState.paused);
        expect(engine.isPlaying, isFalse);

        await engine.dispose();
      },
    );
  });
}

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
  const MethodChannel eventChannel = MethodChannel(
    'io.github.gxwane.pilipalaz/media3_events',
  );

  setUp(() {
    methodCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'create':
              return 42;
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, (MethodCall call) async {
          return null; // Mock listen / cancel for EventChannel
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannel, null);
  });

  Future<void> emitNativePlaybackUpdate({
    required int positionMs,
    int bufferedMs = 10000,
    int durationMs = 60000,
    bool isPlaying = true,
  }) async {
    const StandardMethodCodec codec = StandardMethodCodec();
    final ByteData message = codec.encodeSuccessEnvelope({
      'event': 'playbackUpdate',
      'position': positionMs,
      'buffered': bufferedMs,
      'duration': durationMs,
      'isPlaying': isPlaying,
    });
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'io.github.gxwane.pilipalaz/media3_events',
          message,
          (ByteData? reply) {},
        );
  }

  group('Media3PlayerEngine Subtitle Engine TDD Tests (Gate 4)', () {
    const sampleVtt = '''WEBVTT

1
00:00:01.000 --> 00:00:04.000
First Subtitle Text

2
00:00:03.000 --> 00:00:06.000
Overlapping Second Text

3
00:00:10.000 --> 00:00:15.000
Third Subtitle Text
''';

    test(
      'loads subtitle track data and aligns with native playback clock',
      () async {
        final engine = Media3PlayerEngine();
        await engine.initialize();

        await engine.setSubtitleTrack(
          SubtitleTrackOption.data(sampleVtt, label: '中文'),
        );

        // Initially at 0ms, before first cue
        expect(engine.currentSubtitle.value, equals(''));

        // Advance clock to 2000ms -> matches cue 1 only
        await emitNativePlaybackUpdate(positionMs: 2000);
        expect(engine.currentSubtitle.value, equals('First Subtitle Text'));

        // Advance clock to 3500ms -> overlaps cue 1 and cue 2
        await emitNativePlaybackUpdate(positionMs: 3500);
        expect(
          engine.currentSubtitle.value,
          equals('First Subtitle Text\nOverlapping Second Text'),
        );

        // Advance clock to 5000ms -> matches cue 2 only
        await emitNativePlaybackUpdate(positionMs: 5000);
        expect(engine.currentSubtitle.value, equals('Overlapping Second Text'));

        // Advance clock to 8000ms -> silence gap
        await emitNativePlaybackUpdate(positionMs: 8000);
        expect(engine.currentSubtitle.value, equals(''));

        // Advance clock to 12000ms -> matches cue 3
        await emitNativePlaybackUpdate(positionMs: 12000);
        expect(engine.currentSubtitle.value, equals('Third Subtitle Text'));

        await engine.dispose();
      },
    );

    test(
      'seek immediately synchronizes subtitle without waiting for next native event',
      () async {
        final engine = Media3PlayerEngine();
        await engine.initialize();

        await engine.setSubtitleTrack(
          SubtitleTrackOption.data(sampleVtt, label: '中文'),
        );
        expect(engine.currentSubtitle.value, equals(''));

        // Immediate seek to 11000ms
        await engine.seek(const Duration(seconds: 11));
        expect(engine.currentSubtitle.value, equals('Third Subtitle Text'));

        // Immediate seek to silence gap
        await engine.seek(const Duration(seconds: 7));
        expect(engine.currentSubtitle.value, equals(''));

        await engine.dispose();
      },
    );

    test(
      'setting subtitle track to off thoroughly clears active text',
      () async {
        final engine = Media3PlayerEngine();
        await engine.initialize();

        await engine.setSubtitleTrack(
          SubtitleTrackOption.data(sampleVtt, label: '中文'),
        );
        await engine.seek(const Duration(seconds: 2));
        expect(engine.currentSubtitle.value, equals('First Subtitle Text'));

        // Turn off
        await engine.setSubtitleTrack(SubtitleTrackOption.off);
        expect(engine.currentSubtitle.value, equals(''));

        // Subsequent position updates do nothing
        await emitNativePlaybackUpdate(positionMs: 2000);
        expect(engine.currentSubtitle.value, equals(''));

        await engine.dispose();
      },
    );

    test(
      'open and stop cleanly reset subtitle text to prevent cross-video ghosting',
      () async {
        final engine = Media3PlayerEngine();
        await engine.initialize();

        await engine.setSubtitleTrack(
          SubtitleTrackOption.data(sampleVtt, label: '中文'),
        );
        await engine.seek(const Duration(seconds: 2));
        expect(engine.currentSubtitle.value, equals('First Subtitle Text'));

        // Stopping resets subtitle text
        await engine.stop();
        expect(engine.currentSubtitle.value, equals(''));

        await engine.dispose();
      },
    );

    test(
      'buildVideoView structure mounts Stack with IgnorePointer(ignoring: true)',
      () async {
        final engine = Media3PlayerEngine();
        await engine.initialize();

        await engine.setSubtitleTrack(
          SubtitleTrackOption.data(sampleVtt, label: '中文'),
        );
        await engine.seek(const Duration(seconds: 2));

        final widget = engine.buildVideoView(
          subtitleStyle: const TextStyle(fontSize: 20, color: Colors.white),
          subtitleBottomPadding: 30.0,
        );

        expect(widget, isA<StreamBuilder<VideoDimension>>());
        final streamBuilder = widget as StreamBuilder<VideoDimension>;

        // Test builder output directly
        final BuildContext mockContext = _MockBuildContext();
        final builtWidget = streamBuilder.builder(
          mockContext,
          const AsyncSnapshot.withData(
            ConnectionState.active,
            VideoDimension(1920, 1080),
          ),
        );

        expect(builtWidget, isA<Container>());
        final container = builtWidget as Container;
        final center = container.child as Center;
        final stack = center.child as Stack;

        expect(stack.children.length, equals(2));
        expect(stack.children[0], isA<ClipRect>()); // Video texture
        expect(stack.children[1], isA<Positioned>()); // Subtitle overlay

        final positioned = stack.children[1] as Positioned;
        expect(positioned.child, isA<IgnorePointer>());
        final ignorePointer = positioned.child as IgnorePointer;
        expect(
          ignorePointer.ignoring,
          isTrue,
        ); // Gate 2 Enhancement 1: gesture pass-through

        final valueListenableBuilder =
            ignorePointer.child as ValueListenableBuilder<String>;
        expect(
          valueListenableBuilder.valueListenable,
          equals(engine.currentSubtitle),
        );

        // Test Subtitle builder output when active text is present
        final subtitleWidget = valueListenableBuilder.builder(
          mockContext,
          'First Subtitle Text',
          null,
        );
        expect(subtitleWidget, isA<LayoutBuilder>());

        // Test Subtitle builder output when text is empty (silence)
        final emptySubtitleWidget = valueListenableBuilder.builder(
          mockContext,
          '',
          null,
        );
        expect(emptySubtitleWidget, isA<SizedBox>());
        final sizedBox = emptySubtitleWidget as SizedBox;
        expect(sizedBox.width, equals(0.0));
        expect(sizedBox.height, equals(0.0));

        await engine.dispose();
      },
    );
  });
}

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

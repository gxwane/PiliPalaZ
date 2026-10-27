import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/engine/impl/media3_player_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Media3PlayerEngine Screenshot Unit Tests (Gate 4)', () {
    late Media3PlayerEngine engine;
    final List<MethodCall> channelLog = [];
    Uint8List? mockChannelBytes;
    bool shouldThrowPlatformException = false;

    setUp(() {
      channelLog.clear();
      mockChannelBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
      shouldThrowPlatformException = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('io.github.gxwane.pilipalaz/media3'),
            (MethodCall methodCall) async {
              channelLog.add(methodCall);
              if (methodCall.method == 'create') {
                return 42; // Texture ID
              }
              if (methodCall.method == 'screenshot') {
                if (shouldThrowPlatformException) {
                  throw PlatformException(
                    code: 'PIXELCOPY_FAILED',
                    message: 'Native PixelCopy failed',
                  );
                }
                return mockChannelBytes;
              }
              return null;
            },
          );

      engine = Media3PlayerEngine();
    });

    tearDown(() async {
      await engine.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('io.github.gxwane.pilipalaz/media3'),
            null,
          );
    });

    test('returns null when engine is not initialized', () async {
      final result = await engine.screenshot();
      expect(result, isNull);
      expect(
        channelLog.where((call) => call.method == 'screenshot'),
        isEmpty,
      );
    });

    test('invokes native platform channel and returns byte data when initialized', () async {
      await engine.initialize();
      expect(engine.textureId, equals(42));

      final result = await engine.screenshot(format: 'image/png');
      expect(result, equals(mockChannelBytes));

      final screenshotCall = channelLog.firstWhere(
        (call) => call.method == 'screenshot',
      );
      expect(screenshotCall.arguments, equals({'format': 'image/png'}));
    });

    test('catches platform exception and safely returns null without rethrowing', () async {
      await engine.initialize();
      shouldThrowPlatformException = true;

      final result = await engine.screenshot();
      expect(result, isNull);
    });

    test('returns null after engine is disposed', () async {
      await engine.initialize();
      await engine.dispose();

      channelLog.clear();
      final result = await engine.screenshot();
      expect(result, isNull);
      expect(channelLog, isEmpty);
    });
  });
}

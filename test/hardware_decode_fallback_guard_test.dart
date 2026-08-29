import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/hardware_decode_fallback_guard.dart';

void main() {
  group('requiresAndroid8BitSoftwareOutput', () {
    test('recognizes common high-bit-depth software frame formats', () {
      for (final String format in <String>[
        'yuv420p10',
        'yuv420p10le',
        'yuv420p9le',
        'yuv444p12le',
        'gbrp10le',
        'gray16le',
        'p010',
        'p012le',
        'p016le',
      ]) {
        expect(
          requiresAndroid8BitSoftwareOutput(format),
          isTrue,
          reason: format,
        );
      }
    });

    test('leaves normal 8-bit and unknown formats unchanged', () {
      for (final String? format in <String?>[
        null,
        '',
        'yuv420p',
        'nv12',
        'rgba',
      ]) {
        expect(
          requiresAndroid8BitSoftwareOutput(format),
          isFalse,
          reason: format,
        );
      }
    });
  });

  group('HardwareDecodeFallbackGuard', () {
    test('requests one fallback for repeated codec errors in a session', () {
      final guard = HardwareDecodeFallbackGuard();
      guard.beginSession(1, enabled: true);

      expect(
        guard.evaluate(1, 'Could not open codec.'),
        HardwareDecodeFallbackAction.fallback,
      );
      expect(
        guard.evaluate(1, 'Could not open codec.'),
        HardwareDecodeFallbackAction.suppress,
      );
      expect(
        guard.evaluate(1, 'Could not open codec.'),
        HardwareDecodeFallbackAction.suppress,
      );
    });

    test('ignores unrelated errors and stale sessions', () {
      final guard = HardwareDecodeFallbackGuard();
      guard.beginSession(2, enabled: true);

      expect(
        guard.evaluate(2, 'Failed to open stream.'),
        HardwareDecodeFallbackAction.ignore,
      );
      expect(
        guard.evaluate(1, 'Could not open codec.'),
        HardwareDecodeFallbackAction.ignore,
      );
      expect(
        guard.evaluate(2, 'Could not open codec.'),
        HardwareDecodeFallbackAction.fallback,
      );
    });

    test('does not fallback when hardware decoding is disabled', () {
      final guard = HardwareDecodeFallbackGuard();
      guard.beginSession(3, enabled: false);

      expect(
        guard.evaluate(3, 'Could not open codec.'),
        HardwareDecodeFallbackAction.ignore,
      );
    });

    test('allows a new playback session to try hardware decoding again', () {
      final guard = HardwareDecodeFallbackGuard();
      guard.beginSession(4, enabled: true);
      expect(
        guard.evaluate(4, 'Could not open codec.'),
        HardwareDecodeFallbackAction.fallback,
      );

      guard.beginSession(5, enabled: true);

      expect(
        guard.evaluate(5, 'Could not open codec.'),
        HardwareDecodeFallbackAction.fallback,
      );
    });

    test(
      'keeps suppressing duplicate codec errors after fallback is ready',
      () {
        final guard = HardwareDecodeFallbackGuard();
        guard.beginSession(6, enabled: true);
        expect(
          guard.evaluate(6, 'Could not open codec.'),
          HardwareDecodeFallbackAction.fallback,
        );

        guard.finishFallback(6);

        expect(
          guard.evaluate(6, 'Could not open codec.'),
          HardwareDecodeFallbackAction.suppress,
        );
      },
    );
  });
}

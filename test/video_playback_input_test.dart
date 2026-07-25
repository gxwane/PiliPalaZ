import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/playback_input.dart';

void main() {
  group('normalizeHistoryPosition', () {
    test('uses zero when last play time is missing', () {
      expect(
        normalizeHistoryPosition(lastPlayTimeMs: null, durationMs: 120000),
        Duration.zero,
      );
    });

    test('uses zero for invalid or completed history positions', () {
      expect(
        normalizeHistoryPosition(lastPlayTimeMs: -1, durationMs: 120000),
        Duration.zero,
      );
      expect(
        normalizeHistoryPosition(lastPlayTimeMs: 120000, durationMs: 120000),
        Duration.zero,
      );
      expect(
        normalizeHistoryPosition(lastPlayTimeMs: 130000, durationMs: 120000),
        Duration.zero,
      );
    });

    test('keeps a valid history position', () {
      expect(
        normalizeHistoryPosition(lastPlayTimeMs: 42000, durationMs: 120000),
        const Duration(seconds: 42),
      );
    });
  });
}

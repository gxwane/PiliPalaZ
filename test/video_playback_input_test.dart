import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/playback_input.dart';

void main() {
  group('resolvePlaybackDuration', () {
    test('prefers an explicit preview duration', () {
      expect(
        resolvePlaybackDuration(
          explicitDuration: const Duration(minutes: 6),
          fallbackDurationMs: 120000,
        ),
        const Duration(minutes: 6),
      );
    });

    test('falls back to the full source duration', () {
      expect(
        resolvePlaybackDuration(fallbackDurationMs: 120000),
        const Duration(minutes: 2),
      );
    });

    test('keeps a missing duration nullable', () {
      expect(resolvePlaybackDuration(), isNull);
    });
  });

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

  group('transitionPlaybackLoadState', () {
    test(
      'recovers from an initial failure after a successful source change',
      () {
        PlaybackLoadState state = PlaybackLoadState.failed;

        state = transitionPlaybackLoadState(
          current: state,
          event: PlaybackLoadEvent.begin,
        );
        expect(state, PlaybackLoadState.loading);

        state = transitionPlaybackLoadState(
          current: state,
          event: PlaybackLoadEvent.success,
        );
        expect(state, PlaybackLoadState.ready);
      },
    );

    test('keeps the current player visible while a replacement fails', () {
      PlaybackLoadState state = PlaybackLoadState.ready;

      state = transitionPlaybackLoadState(
        current: state,
        event: PlaybackLoadEvent.begin,
        preserveReady: true,
      );
      expect(state, PlaybackLoadState.ready);

      state = transitionPlaybackLoadState(
        current: state,
        event: PlaybackLoadEvent.failure,
        preserveReady: true,
      );
      expect(state, PlaybackLoadState.ready);
    });

    test('exposes a failure when there is no playable source to preserve', () {
      expect(
        transitionPlaybackLoadState(
          current: PlaybackLoadState.loading,
          event: PlaybackLoadEvent.failure,
        ),
        PlaybackLoadState.failed,
      );
    });
  });
}

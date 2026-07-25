import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/playback_position_guard.dart';

void main() {
  late DateTime now;
  late PlaybackPositionGuard guard;

  setUp(() {
    now = DateTime(2026, 7, 25, 12);
    guard = PlaybackPositionGuard(clock: () => now);
  });

  test('accepts forward progress and small backward jitter', () {
    expect(
      guard
          .evaluate(
            const Duration(seconds: 20),
            isPlaying: true,
            isBuffering: false,
          )
          .action,
      PlaybackPositionAction.accept,
    );
    expect(
      guard
          .evaluate(
            const Duration(milliseconds: 19000),
            isPlaying: true,
            isBuffering: false,
          )
          .action,
      PlaybackPositionAction.accept,
    );
  });

  test('requests correction for a large unexpected regression', () {
    guard.evaluate(
      const Duration(seconds: 20),
      isPlaying: true,
      isBuffering: false,
    );

    final decision = guard.evaluate(
      const Duration(seconds: 15),
      isPlaying: true,
      isBuffering: false,
    );

    expect(decision.action, PlaybackPositionAction.correct);
    expect(decision.correctionTarget, const Duration(seconds: 20));
    expect(decision.regression, const Duration(seconds: 5));
  });

  test('holds a large regression while buffering without seeking', () {
    guard.evaluate(
      const Duration(seconds: 20),
      isPlaying: true,
      isBuffering: false,
    );

    final decision = guard.evaluate(
      const Duration(seconds: 15),
      isPlaying: true,
      isBuffering: true,
    );

    expect(decision.action, PlaybackPositionAction.ignore);
    expect(decision.correctionTarget, isNull);
  });

  test('allows an explicit backward seek and ignores stale events', () {
    guard.evaluate(
      const Duration(seconds: 100),
      isPlaying: true,
      isBuffering: false,
    );
    guard.expectPosition(const Duration(seconds: 40));

    expect(
      guard
          .evaluate(
            const Duration(seconds: 101),
            isPlaying: true,
            isBuffering: false,
          )
          .action,
      PlaybackPositionAction.ignore,
    );
    expect(
      guard
          .evaluate(
            const Duration(milliseconds: 40500),
            isPlaying: true,
            isBuffering: false,
          )
          .action,
      PlaybackPositionAction.accept,
    );
  });

  test('does not create a correction storm during cooldown', () {
    guard.evaluate(
      const Duration(seconds: 20),
      isPlaying: true,
      isBuffering: false,
    );
    expect(
      guard
          .evaluate(
            const Duration(seconds: 15),
            isPlaying: true,
            isBuffering: false,
          )
          .action,
      PlaybackPositionAction.correct,
    );

    now = now.add(const Duration(seconds: 1));

    expect(
      guard
          .evaluate(
            const Duration(seconds: 14),
            isPlaying: true,
            isBuffering: false,
          )
          .action,
      PlaybackPositionAction.ignore,
    );
  });

  test('does not enforce monotonic positions for live playback', () {
    guard.evaluate(
      const Duration(seconds: 20),
      isPlaying: true,
      isBuffering: false,
      isLive: true,
    );

    expect(
      guard
          .evaluate(
            const Duration(seconds: 5),
            isPlaying: true,
            isBuffering: false,
            isLive: true,
          )
          .action,
      PlaybackPositionAction.accept,
    );
  });
}

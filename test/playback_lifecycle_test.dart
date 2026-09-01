import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/playback_lifecycle.dart';

void main() {
  group('PlaybackLifecycle', () {
    test('only accepts user commands while ready', () {
      final lifecycle = PlaybackLifecycle();

      expect(lifecycle.canControlPlayback, isFalse);

      lifecycle.beginLoading();
      expect(lifecycle.state, PlaybackLifecycleState.loading);
      expect(lifecycle.canControlPlayback, isFalse);

      lifecycle.markReady();
      expect(lifecycle.canControlPlayback, isTrue);

      lifecycle.beginRelease();
      expect(lifecycle.state, PlaybackLifecycleState.releasing);
      expect(lifecycle.canControlPlayback, isFalse);

      lifecycle.markIdle();
      expect(lifecycle.state, PlaybackLifecycleState.idle);
      expect(lifecycle.canControlPlayback, isFalse);
    });

    test('a stale session cannot publish ready state', () {
      final lifecycle = PlaybackLifecycle();

      final first = lifecycle.beginLoading();
      final second = lifecycle.beginLoading();

      expect(lifecycle.markReady(first), isFalse);
      expect(lifecycle.canControlPlayback, isFalse);
      expect(lifecycle.markReady(second), isTrue);
      expect(lifecycle.canControlPlayback, isTrue);
    });

    test('beginning release invalidates the active session', () {
      final lifecycle = PlaybackLifecycle();
      final session = lifecycle.beginLoading();
      lifecycle.markReady(session);

      lifecycle.beginRelease();

      expect(lifecycle.isCurrent(session), isFalse);
    });
  });
}

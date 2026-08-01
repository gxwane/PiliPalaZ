import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/playback_presentation_state.dart';

void main() {
  group('PlaybackPresentationState', () {
    test('a new video never inherits the previous video timeline', () {
      const previous = PlaybackPresentationState(
        position: Duration(seconds: 10),
        sliderPosition: Duration(seconds: 10),
        sliderTempPosition: Duration(seconds: 10),
        buffered: Duration(seconds: 30),
        duration: Duration(minutes: 5),
        isSliderMoving: true,
      );

      final next = previous.beginSource(
        initialPosition: Duration.zero,
        initialDuration: const Duration(minutes: 2),
      );

      expect(next.position, Duration.zero);
      expect(next.sliderPosition, Duration.zero);
      expect(next.sliderTempPosition, Duration.zero);
      expect(next.buffered, Duration.zero);
      expect(next.duration, const Duration(minutes: 2));
      expect(next.isSliderMoving, isFalse);
    });

    test('restoring a video starts from its saved position', () {
      const current = PlaybackPresentationState(
        position: Duration.zero,
        sliderPosition: Duration.zero,
        sliderTempPosition: Duration.zero,
        buffered: Duration.zero,
        duration: Duration(minutes: 2),
        isSliderMoving: false,
      );

      final restored = current.beginSource(
        initialPosition: const Duration(seconds: 10),
        initialDuration: const Duration(minutes: 5),
      );

      expect(restored.position, const Duration(seconds: 10));
      expect(restored.sliderPosition, const Duration(seconds: 10));
      expect(restored.sliderTempPosition, const Duration(seconds: 10));
      expect(restored.buffered, Duration.zero);
      expect(restored.duration, const Duration(minutes: 5));
      expect(restored.isSliderMoving, isFalse);
    });
  });
}

final class PlaybackPresentationState {
  const PlaybackPresentationState({
    required this.position,
    required this.sliderPosition,
    required this.sliderTempPosition,
    required this.buffered,
    required this.duration,
    required this.isSliderMoving,
  });

  final Duration position;
  final Duration sliderPosition;
  final Duration sliderTempPosition;
  final Duration buffered;
  final Duration duration;
  final bool isSliderMoving;

  PlaybackPresentationState beginSource({
    required Duration initialPosition,
    Duration? initialDuration,
  }) {
    return PlaybackPresentationState(
      position: initialPosition,
      sliderPosition: initialPosition,
      sliderTempPosition: initialPosition,
      buffered: Duration.zero,
      duration: initialDuration ?? Duration.zero,
      isSliderMoving: false,
    );
  }
}

enum PlaybackLoadState { loading, ready, failed }

enum PlaybackLoadEvent { begin, success, failure }

Duration? resolvePlaybackDuration({
  Duration? explicitDuration,
  int? fallbackDurationMs,
}) {
  return explicitDuration ??
      (fallbackDurationMs == null
          ? null
          : Duration(milliseconds: fallbackDurationMs));
}

PlaybackLoadState transitionPlaybackLoadState({
  required PlaybackLoadState current,
  required PlaybackLoadEvent event,
  bool preserveReady = false,
}) {
  return switch (event) {
    PlaybackLoadEvent.begin =>
      preserveReady && current == PlaybackLoadState.ready
          ? PlaybackLoadState.ready
          : PlaybackLoadState.loading,
    PlaybackLoadEvent.success => PlaybackLoadState.ready,
    PlaybackLoadEvent.failure =>
      preserveReady && current == PlaybackLoadState.ready
          ? PlaybackLoadState.ready
          : PlaybackLoadState.failed,
  };
}

Duration normalizeHistoryPosition({
  required int? lastPlayTimeMs,
  required int? durationMs,
}) {
  final int positionMs = lastPlayTimeMs ?? 0;
  if (positionMs <= 0) {
    return Duration.zero;
  }
  if (durationMs != null && durationMs > 0 && positionMs >= durationMs) {
    return Duration.zero;
  }
  return Duration(milliseconds: positionMs);
}

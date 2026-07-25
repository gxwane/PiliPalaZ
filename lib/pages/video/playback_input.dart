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

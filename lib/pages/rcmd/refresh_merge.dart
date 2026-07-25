class RcmdRefreshMerge<T> {
  const RcmdRefreshMerge({required this.videos, required this.lastSeenIndex});

  final List<T> videos;
  final int? lastSeenIndex;
}

RcmdRefreshMerge<T> mergeRcmdRefresh<T>({
  required Iterable<T> currentVideos,
  required Iterable<T> refreshedVideos,
  required bool preserveCurrent,
}) {
  final current = List<T>.of(currentVideos);
  final refreshed = List<T>.of(refreshedVideos);

  if (!preserveCurrent) {
    return RcmdRefreshMerge<T>(
      videos: List<T>.unmodifiable(refreshed),
      lastSeenIndex: null,
    );
  }

  if (refreshed.isEmpty) {
    return RcmdRefreshMerge<T>(
      videos: List<T>.unmodifiable(current),
      lastSeenIndex: null,
    );
  }

  if (current.isEmpty) {
    return RcmdRefreshMerge<T>(
      videos: List<T>.unmodifiable(refreshed),
      lastSeenIndex: null,
    );
  }

  return RcmdRefreshMerge<T>(
    videos: List<T>.unmodifiable(<T>[...refreshed, ...current]),
    lastSeenIndex: refreshed.length,
  );
}

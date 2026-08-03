typedef AsyncPlaybackAction = Future<void> Function();
typedef AsyncModalAction<T> = Future<T?> Function();

Future<T?> runPlaybackAwareModal<T>({
  required bool wasPlaying,
  required AsyncPlaybackAction pause,
  required AsyncModalAction<T> showModal,
  required bool Function() canResume,
  required AsyncPlaybackAction resume,
}) async {
  if (!wasPlaying) {
    return showModal();
  }

  await pause();
  try {
    return await showModal();
  } finally {
    if (canResume()) {
      await resume();
    }
  }
}

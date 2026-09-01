enum PlaybackLifecycleState { idle, loading, ready, releasing }

class PlaybackLifecycle {
  PlaybackLifecycleState _state = PlaybackLifecycleState.idle;
  int _session = 0;

  PlaybackLifecycleState get state => _state;

  int get session => _session;

  bool get canControlPlayback => _state == PlaybackLifecycleState.ready;

  int beginLoading() {
    _state = PlaybackLifecycleState.loading;
    return ++_session;
  }

  bool markReady([int? session]) {
    if (session != null && !isCurrent(session)) return false;
    if (_state == PlaybackLifecycleState.releasing) return false;
    _state = PlaybackLifecycleState.ready;
    return true;
  }

  void beginRelease() {
    ++_session;
    _state = PlaybackLifecycleState.releasing;
  }

  void markIdle() {
    _state = PlaybackLifecycleState.idle;
  }

  bool isCurrent(int session) => session == _session;
}

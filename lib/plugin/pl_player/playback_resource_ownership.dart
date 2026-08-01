final class PlayerResourceOwner {}

final class PlaybackResourceOwnership {
  PlayerResourceOwner? _owner;

  void claim(PlayerResourceOwner owner) {
    _owner = owner;
  }

  bool owns(PlayerResourceOwner owner) => identical(_owner, owner);

  bool release(PlayerResourceOwner owner) {
    if (!owns(owner)) {
      return false;
    }
    _owner = null;
    return true;
  }

  void forceClear() {
    _owner = null;
  }
}

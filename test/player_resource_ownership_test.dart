import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';

void main() {
  group('PlaybackResourceOwnership', () {
    test('current owner can release the resource', () {
      final ownership = PlaybackResourceOwnership();
      final owner = PlayerResourceOwner();

      ownership.claim(owner);

      expect(ownership.release(owner), isTrue);
      expect(ownership.owns(owner), isFalse);
    });

    test('a stale owner cannot release a newer owner resource', () {
      final ownership = PlaybackResourceOwnership();
      final firstVideo = PlayerResourceOwner();
      final relatedVideo = PlayerResourceOwner();

      ownership.claim(firstVideo);
      ownership.claim(relatedVideo);

      expect(ownership.release(firstVideo), isFalse);
      expect(ownership.owns(relatedVideo), isTrue);
    });

    test('late related video release cannot clear restored first video', () {
      final ownership = PlaybackResourceOwnership();
      final firstVideo = PlayerResourceOwner();
      final relatedVideo = PlayerResourceOwner();

      ownership.claim(firstVideo);
      ownership.claim(relatedVideo);
      ownership.claim(firstVideo);

      expect(ownership.release(relatedVideo), isFalse);
      expect(ownership.owns(firstVideo), isTrue);
    });

    test('force clear removes the current owner', () {
      final ownership = PlaybackResourceOwnership();
      final owner = PlayerResourceOwner();

      ownership.claim(owner);
      ownership.forceClear();

      expect(ownership.owns(owner), isFalse);
    });
  });
}

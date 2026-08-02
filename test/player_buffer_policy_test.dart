import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/player_buffer_policy.dart';

void main() {
  const mebibyte = 1024 * 1024;

  group('resolvePlayerBufferPolicy', () {
    test('uses the standard buffer without a VPN', () {
      final video = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: false,
        vpnActive: false,
      );
      final live = resolvePlayerBufferPolicy(
        isLive: true,
        forceExpanded: false,
        vpnActive: false,
      );

      expect(video.bufferSize, 4 * mebibyte);
      expect(video.reason, PlayerBufferReason.standard);
      expect(live.bufferSize, 16 * mebibyte);
      expect(live.reason, PlayerBufferReason.standard);
    });

    test('expands video and live buffers for an active VPN', () {
      final video = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: false,
        vpnActive: true,
      );
      final live = resolvePlayerBufferPolicy(
        isLive: true,
        forceExpanded: false,
        vpnActive: true,
      );

      expect(video.bufferSize, 32 * mebibyte);
      expect(video.reason, PlayerBufferReason.vpn);
      expect(live.bufferSize, 64 * mebibyte);
      expect(live.reason, PlayerBufferReason.vpn);
    });

    test('the user setting forces expanded buffers on every network', () {
      final video = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: true,
        vpnActive: false,
      );
      final live = resolvePlayerBufferPolicy(
        isLive: true,
        forceExpanded: true,
        vpnActive: false,
      );

      expect(video.bufferSize, 32 * mebibyte);
      expect(video.reason, PlayerBufferReason.userExpanded);
      expect(live.bufferSize, 64 * mebibyte);
      expect(live.reason, PlayerBufferReason.userExpanded);
    });

    test('the user setting takes diagnostic precedence over VPN detection', () {
      final policy = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: true,
        vpnActive: true,
      );

      expect(policy.bufferSize, 32 * mebibyte);
      expect(policy.reason, PlayerBufferReason.userExpanded);
    });
  });

  group('hasActiveVpn', () {
    test('detects VPN alongside the underlying Wi-Fi network', () {
      expect(
        hasActiveVpn([ConnectivityResult.wifi, ConnectivityResult.vpn]),
        isTrue,
      );
    });

    test('does not treat an ordinary network as a VPN', () {
      expect(hasActiveVpn([ConnectivityResult.wifi]), isFalse);
    });
  });
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/player_buffer_policy.dart';

void main() {
  const mebibyte = 1024 * 1024;

  group('resolvePlayerBufferPolicy', () {
    test('uses standard policy on Wi-Fi/broadband', () {
      final video = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: false,
        vpnActive: false,
        isMobileNetwork: false,
      );
      final live = resolvePlayerBufferPolicy(
        isLive: true,
        forceExpanded: false,
        vpnActive: false,
        isMobileNetwork: false,
      );

      expect(video.demuxerMaxBytes, 32 * mebibyte);
      expect(video.demuxerMaxBackBytes, 8 * mebibyte);
      expect(video.demuxerReadaheadSecs, 30);
      expect(video.demuxerHysteresisSecs, 0);
      expect(video.cachePauseWait, 2.0);
      expect(video.networkTimeout, 10);
      expect(video.reason, PlayerBufferReason.standard);
      expect(video.bufferSize, 32 * mebibyte);

      expect(live.demuxerMaxBytes, 16 * mebibyte);
      expect(live.demuxerMaxBackBytes, 2 * mebibyte);
      expect(live.demuxerReadaheadSecs, 10);
      expect(live.demuxerHysteresisSecs, 0);
      expect(live.cachePauseWait, 1.0);
      expect(live.networkTimeout, 10);
      expect(live.reason, PlayerBufferReason.standard);
      expect(live.bufferSize, 16 * mebibyte);
    });

    test('uses cellular policy on mobile data', () {
      final video = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: false,
        vpnActive: false,
        isMobileNetwork: true,
      );
      final live = resolvePlayerBufferPolicy(
        isLive: true,
        forceExpanded: false,
        vpnActive: false,
        isMobileNetwork: true,
      );

      expect(video.demuxerMaxBytes, 16 * mebibyte);
      expect(video.demuxerMaxBackBytes, 4 * mebibyte);
      expect(video.demuxerReadaheadSecs, 30);
      expect(video.cachePauseWait, 2.0);
      expect(video.reason, PlayerBufferReason.cellular);

      expect(live.demuxerMaxBytes, 16 * mebibyte);
      expect(live.demuxerMaxBackBytes, 2 * mebibyte);
      expect(live.demuxerReadaheadSecs, 10);
      expect(live.cachePauseWait, 1.0);
      expect(live.reason, PlayerBufferReason.cellular);
    });

    test('expands video and live buffers for an active VPN', () {
      final video = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: false,
        vpnActive: true,
        isMobileNetwork: false,
      );
      final live = resolvePlayerBufferPolicy(
        isLive: true,
        forceExpanded: false,
        vpnActive: true,
        isMobileNetwork: false,
      );

      expect(video.demuxerMaxBytes, 64 * mebibyte);
      expect(video.demuxerMaxBackBytes, 8 * mebibyte);
      expect(video.demuxerReadaheadSecs, 30);
      expect(video.reason, PlayerBufferReason.vpn);

      expect(live.demuxerMaxBytes, 32 * mebibyte);
      expect(live.demuxerMaxBackBytes, 2 * mebibyte);
      expect(live.demuxerReadaheadSecs, 10);
      expect(live.reason, PlayerBufferReason.vpn);
    });

    test('the user setting forces expanded buffers on every network', () {
      final video = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: true,
        vpnActive: false,
        isMobileNetwork: true,
      );
      final live = resolvePlayerBufferPolicy(
        isLive: true,
        forceExpanded: true,
        vpnActive: false,
        isMobileNetwork: true,
      );

      expect(video.demuxerMaxBytes, 64 * mebibyte);
      expect(video.demuxerMaxBackBytes, 8 * mebibyte);
      expect(video.reason, PlayerBufferReason.userExpanded);

      expect(live.demuxerMaxBytes, 32 * mebibyte);
      expect(live.demuxerMaxBackBytes, 2 * mebibyte);
      expect(live.reason, PlayerBufferReason.userExpanded);
    });

    test(
      'the user setting takes precedence over VPN and cellular detection',
      () {
        final policy = resolvePlayerBufferPolicy(
          isLive: false,
          forceExpanded: true,
          vpnActive: true,
          isMobileNetwork: true,
        );

        expect(policy.demuxerMaxBytes, 64 * mebibyte);
        expect(policy.reason, PlayerBufferReason.userExpanded);
      },
    );

    test('VPN takes precedence over cellular detection', () {
      final policy = resolvePlayerBufferPolicy(
        isLive: false,
        forceExpanded: false,
        vpnActive: true,
        isMobileNetwork: true,
      );

      expect(policy.demuxerMaxBytes, 64 * mebibyte);
      expect(policy.reason, PlayerBufferReason.vpn);
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

    test('handles empty network list', () {
      expect(hasActiveVpn([]), isFalse);
    });

    test('handles none connectivity result', () {
      expect(hasActiveVpn([ConnectivityResult.none]), isFalse);
    });
  });

  group('hasActiveMobile', () {
    test('detects pure mobile network', () {
      expect(hasActiveMobile([ConnectivityResult.mobile]), isTrue);
    });

    test('detects mobile network alongside VPN', () {
      expect(
        hasActiveMobile([ConnectivityResult.mobile, ConnectivityResult.vpn]),
        isTrue,
      );
    });

    test('does not treat concurrent Wi-Fi + mobile as mobile restricted', () {
      expect(
        hasActiveMobile([ConnectivityResult.wifi, ConnectivityResult.mobile]),
        isFalse,
      );
    });

    test(
      'does not treat concurrent Ethernet + mobile as mobile restricted',
      () {
        expect(
          hasActiveMobile([
            ConnectivityResult.ethernet,
            ConnectivityResult.mobile,
          ]),
          isFalse,
        );
      },
    );

    test('does not treat Wi-Fi only as mobile', () {
      expect(hasActiveMobile([ConnectivityResult.wifi]), isFalse);
    });

    test('handles empty network list', () {
      expect(hasActiveMobile([]), isFalse);
    });

    test('handles none connectivity result', () {
      expect(hasActiveMobile([ConnectivityResult.none]), isFalse);
    });
  });

  group('defaultStreamLavfOptions', () {
    test('defines safe reconnect options for FFmpeg/libavformat', () {
      expect(
        defaultStreamLavfOptions,
        'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,reconnect_on_network_error=1',
      );
      expect(defaultStreamLavfOptions, contains('reconnect=1'));
      expect(defaultStreamLavfOptions, contains('reconnect_streamed=1'));
      expect(defaultStreamLavfOptions, contains('reconnect_delay_max=5'));
      expect(
        defaultStreamLavfOptions,
        contains('reconnect_on_network_error=1'),
      );
      // Ensure dangerous reconnect parameters are NOT present
      expect(defaultStreamLavfOptions, isNot(contains('reconnect_at_eof')));
      expect(
        defaultStreamLavfOptions,
        isNot(contains('reconnect_on_http_error')),
      );
    });
  });
}

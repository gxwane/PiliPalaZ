import 'package:connectivity_plus/connectivity_plus.dart';

const int _mebibyte = 1024 * 1024;

const String defaultStreamLavfOptions =
    'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,reconnect_on_network_error=1';

enum PlayerBufferReason { cellular, standard, vpn, userExpanded }

final class PlayerBufferPolicy {
  const PlayerBufferPolicy({
    required this.demuxerMaxBytes,
    required this.demuxerMaxBackBytes,
    required this.demuxerReadaheadSecs,
    required this.demuxerHysteresisSecs,
    required this.cachePauseWait,
    required this.networkTimeout,
    required this.reason,
  });

  final int demuxerMaxBytes;
  final int demuxerMaxBackBytes;
  final int demuxerReadaheadSecs;
  final int demuxerHysteresisSecs;
  final double cachePauseWait;
  final int networkTimeout;
  final PlayerBufferReason reason;

  /// 向下兼容原有使用 bufferSize 的调用与监控点
  int get bufferSize => demuxerMaxBytes;
}

PlayerBufferPolicy resolvePlayerBufferPolicy({
  required bool isLive,
  required bool forceExpanded,
  required bool vpnActive,
  required bool isMobileNetwork,
}) {
  final PlayerBufferReason reason = forceExpanded
      ? PlayerBufferReason.userExpanded
      : vpnActive
      ? PlayerBufferReason.vpn
      : isMobileNetwork
      ? PlayerBufferReason.cellular
      : PlayerBufferReason.standard;

  final int demuxerMaxBytes = switch ((isLive, reason)) {
    (false, PlayerBufferReason.userExpanded || PlayerBufferReason.vpn) =>
      64 * _mebibyte,
    (false, PlayerBufferReason.cellular) => 16 * _mebibyte,
    (false, PlayerBufferReason.standard) => 32 * _mebibyte,
    (true, PlayerBufferReason.userExpanded || PlayerBufferReason.vpn) =>
      32 * _mebibyte,
    (true, PlayerBufferReason.cellular || PlayerBufferReason.standard) =>
      16 * _mebibyte,
  };

  final int demuxerMaxBackBytes = isLive
      ? 2 * _mebibyte
      : (demuxerMaxBytes ~/ 4).clamp(2 * _mebibyte, 8 * _mebibyte);

  final int demuxerReadaheadSecs = isLive ? 10 : 30;
  const int demuxerHysteresisSecs = 0;
  final double cachePauseWait = isLive ? 1.0 : 2.0;
  const int networkTimeout = 10;

  return PlayerBufferPolicy(
    demuxerMaxBytes: demuxerMaxBytes,
    demuxerMaxBackBytes: demuxerMaxBackBytes,
    demuxerReadaheadSecs: demuxerReadaheadSecs,
    demuxerHysteresisSecs: demuxerHysteresisSecs,
    cachePauseWait: cachePauseWait,
    networkTimeout: networkTimeout,
    reason: reason,
  );
}

bool hasActiveVpn(Iterable<ConnectivityResult> results) {
  return results.contains(ConnectivityResult.vpn);
}

bool hasActiveMobile(Iterable<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet)) {
    return false;
  }
  return results.contains(ConnectivityResult.mobile);
}

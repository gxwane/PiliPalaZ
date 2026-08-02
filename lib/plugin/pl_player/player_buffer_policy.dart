import 'package:connectivity_plus/connectivity_plus.dart';

const int _mebibyte = 1024 * 1024;

enum PlayerBufferReason { standard, vpn, userExpanded }

final class PlayerBufferPolicy {
  const PlayerBufferPolicy({required this.bufferSize, required this.reason});

  final int bufferSize;
  final PlayerBufferReason reason;
}

PlayerBufferPolicy resolvePlayerBufferPolicy({
  required bool isLive,
  required bool forceExpanded,
  required bool vpnActive,
}) {
  final bool expanded = forceExpanded || vpnActive;
  final int bufferSize = switch ((isLive, expanded)) {
    (false, false) => 4 * _mebibyte,
    (true, false) => 16 * _mebibyte,
    (false, true) => 32 * _mebibyte,
    (true, true) => 64 * _mebibyte,
  };
  final PlayerBufferReason reason = forceExpanded
      ? PlayerBufferReason.userExpanded
      : vpnActive
      ? PlayerBufferReason.vpn
      : PlayerBufferReason.standard;

  return PlayerBufferPolicy(bufferSize: bufferSize, reason: reason);
}

bool hasActiveVpn(Iterable<ConnectivityResult> results) {
  return results.contains(ConnectivityResult.vpn);
}

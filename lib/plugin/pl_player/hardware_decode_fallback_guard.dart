enum HardwareDecodeFallbackAction { ignore, fallback, suppress }

enum HardwareDecodeRecoveryDecision { sourceReplaced, unavailable }

final class HardwareDecodeFailureContext {
  const HardwareDecodeFailureContext({
    required this.position,
    required this.wasPlaying,
    this.videoCodec,
    this.pixelFormat,
  });

  final Duration position;
  final bool wasPlaying;
  final String? videoCodec;
  final String? pixelFormat;
}

typedef HardwareDecodeFailureHandler =
    Future<HardwareDecodeRecoveryDecision> Function(
      HardwareDecodeFailureContext context,
    );

bool requiresAndroid8BitSoftwareOutput(String? pixelFormat) {
  final String normalized = pixelFormat?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty) return false;
  if (RegExp(r'^p0(?:10|12|16)(?:le|be)?$').hasMatch(normalized)) {
    return true;
  }
  return RegExp(
    r'^(?:yuv|gbr|gray)[a-z0-9_]*?(?:9|10|12|14|16)(?:le|be)?$',
  ).hasMatch(normalized);
}

final class HardwareDecodeFallbackGuard {
  int? _session;
  bool _enabled = false;
  bool _attempted = false;

  void beginSession(int session, {required bool enabled}) {
    _session = session;
    _enabled = enabled;
    _attempted = false;
  }

  HardwareDecodeFallbackAction evaluate(int session, String error) {
    if (session != _session || !error.startsWith('Could not open codec')) {
      return HardwareDecodeFallbackAction.ignore;
    }
    if (_attempted) return HardwareDecodeFallbackAction.suppress;
    if (!_enabled) return HardwareDecodeFallbackAction.ignore;
    _attempted = true;
    return HardwareDecodeFallbackAction.fallback;
  }

  void finishFallback(int session) {
    if (session == _session) _enabled = false;
  }
}

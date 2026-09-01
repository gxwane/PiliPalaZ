import '../../http/log_sanitizer.dart';

const Set<String> _allowedPlayerDetailKeys = <String>{
  'bufferReason',
  'bufferSize',
  'compatibilityFilterApplied',
  'current-vo',
  'decoder-frame-drop-count',
  'decision',
  'effectiveHwdec',
  'enableHardwareAcceleration',
  'error',
  'estimated-vf-fps',
  'expandedBuffer',
  'fbo-format',
  'frame-drop-count',
  'hardwareAcceleration',
  'height',
  'hwdec',
  'hwdec-current',
  'isBuffering',
  'requires8BitOutput',
  'reuse',
  'video-codec',
  'video-format',
  'video-params/pixelformat',
  'video-out-params/pixelformat',
  'videoRect',
  'videoSync',
  'vo-configured',
  'wasPlaying',
  'width',
};

final RegExp _urlPattern = RegExp(r'''https?://[^\s\]\[\)\("'<>]+''');
final RegExp _bvidPattern = RegExp(r'BV[0-9A-Za-z]{10}', caseSensitive: false);
final RegExp _contentIdPattern = RegExp(
  r'\b(bvid|aid|cid|ep(?:_?id)?|season(?:_?id)?|mid)(\s*[=:]\s*)([^\s,;}]+)',
  caseSensitive: false,
);
final RegExp _androidPathPattern = RegExp(
  r'/(?:data/(?:user/\d+|data|app)|storage/emulated/\d+)/[^\s:]+',
  caseSensitive: false,
);
final RegExp _applePathPattern = RegExp(
  r'/(?:private/)?var/mobile/Containers/(?:Data|Bundle)/Application/[^\s:]+',
  caseSensitive: false,
);
final RegExp _unixHomePathPattern = RegExp(
  r'/(?:Users|home)/[^/\s:]+/[^\s:]+',
  caseSensitive: false,
);
final RegExp _windowsPathPattern = RegExp(
  r'[A-Za-z]:\\(?:Users|Documents and Settings)\\[^\s:]+',
  caseSensitive: false,
);

String sanitizeDiagnosticText(Object? value, {int maxLength = 4096}) {
  String output = redactSensitiveLog(value);
  output = output.replaceAll(_urlPattern, '<url>');
  output = output.replaceAll(_bvidPattern, '<content-id>');
  output = output.replaceAllMapped(
    _contentIdPattern,
    (match) => '${match.group(1)}${match.group(2)}<content-id>',
  );
  output = output.replaceAll(_androidPathPattern, '<app-path>');
  output = output.replaceAll(_applePathPattern, '<app-path>');
  output = output.replaceAll(_unixHomePathPattern, '<app-path>');
  output = output.replaceAll(_windowsPathPattern, '<app-path>');
  return output.length <= maxLength ? output : output.substring(0, maxLength);
}

Map<String, Object?> sanitizePlayerDetails(Map<String, Object?> details) {
  final output = <String, Object?>{};
  for (final entry in details.entries) {
    if (!_allowedPlayerDetailKeys.contains(entry.key) || entry.value == null) {
      continue;
    }
    final value = entry.value;
    if (value is num || value is bool) {
      output[entry.key] = value;
    } else if (value is String) {
      output[entry.key] = sanitizeDiagnosticText(value, maxLength: 2048);
    } else {
      output[entry.key] = sanitizeDiagnosticText(
        value.toString(),
        maxLength: 2048,
      );
    }
  }
  return output;
}

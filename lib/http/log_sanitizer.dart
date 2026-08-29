const String _redactedValue = '<redacted>';

const String _sensitiveFieldNames =
    r'access_key|access_token|refresh_token|SESSDATA|bili_jct|csrf_token|csrf';

final RegExp _equalsFieldPattern = RegExp(
  '($_sensitiveFieldNames)=([^&;\\s,}]+)',
  caseSensitive: false,
);

final RegExp _jsonFieldPattern = RegExp(
  '("(?:$_sensitiveFieldNames)"\\s*:\\s*")([^"]*)(")',
  caseSensitive: false,
);

final RegExp _mapFieldPattern = RegExp(
  '($_sensitiveFieldNames)(\\s*:\\s*)([^,\\s}]+)',
  caseSensitive: false,
);

String redactSensitiveLog(Object? message) {
  String output = message?.toString() ?? '';
  output = output.replaceAllMapped(
    _equalsFieldPattern,
    (Match match) => '${match.group(1)}=$_redactedValue',
  );
  output = output.replaceAllMapped(
    _jsonFieldPattern,
    (Match match) => '${match.group(1)}$_redactedValue${match.group(3)}',
  );
  return output.replaceAllMapped(
    _mapFieldPattern,
    (Match match) => '${match.group(1)}${match.group(2)}$_redactedValue',
  );
}

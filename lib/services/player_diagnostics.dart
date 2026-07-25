import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String playerDiagnosticSeparator =
    '======================================================================';
const int _maxDiagnosticCharacters = 512 * 1024;

String sanitizeMediaUri(String? source) {
  if (source == null || source.isEmpty) return '';
  final Uri? uri = Uri.tryParse(source);
  if (uri == null || uri.host.isEmpty) return '<invalid-uri>';
  final String port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

String redactDiagnosticText(String value) {
  return value.replaceAllMapped(
    RegExp(r'https?://[^\s]+'),
    (match) => sanitizeMediaUri(match.group(0)),
  );
}

String trimDiagnosticContent(
  String content, {
  int maxCharacters = _maxDiagnosticCharacters,
}) {
  if (content.length <= maxCharacters) return content;
  final String tail = content.substring(content.length - maxCharacters);
  final int firstNewline = tail.indexOf('\n');
  return firstNewline == -1 ? tail : tail.substring(firstNewline + 1);
}

Future<File> getPlayerDiagnosticsPath() async {
  final String directory = (await getApplicationDocumentsDirectory()).path;
  final File file = File(p.join(directory, '.pili_player_logs'));
  if (!await file.exists()) {
    await file.create(recursive: true);
  }
  return file;
}

class PlayerDiagnosticSession {
  PlayerDiagnosticSession._(this.id, this._owner);

  final String id;
  final PlayerDiagnostics _owner;
  bool _completed = false;

  Future<void> checkpoint(
    String event, [
    Map<String, Object?> fields = const {},
  ]) async {
    if (_completed) return;
    try {
      await _owner._writeEvent(id, event, fields);
    } catch (_) {}
  }

  Future<void> complete([
    String event = 'session_complete',
    Map<String, Object?> fields = const {},
  ]) async {
    if (_completed) return;
    _completed = true;
    try {
      await _owner._completeSession(id, event, fields);
    } catch (_) {}
  }
}

class PlayerDiagnostics {
  PlayerDiagnostics._();

  static final PlayerDiagnostics instance = PlayerDiagnostics._();

  Future<void> _writeQueue = Future<void>.value();
  int _sessionCounter = 0;

  Future<PlayerDiagnosticSession> startSession({
    required Map<String, Object?> context,
  }) async {
    final String id =
        '${DateTime.now().microsecondsSinceEpoch}-${_sessionCounter++}';
    final Map<String, Object?> device = await _deviceContext();
    final String header = [
      '========================== PLAYER DIAGNOSTIC LOG ==========================',
      'Diagnostic occurred on ${DateTime.now().toIso8601String()}',
      _encodeEvent(id, 'session_start', {...device, ...context}),
    ].join('\n');
    try {
      await _append('$header\n', closeIncompleteSession: true);
    } catch (_) {}
    return PlayerDiagnosticSession._(id, this);
  }

  Future<void> record(
    String event, [
    Map<String, Object?> fields = const {},
  ]) async {
    final String id = 'standalone-${DateTime.now().microsecondsSinceEpoch}';
    final String block = [
      '========================== PLAYER DIAGNOSTIC LOG ==========================',
      'Diagnostic occurred on ${DateTime.now().toIso8601String()}',
      _encodeEvent(id, event, fields),
      playerDiagnosticSeparator,
      '',
    ].join('\n');
    try {
      await _append(block, closeIncompleteSession: true);
    } catch (_) {}
  }

  Future<String> read() async {
    try {
      await _writeQueue;
      final File file = await getPlayerDiagnosticsPath();
      return file.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<void> clear() {
    return _enqueue(() async {
      final File file = await getPlayerDiagnosticsPath();
      await file.writeAsString('');
    });
  }

  Future<void> _writeEvent(
    String sessionId,
    String event,
    Map<String, Object?> fields,
  ) {
    return _append('${_encodeEvent(sessionId, event, fields)}\n');
  }

  Future<void> _completeSession(
    String sessionId,
    String event,
    Map<String, Object?> fields,
  ) {
    return _append(
      '${_encodeEvent(sessionId, event, fields)}\n'
      '$playerDiagnosticSeparator\n',
    );
  }

  String _encodeEvent(
    String sessionId,
    String event,
    Map<String, Object?> fields,
  ) {
    return jsonEncode({
      'time': DateTime.now().toIso8601String(),
      'session': sessionId,
      'event': event,
      for (final entry in fields.entries) entry.key: _redactValue(entry.value),
    });
  }

  Object? _redactValue(Object? value) {
    if (value is String) return redactDiagnosticText(value);
    if (value is Iterable) {
      return value.map<Object?>((item) => _redactValue(item)).toList();
    }
    if (value is Map) {
      return value.map<String, Object?>(
        (key, item) => MapEntry(key.toString(), _redactValue(item)),
      );
    }
    return value;
  }

  Future<Map<String, Object?>> _deviceContext() async {
    final Map<String, Object?> context = {
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
    };
    if (!Platform.isAndroid) return context;
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      context.addAll({
        'manufacturer': info.manufacturer,
        'model': info.model,
        'androidSdk': info.version.sdkInt,
        'supportedAbis': info.supportedAbis,
      });
    } catch (_) {}
    return context;
  }

  Future<void> _append(String text, {bool closeIncompleteSession = false}) {
    return _enqueue(() async {
      final File file = await getPlayerDiagnosticsPath();
      String content = await file.readAsString();
      if (closeIncompleteSession &&
          content.trim().isNotEmpty &&
          !content.trimRight().endsWith(playerDiagnosticSeparator)) {
        content = '$content$playerDiagnosticSeparator\n';
      }
      content = trimDiagnosticContent('$content$text');
      await file.writeAsString(content, flush: true);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> queued = _writeQueue.then((_) => operation());
    _writeQueue = queued.catchError((_) {});
    return queued;
  }
}

import 'dart:convert';
import 'dart:io';

import 'diagnostic_record.dart';

class DiagnosticStore {
  DiagnosticStore({
    required this.file,
    DateTime Function()? now,
    this.maxBytes = 1024 * 1024,
    this.retention = const Duration(days: 7),
  }) : _now = now ?? DateTime.now;

  final File file;
  final int maxBytes;
  final Duration retention;
  final DateTime Function() _now;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> append(DiagnosticRecord record) {
    return _serialize(() async {
      final records = await _readFile();
      records.add(record);
      await _rewrite(_prune(records));
    });
  }

  Future<List<DiagnosticRecord>> read() {
    return _serialize(() async {
      final records = await _readFile();
      final pruned = _prune(records);
      if (pruned.length != records.length) await _rewrite(pruned);
      return List<DiagnosticRecord>.unmodifiable(pruned);
    });
  }

  Future<void> clear() {
    return _serialize(() async {
      await file.parent.create(recursive: true);
      await file.writeAsString('', flush: true);
    });
  }

  Future<List<DiagnosticRecord>> _readFile() async {
    if (!await file.exists()) return <DiagnosticRecord>[];
    final content = await file.readAsString();
    final records = <DiagnosticRecord>[];
    for (final line in const LineSplitter().convert(content)) {
      if (line.trim().isEmpty) continue;
      try {
        final value = jsonDecode(line);
        if (value is Map) {
          records.add(
            DiagnosticRecord.fromJson(
              value.map<String, dynamic>(
                (key, item) => MapEntry(key.toString(), item),
              ),
            ),
          );
        }
      } catch (_) {}
    }
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return records;
  }

  List<DiagnosticRecord> _prune(List<DiagnosticRecord> records) {
    final cutoff = _now().toUtc().subtract(retention);
    final candidates =
        records
            .where((record) => !record.timestamp.toUtc().isBefore(cutoff))
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final selected = <DiagnosticRecord>[];
    var bytes = 0;
    for (final record in candidates.reversed) {
      final length = utf8.encode('${jsonEncode(record.toJson())}\n').length;
      if (length > maxBytes || bytes + length > maxBytes) continue;
      selected.insert(0, record);
      bytes += length;
    }
    return selected;
  }

  Future<void> _rewrite(List<DiagnosticRecord> records) async {
    await file.parent.create(recursive: true);
    final content = records
        .map((record) => jsonEncode(record.toJson()))
        .join('\n');
    await file.writeAsString(content.isEmpty ? '' : '$content\n', flush: true);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final queued = _writeQueue.then((_) => operation());
    _writeQueue = queued.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return queued;
  }
}

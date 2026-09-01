import 'diagnostics/diagnostic_record.dart';
import 'diagnostics/diagnostic_sanitizer.dart';
import 'diagnostics/local_diagnostics.dart';

const int _maxBreadcrumbs = 50;

class PlayerDiagnosticSession {
  PlayerDiagnosticSession._(this.id, this._owner);

  final String id;
  final PlayerDiagnostics _owner;
  final List<DiagnosticBreadcrumb> _breadcrumbs = <DiagnosticBreadcrumb>[];
  bool _completed = false;

  Future<void> checkpoint(
    String event, [
    Map<String, Object?> fields = const <String, Object?>{},
  ]) async {
    if (_completed) return;
    _breadcrumbs.add(
      DiagnosticBreadcrumb(
        timestamp: _owner._now().toUtc(),
        event: sanitizeDiagnosticText(event, maxLength: 64),
        details: sanitizePlayerDetails(fields),
      ),
    );
    if (_breadcrumbs.length > _maxBreadcrumbs) _breadcrumbs.removeAt(0);
  }

  Future<void> reportFailure(
    DiagnosticFailureKind kind,
    Object error,
    StackTrace? stackTrace, {
    bool completeSession = false,
  }) async {
    if (_completed) return;
    await checkpoint('failure', <String, Object?>{'error': error.toString()});
    await _owner._diagnostics.recordFailure(
      kind,
      error,
      stackTrace,
      breadcrumbs: List<DiagnosticBreadcrumb>.unmodifiable(_breadcrumbs),
    );
    if (completeSession) {
      _completed = true;
      _breadcrumbs.clear();
    }
  }

  Future<void> complete([
    String event = 'session_complete',
    Map<String, Object?> fields = const <String, Object?>{},
  ]) async {
    if (_completed) return;
    await checkpoint(event, fields);
    _completed = true;
    _breadcrumbs.clear();
  }
}

class PlayerDiagnostics {
  PlayerDiagnostics({LocalDiagnostics? diagnostics, DateTime Function()? now})
    : _diagnostics = diagnostics ?? LocalDiagnostics.instance,
      _now = now ?? DateTime.now;

  static final PlayerDiagnostics instance = PlayerDiagnostics();

  final LocalDiagnostics _diagnostics;
  final DateTime Function() _now;
  int _sessionCounter = 0;

  Future<PlayerDiagnosticSession> startSession({
    required Map<String, Object?> context,
  }) async {
    final session = PlayerDiagnosticSession._(
      'player-${_sessionCounter++}',
      this,
    );
    await session.checkpoint('session_start', context);
    return session;
  }
}

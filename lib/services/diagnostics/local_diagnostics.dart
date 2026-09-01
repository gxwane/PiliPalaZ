import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diagnostic_record.dart';
import 'diagnostic_sanitizer.dart';
import 'diagnostic_store.dart';

typedef DiagnosticDirectoryProvider = Future<Directory> Function();
typedef DiagnosticEnvironmentLoader = Future<DiagnosticEnvironment> Function();

class LocalDiagnostics {
  LocalDiagnostics({
    required DiagnosticDirectoryProvider directoryProvider,
    required DiagnosticEnvironmentLoader environmentLoader,
    DateTime Function()? now,
  }) : _directoryProvider = directoryProvider,
       _environmentLoader = environmentLoader,
       _now = now ?? DateTime.now;

  LocalDiagnostics.production()
    : this(
        directoryProvider: getApplicationDocumentsDirectory,
        environmentLoader: loadDiagnosticEnvironment,
      );

  static final LocalDiagnostics instance = LocalDiagnostics.production();

  final DiagnosticDirectoryProvider _directoryProvider;
  final DiagnosticEnvironmentLoader _environmentLoader;
  final DateTime Function() _now;
  final List<_PendingFailure> _pendingFailures = <_PendingFailure>[];
  final Map<String, DateTime> _recentFailures = <String, DateTime>{};

  DiagnosticStore? _store;
  File? _configFile;
  bool _initialized = false;
  bool _enabled = false;
  bool _hooksInstalled = false;
  FlutterExceptionHandler? _previousFlutterHandler;
  bool Function(Object, StackTrace)? _previousPlatformHandler;

  bool get enabled => _enabled;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final directory = await _directoryProvider();
      await directory.create(recursive: true);
      _configFile = File(
        p.join(directory.path, '.pili_diagnostics_config.json'),
      );
      _store = DiagnosticStore(
        file: File(p.join(directory.path, '.pili_diagnostics.jsonl')),
        now: _now,
      );
      await _deleteLegacyFiles(directory);
      _enabled = await _readEnabledConfig();
      await _store!.read();
    } catch (_) {
      _enabled = false;
      _store = null;
    } finally {
      _initialized = true;
    }

    final pending = List<_PendingFailure>.of(_pendingFailures);
    _pendingFailures.clear();
    if (_enabled) {
      for (final failure in pending) {
        await recordFailure(
          failure.kind,
          failure.error,
          failure.stackTrace,
          breadcrumbs: failure.breadcrumbs,
        );
      }
    }
  }

  void installGlobalErrorHandlers() {
    if (_hooksInstalled) return;
    _hooksInstalled = true;
    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(
        recordFailure(
          DiagnosticFailureKind.flutterFramework,
          details.exception,
          details.stack,
        ),
      );
      final previous = _previousFlutterHandler;
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        recordFailure(
          DiagnosticFailureKind.platformUnhandled,
          error,
          stackTrace,
        ),
      );
      return _previousPlatformHandler?.call(error, stackTrace) ?? true;
    };
  }

  Future<void> setEnabled(bool value, {required bool clearExisting}) async {
    if (!_initialized) await initialize();
    final configFile = _configFile;
    if (configFile == null) throw StateError('本地诊断存储不可用');
    await configFile.writeAsString(
      jsonEncode(<String, Object?>{'enabled': value}),
      flush: true,
    );
    _enabled = value;
    if (!value) _pendingFailures.clear();
    if (clearExisting) await clear();
  }

  Future<void> recordFailure(
    DiagnosticFailureKind kind,
    Object error,
    StackTrace? stackTrace, {
    List<DiagnosticBreadcrumb> breadcrumbs = const <DiagnosticBreadcrumb>[],
  }) async {
    if (!_initialized) {
      if (_pendingFailures.length == 5) _pendingFailures.removeAt(0);
      _pendingFailures.add(
        _PendingFailure(kind, error, stackTrace, breadcrumbs),
      );
      return;
    }
    final store = _store;
    if (!_enabled || store == null) return;

    try {
      final message = sanitizeDiagnosticText(error);
      final sanitizedStack = sanitizeDiagnosticText(
        stackTrace,
        maxLength: 32 * 1024,
      );
      final fingerprint =
          '$kind|${error.runtimeType}|$message|'
          '${sanitizedStack.split('\n').firstOrNull ?? ''}';
      final timestamp = _now().toUtc();
      final previous = _recentFailures[fingerprint];
      if (previous != null &&
          timestamp.difference(previous) < const Duration(seconds: 3)) {
        return;
      }
      _recentFailures[fingerprint] = timestamp;
      _recentFailures.removeWhere(
        (_, time) => timestamp.difference(time) > const Duration(minutes: 1),
      );

      DiagnosticEnvironment environment;
      try {
        environment = await _environmentLoader();
      } catch (_) {
        environment = DiagnosticEnvironment(
          appVersion: '',
          buildNumber: '',
          platform: Platform.operatingSystem,
          osVersion: '',
        );
      }
      final safeBreadcrumbs = breadcrumbs
          .map(
            (item) => DiagnosticBreadcrumb(
              timestamp: item.timestamp,
              event: sanitizeDiagnosticText(item.event, maxLength: 64),
              details: sanitizePlayerDetails(item.details),
            ),
          )
          .toList(growable: false);
      await store.append(
        DiagnosticRecord(
          timestamp: timestamp,
          kind: kind,
          errorType: error.runtimeType.toString(),
          message: message,
          stackTrace: sanitizedStack,
          environment: environment,
          breadcrumbs: safeBreadcrumbs.length <= 50
              ? safeBreadcrumbs
              : safeBreadcrumbs.sublist(safeBreadcrumbs.length - 50),
        ),
      );
    } catch (_) {}
  }

  Future<List<DiagnosticRecord>> readFailures() async {
    try {
      return await _store?.read() ?? const <DiagnosticRecord>[];
    } catch (_) {
      return const <DiagnosticRecord>[];
    }
  }

  Future<int> storageBytes() async {
    try {
      final file = _store?.file;
      return file != null && await file.exists() ? await file.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      await _store?.clear();
    } catch (_) {}
  }

  Future<bool> _readEnabledConfig() async {
    final configFile = _configFile!;
    if (!await configFile.exists()) return true;
    try {
      final value = jsonDecode(await configFile.readAsString());
      return value is Map && value['enabled'] is bool
          ? value['enabled'] as bool
          : false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteLegacyFiles(Directory directory) async {
    for (final name in <String>['.pili_logs', '.pili_player_logs']) {
      try {
        final file = File(p.join(directory.path, name));
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}

class _PendingFailure {
  const _PendingFailure(
    this.kind,
    this.error,
    this.stackTrace,
    this.breadcrumbs,
  );

  final DiagnosticFailureKind kind;
  final Object error;
  final StackTrace? stackTrace;
  final List<DiagnosticBreadcrumb> breadcrumbs;
}

Future<DiagnosticEnvironment> loadDiagnosticEnvironment() async {
  String appVersion = '';
  String buildNumber = '';
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;
    buildNumber = packageInfo.buildNumber;
  } catch (_) {}

  if (Platform.isAndroid) {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return DiagnosticEnvironment(
        appVersion: appVersion,
        buildNumber: buildNumber,
        platform: 'android',
        osVersion: info.version.sdkInt.toString(),
        manufacturer: info.manufacturer,
        model: info.model,
        supportedAbis: info.supportedAbis,
      );
    } catch (_) {}
  }
  if (Platform.isIOS) {
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      return DiagnosticEnvironment(
        appVersion: appVersion,
        buildNumber: buildNumber,
        platform: 'ios',
        osVersion: info.systemVersion.split('.').first,
        manufacturer: 'Apple',
        model: info.utsname.machine,
      );
    } catch (_) {}
  }
  return DiagnosticEnvironment(
    appVersion: appVersion,
    buildNumber: buildNumber,
    platform: Platform.operatingSystem,
    osVersion: '',
  );
}

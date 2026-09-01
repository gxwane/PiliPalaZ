import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';

void main() {
  late Directory directory;
  late DateTime now;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pilipalaz-local-diag-');
    now = DateTime.utc(2026, 9, 1, 12);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  LocalDiagnostics buildDiagnostics({
    Future<DiagnosticEnvironment> Function()? environmentLoader,
  }) {
    return LocalDiagnostics(
      directoryProvider: () async => directory,
      environmentLoader:
          environmentLoader ??
          () async => const DiagnosticEnvironment(
            appVersion: '1.3.1',
            buildNumber: '114535',
            platform: 'android',
            osVersion: '36',
            manufacturer: 'Example',
            model: 'Device',
            supportedAbis: <String>['arm64-v8a'],
          ),
      now: () => now,
    );
  }

  test('defaults to enabled and persists a sanitized failure', () async {
    final diagnostics = buildDiagnostics();
    await diagnostics.initialize();

    await diagnostics.recordFailure(
      DiagnosticFailureKind.videoPlaybackInitialization,
      StateError('Failed BV1xx411c7mD at https://example.com/private'),
      StackTrace.fromString('#0 /data/user/0/app/private.dart:1'),
    );

    final records = await diagnostics.readFailures();
    expect(diagnostics.enabled, isTrue);
    expect(records, hasLength(1));
    expect(records.single.message, isNot(contains('BV1xx411c7mD')));
    expect(records.single.message, isNot(contains('example.com')));
    expect(records.single.stackTrace, isNot(contains('/data/user/0')));
  });

  test(
    'disabled diagnostics neither loads environment nor writes failures',
    () async {
      var environmentLoads = 0;
      final diagnostics = buildDiagnostics(
        environmentLoader: () async {
          environmentLoads++;
          throw StateError('must not load');
        },
      );
      await diagnostics.initialize();
      await diagnostics.setEnabled(false, clearExisting: true);

      await diagnostics.recordFailure(
        DiagnosticFailureKind.flutterFramework,
        Exception('ignored'),
        StackTrace.current,
      );

      expect(environmentLoads, 0);
      expect(await diagnostics.readFailures(), isEmpty);
    },
  );

  test('malformed existing config fails closed', () async {
    await File(
      '${directory.path}${Platform.pathSeparator}.pili_diagnostics_config.json',
    ).writeAsString('{broken');
    final diagnostics = buildDiagnostics();

    await diagnostics.initialize();

    expect(diagnostics.enabled, isFalse);
  });

  test('removes legacy diagnostics during initialization', () async {
    final oldCatcher = File(
      '${directory.path}${Platform.pathSeparator}.pili_logs',
    );
    final oldPlayer = File(
      '${directory.path}${Platform.pathSeparator}.pili_player_logs',
    );
    await oldCatcher.writeAsString('legacy');
    await oldPlayer.writeAsString('legacy');

    await buildDiagnostics().initialize();

    expect(await oldCatcher.exists(), isFalse);
    expect(await oldPlayer.exists(), isFalse);
  });

  test('persists failures captured before initialization', () async {
    final diagnostics = buildDiagnostics();

    await diagnostics.recordFailure(
      DiagnosticFailureKind.platformUnhandled,
      StateError('startup failure'),
      StackTrace.current,
    );
    await diagnostics.initialize();

    expect(await diagnostics.readFailures(), hasLength(1));
  });

  test(
    'deduplicates identical failures inside the three second window',
    () async {
      final diagnostics = buildDiagnostics();
      await diagnostics.initialize();

      Future<void> record() => diagnostics.recordFailure(
        DiagnosticFailureKind.flutterFramework,
        StateError('duplicate'),
        StackTrace.fromString('#0 duplicate (package:pilipalaz/main.dart:1)'),
      );

      await record();
      await record();
      now = now.add(const Duration(seconds: 3));
      await record();

      expect(await diagnostics.readFailures(), hasLength(2));
    },
  );

  test('can disable without deleting existing diagnostics', () async {
    final diagnostics = buildDiagnostics();
    await diagnostics.initialize();
    await diagnostics.recordFailure(
      DiagnosticFailureKind.flutterFramework,
      StateError('existing'),
      StackTrace.current,
    );

    await diagnostics.setEnabled(false, clearExisting: false);
    await diagnostics.recordFailure(
      DiagnosticFailureKind.flutterFramework,
      StateError('ignored'),
      StackTrace.current,
    );

    expect(diagnostics.enabled, isFalse);
    expect(await diagnostics.readFailures(), hasLength(1));

    final reloaded = buildDiagnostics();
    await reloaded.initialize();
    expect(reloaded.enabled, isFalse);
    expect(await reloaded.readFailures(), hasLength(1));
  });
}

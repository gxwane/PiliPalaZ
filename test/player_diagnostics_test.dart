import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';
import 'package:pilipalaz/services/player_diagnostics.dart';

void main() {
  late Directory directory;
  late DateTime now;
  late LocalDiagnostics localDiagnostics;
  late PlayerDiagnostics playerDiagnostics;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pilipalaz-player-diag-');
    now = DateTime.utc(2026, 9, 1, 12);
    localDiagnostics = LocalDiagnostics(
      directoryProvider: () async => directory,
      environmentLoader: () async => const DiagnosticEnvironment(
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
    await localDiagnostics.initialize();
    playerDiagnostics = PlayerDiagnostics(
      diagnostics: localDiagnostics,
      now: () => now,
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('successful player sessions never persist normal activity', () async {
    final session = await playerDiagnostics.startSession(
      context: <String, Object?>{
        'bvid': 'BV1xx411c7mD',
        'videoSource': 'https://upos.example.com/video.m4s?token=private',
        'enableHardwareAcceleration': true,
      },
    );
    await session.checkpoint('media_open_complete');
    await session.complete();

    expect(await localDiagnostics.readFailures(), isEmpty);
  });

  test('failure persists only sanitized compatibility breadcrumbs', () async {
    final session = await playerDiagnostics.startSession(
      context: <String, Object?>{
        'bvid': 'BV1xx411c7mD',
        'cid': 123456,
        'videoSource': 'https://upos.example.com/video.m4s?token=private',
        'enableHardwareAcceleration': true,
        'hwdec': 'auto-safe',
      },
    );
    await session.checkpoint('native_player_prepare', <String, Object?>{
      'positionMs': 60000,
      'video-codec': 'hevc',
      'video-out-params/pixelformat': 'p010',
      'width': 3840,
      'height': 2160,
    });

    await session.reportFailure(
      DiagnosticFailureKind.playerNativeFailure,
      StateError('Failed https://upos.example.com/private.m4s'),
      StackTrace.current,
      completeSession: true,
    );

    final record = (await localDiagnostics.readFailures()).single;
    final encoded = record.toJson().toString();
    expect(encoded, isNot(contains('BV1xx411c7mD')));
    expect(encoded, isNot(contains('123456')));
    expect(encoded, isNot(contains('upos.example.com')));
    expect(encoded, isNot(contains('positionMs')));
    expect(encoded, contains('video-codec: hevc'));
    expect(encoded, contains('width: 3840'));
  });
}

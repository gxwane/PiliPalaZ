import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/plugin/pl_player/volume_coordinator.dart';

void main() {
  group('MasterVolumeEchoGuard', () {
    late MasterVolumeEchoGuard echoGuard;

    setUp(() {
      echoGuard = MasterVolumeEchoGuard();
    });

    test('recognizes programmatic expected step as echo', () {
      echoGuard.registerExpectedStep(6);
      expect(echoGuard.expectedHardwareStep, 6);

      // Raw system volume corresponding to step 6 (6 / 15 = 0.4)
      expect(echoGuard.isEchoEvent(6 / 15.0), isTrue);

      // Echo is consumed, expected step cleared
      expect(echoGuard.expectedHardwareStep, isNull);
    });

    test('treats unexpected external volume change as physical key event', () {
      // No expected step registered
      expect(echoGuard.isEchoEvent(5 / 15.0), isFalse);
    });

    test(
      'suppresses jitter within immediate 150ms window after registration',
      () {
        echoGuard.registerExpectedStep(8);
        // Immediately receives intermediate step 7
        expect(echoGuard.isEchoEvent(7 / 15.0), isTrue);
      },
    );
  });

  group('PlaybackVolumeCoordinator', () {
    late PlaybackVolumeCoordinator coordinator;

    setUp(() {
      coordinator = PlaybackVolumeCoordinator();
    });

    test('initializes with default values', () {
      expect(coordinator.masterVolume, 1.0);
      expect(coordinator.userVolume, 1.0);
      expect(coordinator.hardwareStep, 15);
      expect(coordinator.engineMicroGain, 1.0);
      expect(coordinator.loudnessFactor, 1.0);
      expect(coordinator.duckFactor, 1.0);
      expect(coordinator.enableLoudnessBalance, isTrue);
      expect(coordinator.effectiveVolume, 1.0);
    });

    test('calculates required step correctly across volume boundaries', () {
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(0.0), 0);
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(0.00005), 0);
      // Night micro-volume: 1% to 6.67% maps to step 1
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(0.01), 1);
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(0.03), 1);
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(0.06), 1);
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(1.0 / 15.0), 1);
      // Higher steps
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(0.10), 2);
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(0.50), 8);
      expect(PlaybackVolumeCoordinator.calculateRequiredStep(1.00), 15);
    });

    test('engine micro-gain interpolates smoothly within hardware step', () {
      coordinator.initFromSystem(15, 1.0);
      coordinator.setMasterVolume(0.5);
      expect(coordinator.masterVolume, 0.5);
      // At step 15 (base 1.0), micro gain = 0.5 / 1.0 = 0.5
      expect(coordinator.engineMicroGain, closeTo(0.5, 0.001));
      expect(coordinator.effectiveVolume, closeTo(0.5, 0.001));

      // After compaction to step 8 (base 8/15 = 0.5333)
      coordinator.updateHardwareStep(8);
      // micro gain = 0.5 / (8 / 15) = 0.9375
      expect(coordinator.engineMicroGain, closeTo(0.9375, 0.001));
      // Total acoustic output: (8 / 15) * 0.9375 == 0.5
      final double totalAcousticOutput =
          (coordinator.hardwareStep / 15.0) * coordinator.engineMicroGain;
      expect(totalAcousticOutput, closeTo(0.5, 0.001));
    });

    test(
      'night micro-volume (1% to 6%) maintains step 1 with pure PCM scaling',
      () {
        coordinator.initFromSystem(1, 1.0 / 15.0);

        // 1%
        coordinator.setMasterVolume(0.01);
        expect(coordinator.engineMicroGain, closeTo(0.01 * 15.0, 0.001));
        expect(
          (1.0 / 15.0) * coordinator.engineMicroGain,
          closeTo(0.01, 0.001),
        );

        // 2%
        coordinator.setMasterVolume(0.02);
        expect(coordinator.engineMicroGain, closeTo(0.02 * 15.0, 0.001));
        expect(
          (1.0 / 15.0) * coordinator.engineMicroGain,
          closeTo(0.02, 0.001),
        );

        // 3%
        coordinator.setMasterVolume(0.03);
        expect(coordinator.engineMicroGain, closeTo(0.03 * 15.0, 0.001));
        expect(
          (1.0 / 15.0) * coordinator.engineMicroGain,
          closeTo(0.03, 0.001),
        );

        // Step up / compaction checks return null because step 1 is optimal
        expect(coordinator.checkHardwareStepUpNeeded(), isNull);
        expect(coordinator.checkHardwareStepCompactionNeeded(), isNull);
      },
    );

    test(
      'checkHardwareStepUpNeeded triggers only when exceeding current step ceiling',
      () {
        coordinator.initFromSystem(5, 5 / 15.0); // 0.333
        coordinator.setMasterVolume(0.30); // downward -> no step up needed
        expect(coordinator.checkHardwareStepUpNeeded(), isNull);

        coordinator.setMasterVolume(
          0.40,
        ); // upward -> exceeds step 5 (0.333), needs step 6
        expect(coordinator.checkHardwareStepUpNeeded(), 6);
      },
    );

    test(
      'checkHardwareStepCompactionNeeded identifies lower optimal step on release',
      () {
        coordinator.initFromSystem(12, 12 / 15.0); // 0.80
        coordinator.setMasterVolume(0.20); // user slid down to 20%
        // Optimal step for 0.20 is step 3 (0.20 * 15 = 3)
        expect(coordinator.checkHardwareStepCompactionNeeded(), 3);
      },
    );

    test(
      'syncFromHardwareKey aligns master volume on step change and ignores unchanged redundant step',
      () {
        coordinator.initFromSystem(5, 5 / 15.0);
        coordinator.setMasterVolume(0.25); // microGain is 0.25 / (5/15) = 0.75
        expect(coordinator.engineMicroGain, closeTo(0.75, 0.001));

        // Redundant broadcast with same step 5 (e.g. switching video or focus change)
        final bool unchangedResult = coordinator.syncFromHardwareKey(5);
        expect(unchangedResult, isFalse);
        // Master volume and micro-gain are NOT overwritten or reset
        expect(coordinator.masterVolume, 0.25);
        expect(coordinator.engineMicroGain, closeTo(0.75, 0.001));

        // Genuine physical button press to step 6
        final bool changedResult = coordinator.syncFromHardwareKey(6);
        expect(changedResult, isTrue);
        expect(coordinator.hardwareStep, 6);
        expect(coordinator.masterVolume, closeTo(6 / 15.0, 0.001));
        expect(coordinator.engineMicroGain, closeTo(1.0, 0.001));
      },
    );

    test('updates user volume within bounds', () {
      expect(coordinator.setUserVolume(0.5), isTrue);
      expect(coordinator.masterVolume, 0.5);

      // Clamp test
      coordinator.setUserVolume(1.5);
      expect(coordinator.masterVolume, 1.0);
      coordinator.setUserVolume(-0.2);
      expect(coordinator.masterVolume, 0.0);
      expect(coordinator.engineMicroGain, 0.0);
      expect(coordinator.effectiveVolume, 0.0);
    });

    test('calculates attenuation for negative targetOffset', () {
      // -6 dB is roughly 0.501187 factor
      const meta = AudioVolumeMetadata(
        targetOffset: -6.0,
        targetTp: -1.0,
        measuredTp: -1.0,
      );

      expect(coordinator.updateLoudnessMetadata(meta), isTrue);
      expect(coordinator.loudnessFactor, closeTo(0.501, 0.005));
      expect(coordinator.effectiveVolume, closeTo(0.501, 0.005));
    });

    test(
      'enforces attenuate-only: positive targetOffset does not exceed 1.0',
      () {
        const meta = AudioVolumeMetadata(
          targetOffset: 3.0,
          targetTp: -1.0,
          measuredTp: -4.0,
        );

        expect(coordinator.updateLoudnessMetadata(meta), isFalse);
        expect(coordinator.loudnessFactor, 1.0);
        expect(coordinator.effectiveVolume, 1.0);
      },
    );

    test('anti-clipping limits gain when true peak margin is tight', () {
      const meta = AudioVolumeMetadata(
        targetOffset: -1.0,
        targetTp: -1.0,
        measuredTp: 0.5,
      );

      coordinator.updateLoudnessMetadata(meta);
      expect(coordinator.loudnessFactor, closeTo(0.841, 0.005));
    });

    test('null metadata restores loudness factor to 1.0', () {
      const meta = AudioVolumeMetadata(targetOffset: -6.0);
      coordinator.updateLoudnessMetadata(meta);
      expect(coordinator.loudnessFactor, closeTo(0.501, 0.005));

      expect(coordinator.updateLoudnessMetadata(null), isTrue);
      expect(coordinator.loudnessFactor, 1.0);
    });

    test(
      'disabling loudness balance bypasses loudness factor in effectiveVolume',
      () {
        const meta = AudioVolumeMetadata(targetOffset: -6.0);
        coordinator.updateLoudnessMetadata(meta);
        expect(coordinator.effectiveVolume, closeTo(0.501, 0.005));

        coordinator.setEnableLoudnessBalance(false);
        expect(coordinator.effectiveVolume, 1.0);

        coordinator.setEnableLoudnessBalance(true);
        expect(coordinator.effectiveVolume, closeTo(0.501, 0.005));
      },
    );

    test('ducking operates idempotently and preserves master volume', () {
      coordinator.setUserVolume(0.8);
      expect(coordinator.setDucking(true), isTrue);
      expect(coordinator.duckFactor, 0.3);
      expect(coordinator.effectiveVolume, closeTo(0.24, 0.001));

      // Repeated ducking does not multiply further
      expect(coordinator.setDucking(true), isFalse);
      expect(coordinator.effectiveVolume, closeTo(0.24, 0.001));

      // User adjusts volume during ducking
      coordinator.setUserVolume(0.5);
      expect(coordinator.effectiveVolume, closeTo(0.15, 0.001));

      // Unduck restores clean volume
      expect(coordinator.setDucking(false), isTrue);
      expect(coordinator.duckFactor, 1.0);
      expect(coordinator.effectiveVolume, 0.5);
    });

    test(
      'resetForNewPlayback resets ducking and loudness, protects extreme low volume',
      () {
        coordinator.setUserVolume(0.01);
        coordinator.setDucking(true);
        const meta = AudioVolumeMetadata(targetOffset: -3.0);
        coordinator.updateLoudnessMetadata(meta);

        coordinator.resetForNewPlayback();
        expect(coordinator.duckFactor, 1.0);
        expect(coordinator.loudnessFactor, 1.0);
        // Below 0.05 safety reset to 1.0
        expect(coordinator.masterVolume, 1.0);
      },
    );
  });
}

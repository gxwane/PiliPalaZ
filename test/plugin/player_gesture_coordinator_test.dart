import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/player_gesture_coordinator.dart';

void main() {
  group('PlayerGestureCoordinator.isInsideDeadzone', () {
    const size = Size(800.0, 400.0);

    test('identifies top deadzone when y < topDeadzone (28dp)', () {
      expect(
        PlayerGestureCoordinator.isInsideDeadzone(
          const Offset(200.0, 10.0),
          size,
        ),
        isTrue,
      );
      expect(
        PlayerGestureCoordinator.isInsideDeadzone(
          const Offset(200.0, 27.9),
          size,
        ),
        isTrue,
      );
    });

    test(
      'identifies bottom deadzone when y > height - bottomDeadzone (24dp)',
      () {
        expect(
          PlayerGestureCoordinator.isInsideDeadzone(
            const Offset(200.0, 390.0),
            size,
          ),
          isTrue,
        );
        expect(
          PlayerGestureCoordinator.isInsideDeadzone(
            const Offset(200.0, 376.1),
            size,
          ),
          isTrue,
        );
      },
    );

    test(
      'permits interactions inside safe vertical zone in non-fullscreen',
      () {
        expect(
          PlayerGestureCoordinator.isInsideDeadzone(
            const Offset(5.0, 200.0),
            size,
            isFullScreen: false,
          ),
          isFalse,
        );
        expect(
          PlayerGestureCoordinator.isInsideDeadzone(
            const Offset(795.0, 200.0),
            size,
            isFullScreen: false,
          ),
          isFalse,
        );
      },
    );

    test('identifies side deadzone (16dp) in fullscreen mode', () {
      expect(
        PlayerGestureCoordinator.isInsideDeadzone(
          const Offset(10.0, 200.0),
          size,
          isFullScreen: true,
        ),
        isTrue,
      );
      expect(
        PlayerGestureCoordinator.isInsideDeadzone(
          const Offset(790.0, 200.0),
          size,
          isFullScreen: true,
        ),
        isTrue,
      );
      // Safe center in fullscreen
      expect(
        PlayerGestureCoordinator.isInsideDeadzone(
          const Offset(400.0, 200.0),
          size,
          isFullScreen: true,
        ),
        isFalse,
      );
    });

    test('bypasses all deadzones when enableDeadzone is false', () {
      expect(
        PlayerGestureCoordinator.isInsideDeadzone(
          const Offset(10.0, 5.0),
          size,
          isFullScreen: true,
          enableDeadzone: false,
        ),
        isFalse,
      );
    });
  });

  group('PlayerGestureCoordinator.calculateTravel', () {
    test('clamps travel on very large tablet screens (e.g. 1600px)', () {
      final travel = PlayerGestureCoordinator.calculateTravel(1600.0);
      expect(travel, equals(540.0));
    });

    test('clamps travel on very small compact screens (e.g. 200px)', () {
      final travel = PlayerGestureCoordinator.calculateTravel(200.0);
      expect(travel, equals(280.0));
    });

    test('uses linear travel in standard range (e.g. 400px)', () {
      final travel = PlayerGestureCoordinator.calculateTravel(400.0);
      expect(travel, equals(400.0));
    });

    test('scales inversely with sensitivity factor', () {
      // 1.5x sensitivity reduces travel distance by 1.5
      final fastTravel = PlayerGestureCoordinator.calculateTravel(
        450.0,
        sensitivity: 1.5,
      );
      expect(fastTravel, closeTo(300.0, 0.001));

      // 0.75x sensitivity increases travel distance
      final slowTravel = PlayerGestureCoordinator.calculateTravel(
        450.0,
        sensitivity: 0.75,
      );
      expect(slowTravel, closeTo(600.0, 0.001));
    });
  });

  group('PlayerGestureCoordinator.computeUpdatedVolume (Virtual Anchor)', () {
    test('computes smooth proportional volume within bounds', () {
      double startY = 300.0;
      final double volume = PlayerGestureCoordinator.computeUpdatedVolume(
        currentY: 200.0, // Swiped up 100px
        startY: startY,
        startVolume: 0.5,
        travel: 400.0,
        onUpdateAnchorY: (newY) => startY = newY,
      );

      // deltaY = -100, deltaVol = -(-100)/400 = +0.25 -> 0.75
      expect(volume, closeTo(0.75, 0.001));
      expect(startY, equals(300.0)); // No anchor push
    });

    test('pushes virtual anchor upon ceiling overscroll (> 1.0)', () {
      double startY = 300.0;
      final double volume = PlayerGestureCoordinator.computeUpdatedVolume(
        currentY:
            0.0, // Swiped up 300px with travel 400 and start 0.5 -> raw = 1.25
        startY: startY,
        startVolume: 0.5,
        travel: 400.0,
        onUpdateAnchorY: (newY) => startY = newY,
      );

      expect(volume, equals(1.0));
      // Anchor pushed so that at currentY (0.0), volume is exactly 1.0:
      // newStartY = 0.0 + (1.0 - 0.5) * 400 = 200.0
      expect(startY, equals(200.0));

      // Immediate 1px reversal downwards from 0.0 to 1.0:
      final double reverseVol = PlayerGestureCoordinator.computeUpdatedVolume(
        currentY: 1.0,
        startY: startY,
        startVolume: 0.5,
        travel: 400.0,
        onUpdateAnchorY: (newY) => startY = newY,
      );
      // deltaY = 1.0 - 200.0 = -199.0
      // 0.5 - (-199.0 / 400.0) = 0.5 + 0.4975 = 0.9975 (< 1.0 immediately)
      expect(reverseVol, lessThan(1.0));
      expect(reverseVol, closeTo(0.9975, 0.001));
    });

    test('pushes virtual anchor upon floor overscroll (< 0.0)', () {
      double startY = 100.0;
      final double volume = PlayerGestureCoordinator.computeUpdatedVolume(
        currentY:
            400.0, // Swiped down 300px with travel 400 and start 0.2 -> raw = -0.55
        startY: startY,
        startVolume: 0.2,
        travel: 400.0,
        onUpdateAnchorY: (newY) => startY = newY,
      );

      expect(volume, equals(0.0));
      // Anchor pushed: newStartY = 400.0 - 0.2 * 400 = 320.0
      expect(startY, equals(320.0));

      // Immediate 1px reversal upwards from 400.0 to 399.0:
      final double reverseVol = PlayerGestureCoordinator.computeUpdatedVolume(
        currentY: 399.0,
        startY: startY,
        startVolume: 0.2,
        travel: 400.0,
        onUpdateAnchorY: (newY) => startY = newY,
      );
      expect(reverseVol, greaterThan(0.0));
      expect(reverseVol, closeTo(0.0025, 0.001));
    });
  });
}

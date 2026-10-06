import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of a chapter snap computation
@immutable
class SnapResult {
  /// The effective coordinate to position the thumb at (snapped or raw)
  final double effectiveX;

  /// Whether the thumb is currently magnetically snapped to a chapter boundary
  final bool isSnapped;

  /// The chapter split duration if currently snapped, null otherwise
  final Duration? snappedPoint;

  /// The index of the snapped chapter if currently snapped
  final int? snappedChapterIndex;

  const SnapResult({
    required this.effectiveX,
    required this.isSnapped,
    this.snappedPoint,
    this.snappedChapterIndex,
  });
}

/// Pure coordinator handling magnetic snap-to-chapter physics,
/// Schmitt trigger hysteresis, elastic tension, and haptic feedback.
class ChapterSnapCoordinator {
  ChapterSnapCoordinator({
    this.onHapticFeedback,
    this.velocityBypassThreshold = 800.0,
    this.minHapticIntervalMs = 120,
  });

  /// Optional callback invoked when magnetic snap occurs.
  /// Defaults to [HapticFeedback.selectionClick].
  final VoidCallback? onHapticFeedback;

  /// Instantaneous finger velocity threshold (in dp/s) above which snapping is bypassed
  final double velocityBypassThreshold;

  /// Minimum milliseconds between haptic feedback pulses to avoid buzzing/chatter
  final int minHapticIntervalMs;

  bool _isCurrentlySnapped = false;
  Duration? _snappedChapterPoint;
  int? _snappedChapterIndex;
  DateTime? _lastHapticTime;

  /// Whether the thumb is currently magnetically locked to a chapter point
  bool get isCurrentlySnapped => _isCurrentlySnapped;

  /// The currently snapped chapter duration, if any
  Duration? get snappedChapterPoint => _snappedChapterPoint;

  /// The currently snapped chapter index, if any
  int? get snappedChapterIndex => _snappedChapterIndex;

  /// Computes adaptive magnetic snap radius based on physical bar width
  static double resolveSnapRadius(double barWidth) {
    if (barWidth <= 0.0) return 10.0;
    // 1.5% of bar width, clamped between 10.0 dp and 15.0 dp
    return (barWidth * 0.015).clamp(10.0, 15.0);
  }

  /// Resets internal snap state (e.g. when drag finishes or bar is resized)
  void reset() {
    _isCurrentlySnapped = false;
    _snappedChapterPoint = null;
    _snappedChapterIndex = null;
  }

  /// Computes magnetic snap for a given raw touch position [rawX]
  SnapResult computeSnap({
    required double rawX,
    required double barStart,
    required double barWidth,
    required Duration total,
    required List<Duration> chapterPoints,
    double? velocityPxPerSec,
  }) {
    if (total <= Duration.zero || chapterPoints.isEmpty || barWidth <= 0.0) {
      reset();
      return SnapResult(effectiveX: rawX, isSnapped: false);
    }

    // Velocity bypass: high-speed sweeps ignore snapping for effortless gross seeking
    if (velocityPxPerSec != null &&
        velocityPxPerSec.abs() > velocityBypassThreshold) {
      reset();
      return SnapResult(effectiveX: rawX, isSnapped: false);
    }

    final double snapRadius = resolveSnapRadius(barWidth);
    final double escapeRadius = snapRadius * 1.5;

    // 1. If already locked in snap, check Schmitt trigger breakaway hysteresis
    if (_isCurrentlySnapped && _snappedChapterPoint != null) {
      final double chapterProgress =
          _snappedChapterPoint!.inMilliseconds / total.inMilliseconds;
      final double chapterX = barStart + chapterProgress * barWidth;
      final double deltaX = rawX - chapterX;
      final double absDeltaX = deltaX.abs();

      if (absDeltaX <= snapRadius) {
        // Firmly locked to chapter center
        return SnapResult(
          effectiveX: chapterX,
          isSnapped: true,
          snappedPoint: _snappedChapterPoint,
          snappedChapterIndex: _snappedChapterIndex,
        );
      } else if (absDeltaX <= escapeRadius) {
        // Between snap radius and escape radius: apply elastic tension (feels like pulling away from a magnet)
        final double pullDistance = absDeltaX - snapRadius;
        final double tension = deltaX.sign * min(pullDistance * 0.2, 2.0);
        return SnapResult(
          effectiveX: chapterX + tension,
          isSnapped: true,
          snappedPoint: _snappedChapterPoint,
          snappedChapterIndex: _snappedChapterIndex,
        );
      } else {
        // Escaped magnetic trap! Smoothly break free
        reset();
      }
    }

    // 2. Not currently snapped: search for nearest chapter split point
    double closestDistance = double.infinity;
    Duration? candidatePoint;
    int? candidateIndex;
    double candidateX = 0.0;

    for (int i = 0; i < chapterPoints.length; i++) {
      final point = chapterPoints[i];
      if (point <= Duration.zero || point >= total) continue;

      final double ptProgress = point.inMilliseconds / total.inMilliseconds;
      final double ptX = barStart + ptProgress * barWidth;
      final double dist = (rawX - ptX).abs();

      if (dist < closestDistance) {
        closestDistance = dist;
        candidatePoint = point;
        candidateIndex = i;
        candidateX = ptX;
      }
    }

    // 3. If nearest chapter is within magnetic capture radius, snap!
    if (closestDistance <= snapRadius && candidatePoint != null) {
      _isCurrentlySnapped = true;
      _snappedChapterPoint = candidatePoint;
      _snappedChapterIndex = candidateIndex;
      _triggerHaptic();

      return SnapResult(
        effectiveX: candidateX,
        isSnapped: true,
        snappedPoint: candidatePoint,
        snappedChapterIndex: candidateIndex,
      );
    }

    // Free dragging outside snap zones
    reset();
    return SnapResult(effectiveX: rawX, isSnapped: false);
  }

  void _triggerHaptic() {
    final now = DateTime.now();
    if (_lastHapticTime != null &&
        now.difference(_lastHapticTime!).inMilliseconds < minHapticIntervalMs) {
      return;
    }
    _lastHapticTime = now;
    if (onHapticFeedback != null) {
      onHapticFeedback!();
    } else {
      HapticFeedback.selectionClick();
    }
  }
}

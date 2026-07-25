enum PlaybackPositionAction { accept, ignore, correct }

class PlaybackPositionDecision {
  const PlaybackPositionDecision._(
    this.action, {
    this.correctionTarget,
    this.regression,
  });

  const PlaybackPositionDecision.accept()
    : this._(PlaybackPositionAction.accept);

  const PlaybackPositionDecision.ignore()
    : this._(PlaybackPositionAction.ignore);

  const PlaybackPositionDecision.correct({
    required Duration correctionTarget,
    required Duration regression,
  }) : this._(
         PlaybackPositionAction.correct,
         correctionTarget: correctionTarget,
         regression: regression,
       );

  final PlaybackPositionAction action;
  final Duration? correctionTarget;
  final Duration? regression;
}

class PlaybackPositionGuard {
  PlaybackPositionGuard({
    this.regressionThreshold = const Duration(seconds: 2),
    this.transitionTolerance = const Duration(seconds: 2),
    this.transitionTimeout = const Duration(seconds: 5),
    this.correctionCooldown = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration regressionThreshold;
  final Duration transitionTolerance;
  final Duration transitionTimeout;
  final Duration correctionCooldown;
  final DateTime Function() _clock;

  Duration? _lastStablePosition;
  Duration? _expectedPosition;
  DateTime? _expectedUntil;
  DateTime? _lastCorrectionAt;

  Duration? get lastStablePosition => _lastStablePosition;

  void reset({Duration initialPosition = Duration.zero}) {
    _lastStablePosition = initialPosition;
    _expectedPosition = null;
    _expectedUntil = null;
    _lastCorrectionAt = null;
  }

  void expectPosition(Duration position) {
    final Duration target = position < Duration.zero ? Duration.zero : position;
    _expectedPosition = target;
    _expectedUntil = _clock().add(transitionTimeout);
    _lastStablePosition = target;
  }

  PlaybackPositionDecision evaluate(
    Duration position, {
    required bool isPlaying,
    required bool isBuffering,
    bool isLive = false,
  }) {
    if (isLive) {
      _accept(position);
      return const PlaybackPositionDecision.accept();
    }

    final DateTime now = _clock();
    final Duration? expected = _expectedPosition;
    if (expected != null) {
      final bool timedOut =
          _expectedUntil == null || !now.isBefore(_expectedUntil!);
      final Duration distance = (position - expected).abs();
      if (!timedOut && distance > transitionTolerance) {
        return const PlaybackPositionDecision.ignore();
      }
      _expectedPosition = null;
      _expectedUntil = null;
      _accept(position);
      return const PlaybackPositionDecision.accept();
    }

    final Duration? previous = _lastStablePosition;
    if (previous == null) {
      _accept(position);
      return const PlaybackPositionDecision.accept();
    }

    final Duration regression = previous - position;
    if (regression <= regressionThreshold) {
      _accept(position);
      return const PlaybackPositionDecision.accept();
    }

    if (!isPlaying || isBuffering) {
      return const PlaybackPositionDecision.ignore();
    }

    final DateTime? lastCorrectionAt = _lastCorrectionAt;
    if (lastCorrectionAt != null &&
        now.difference(lastCorrectionAt) < correctionCooldown) {
      return const PlaybackPositionDecision.ignore();
    }

    _lastCorrectionAt = now;
    return PlaybackPositionDecision.correct(
      correctionTarget: previous,
      regression: regression,
    );
  }

  void _accept(Duration position) {
    _lastStablePosition = position < Duration.zero ? Duration.zero : position;
  }
}

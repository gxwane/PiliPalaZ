import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

/// 播放器长按动态高倍速指示器
///
/// 具备毛玻璃胶囊药丸、双箭头流光推进微动效与平滑缩放/淡入淡出。
/// 内部通过 [RepaintBoundary] 进行图层隔离，非激活状态下停止 Ticker 并在完全退场后收敛为 [SizedBox.shrink]。
class FastForwardIndicator extends StatefulWidget {
  const FastForwardIndicator({super.key, required this.speed});

  /// 当前动态倍速值。0.0 或负数表示非激活状态。
  final double speed;

  @override
  State<FastForwardIndicator> createState() => _FastForwardIndicatorState();
}

class _FastForwardIndicatorState extends State<FastForwardIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _visibilityController;
  late final AnimationController _chevronController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  double _displayedSpeed = 2.0;

  @override
  void initState() {
    super.initState();
    _visibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _visibilityController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _visibilityController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    if (widget.speed > 0) {
      _displayedSpeed = widget.speed;
      _visibilityController.forward();
      _chevronController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FastForwardIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speed > 0) {
      _displayedSpeed = widget.speed;
      if (!_visibilityController.isAnimating &&
          _visibilityController.value < 1.0) {
        _visibilityController.forward();
      }
      if (!_chevronController.isAnimating) {
        _chevronController.repeat();
      }
    } else if (oldWidget.speed > 0 && widget.speed <= 0) {
      _visibilityController.reverse().then((_) {
        if (mounted && widget.speed <= 0) {
          _chevronController.stop();
        }
      });
    }
  }

  @override
  void dispose() {
    _visibilityController.dispose();
    _chevronController.dispose();
    super.dispose();
  }

  String get _formattedSpeed {
    if (_displayedSpeed.truncateToDouble() == _displayedSpeed) {
      return '${_displayedSpeed.toStringAsFixed(1)}X';
    }
    return '${_displayedSpeed.toStringAsFixed(2)}X';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight.isFinite && constraints.maxHeight < 160) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          ignoring: true,
          child: AnimatedBuilder(
            animation: _visibilityController,
            builder: (context, _) {
              if (_visibilityController.value == 0.0 && widget.speed <= 0) {
                return const SizedBox.shrink();
              }

              return RepaintBoundary(
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildAnimatedChevrons(),
                              const SizedBox(width: 5),
                              Text(
                                _formattedSpeed,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAnimatedChevrons() {
    return AnimatedBuilder(
      animation: _chevronController,
      builder: (context, _) {
        final double t = _chevronController.value;
        final double op1 = (sin(t * 2 * pi) * 0.35 + 0.65)
            .clamp(0.3, 1.0)
            .toDouble();
        final double op2 = (sin((t - 0.25) * 2 * pi) * 0.35 + 0.65)
            .clamp(0.3, 1.0)
            .toDouble();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: op1,
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
            Opacity(
              opacity: op2,
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}

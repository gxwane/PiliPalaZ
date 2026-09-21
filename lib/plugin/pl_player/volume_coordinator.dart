import 'dart:math' as math;

import 'package:pilipalaz/models/video/play/url.dart';

/// 负责过滤系统广播回执（Echo）与物理按键/外部音量变更判定的状态机
class MasterVolumeEchoGuard {
  int? _expectedHardwareStep;
  int _lastProgrammaticTimestamp = 0;

  int? get expectedHardwareStep => _expectedHardwareStep;

  /// 由 App 手势或程序主动向系统分发硬件音量时调用
  void registerExpectedStep(int targetStep) {
    _expectedHardwareStep = targetStep.clamp(0, 15);
    _lastProgrammaticTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  /// 接收到系统音量广播 (0.0 ~ 1.0) 时判定是否为自身操作的回执（Echo）
  bool isEchoEvent(double rawSystemVolume) {
    final int incomingStep = (rawSystemVolume * 15.0).round();
    final int now = DateTime.now().millisecondsSinceEpoch;

    // 1. 若收到的步进与预期提交步进一致，且在合理时效（1500ms）内
    if (_expectedHardwareStep != null &&
        incomingStep == _expectedHardwareStep &&
        now - _lastProgrammaticTimestamp < 1500) {
      _expectedHardwareStep = null;
      return true;
    }

    // 2. 在程序主动调节后的超短抑制窗口（150ms）内如果收到中间步进或抖动，判定为 Echo 丢弃
    if (now - _lastProgrammaticTimestamp < 150) {
      return true;
    }

    // 3. 确实是外部物理实体按键、控制中心或蓝牙耳机操作
    _expectedHardwareStep = null;
    return false;
  }

  void reset() {
    _expectedHardwareStep = null;
    _lastProgrammaticTimestamp = 0;
  }
}

/// 单轨融合主音量与响度协调器
class PlaybackVolumeCoordinator {
  PlaybackVolumeCoordinator({MasterVolumeEchoGuard? echoGuard})
    : _echoGuard = echoGuard ?? MasterVolumeEchoGuard();

  final MasterVolumeEchoGuard _echoGuard;
  MasterVolumeEchoGuard get echoGuard => _echoGuard;

  /// 用户前台看到的唯一主音量 (0.0 ~ 1.0)
  double _masterVolume = 1.0;

  /// 当前系统硬件阶梯 (0 ~ 15)
  int _hardwareStep = 15;

  /// 响度均衡衰减系数 (0.0 ~ 1.0)
  double _loudnessFactor = 1.0;

  /// 临时闪避衰减系数 (1.0 或 0.3)
  double _duckFactor = 1.0;

  /// 响度均衡开关
  bool _enableLoudnessBalance = true;

  double get masterVolume => _masterVolume;
  double get userVolume => _masterVolume;
  int get hardwareStep => _hardwareStep;
  double get loudnessFactor => _loudnessFactor;
  double get duckFactor => _duckFactor;
  bool get enableLoudnessBalance => _enableLoudnessBalance;

  /// 计算底层播放引擎所需要的微步增益 (EngineMicroGain)
  /// 使得: (HardwareStep / 15.0) * engineMicroGain == _masterVolume
  double get engineMicroGain {
    if (_masterVolume <= 0.0001 || _hardwareStep <= 0) {
      return 0.0;
    }
    final double hardwareBase = _hardwareStep / 15.0;
    return (_masterVolume / hardwareBase).clamp(0.0, 1.0);
  }

  /// 最终下发给播放引擎 (IPlayerEngine) 的合成标量音量
  double get effectiveVolume {
    final double loudness = _enableLoudnessBalance ? _loudnessFactor : 1.0;
    return (engineMicroGain * loudness * _duckFactor).clamp(0.0, 1.0);
  }

  /// 计算给定主音量所必需的硬件最低骨架阶梯
  /// 0% -> 0
  /// 0% < vol <= 6.67% -> 1 (深夜微音量固定在 1 档，完全由软件 PCM 标量微调，无跨阶硬件爆音)
  /// > 6.67% -> ceil(vol * 15)
  static int calculateRequiredStep(double targetVolume) {
    if (targetVolume <= 0.0001) {
      return 0;
    }
    if (targetVolume <= 1.0 / 15.0) {
      return 1;
    }
    return (targetVolume * 15.0).ceil().clamp(1, 15);
  }

  /// 初始化对齐系统当前音量
  void initFromSystem(int step, double rawVolume) {
    _hardwareStep = step.clamp(0, 15);
    _masterVolume = rawVolume.clamp(0.0, 1.0);
  }

  /// 设置主音量（手势滑动调节）
  /// 返回是否有实际数值变化
  bool setMasterVolume(double target) {
    final double clamped = target.clamp(0.0, 1.0);
    if ((_masterVolume - clamped).abs() < 0.0005) {
      return false;
    }
    _masterVolume = clamped;
    return true;
  }

  /// 兼容旧方法名
  bool setUserVolume(double val) => setMasterVolume(val);

  /// 物理按键/外部系统音量同步（非 Echo 事件触发）
  /// 主音量直接与系统硬件阶梯对齐，微步增益归一为 1.0
  /// 若阶梯未发生真实改变，认定为系统冗余广播，返回 false；
  /// 若阶梯发生实际改变，返回 true。
  bool syncFromHardwareKey(int step) {
    final int clamped = step.clamp(0, 15);
    if (_hardwareStep == clamped) {
      return false;
    }
    _hardwareStep = clamped;
    _masterVolume = _hardwareStep / 15.0;
    return true;
  }

  /// 内部确认硬件阶梯已被系统接受（Echo 或主动提升）
  void updateHardwareStep(int step) {
    _hardwareStep = step.clamp(0, 15);
  }

  /// 检查向上滑动时是否需要提升硬件阶梯
  /// 若需要提升，返回目标新阶梯 (> 当前阶梯)；否则返回 null
  int? checkHardwareStepUpNeeded() {
    final int neededStep = calculateRequiredStep(_masterVolume);
    if (neededStep > _hardwareStep) {
      return neededStep;
    }
    return null;
  }

  /// 检查抬手静止时是否可以向下收敛（Compaction）
  /// 若当前硬件档位高于所需骨架档位，返回最优档位；否则返回 null
  int? checkHardwareStepCompactionNeeded() {
    final int optimalStep = calculateRequiredStep(_masterVolume);
    if (optimalStep < _hardwareStep) {
      return optimalStep;
    }
    return null;
  }

  bool updateLoudnessMetadata(AudioVolumeMetadata? meta) {
    if (meta == null || meta.targetOffset == null) {
      if ((_loudnessFactor - 1.0).abs() < 0.001) {
        return false;
      }
      _loudnessFactor = 1.0;
      return true;
    }

    final double offset = meta.targetOffset!;
    final double rawGain = math.pow(10.0, offset / 20.0).toDouble();

    // 防削波保护（Anti-clipping guard）
    double maxSafeGain = 1.0;
    if (meta.targetTp != null && meta.measuredTp != null) {
      maxSafeGain = math
          .pow(10.0, (meta.targetTp! - meta.measuredTp!) / 20.0)
          .toDouble();
    }

    final double safeGain = math.min(rawGain, maxSafeGain);
    // 衰减优先（Attenuate-only），超出 1.0 不放大，规避 ExoPlayer 上限截断死区
    final double nextLoudness = math.min(1.0, math.max(0.0, safeGain));

    if ((_loudnessFactor - nextLoudness).abs() < 0.001) {
      return false;
    }
    _loudnessFactor = nextLoudness;
    return true;
  }

  bool setDucking(bool isDucking) {
    final double targetDuck = isDucking ? 0.3 : 1.0;
    if ((_duckFactor - targetDuck).abs() < 0.001) {
      return false;
    }
    _duckFactor = targetDuck;
    return true;
  }

  bool setEnableLoudnessBalance(bool enable) {
    if (_enableLoudnessBalance == enable) {
      return false;
    }
    _enableLoudnessBalance = enable;
    return true;
  }

  void resetForNewPlayback({bool resetMasterVolume = false}) {
    _duckFactor = 1.0;
    _loudnessFactor = 1.0;
    if (resetMasterVolume || _masterVolume < 0.05) {
      _masterVolume = 1.0;
      _hardwareStep = 15;
    }
  }
}

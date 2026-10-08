/// 全局下载服务，统管并发队列与任务生命周期。
///
/// 单例模式，提供启动/暂停/恢复/取消/删除接口，
/// 并通过 [taskUpdates] 流广播任务状态变更。
library;

import 'dart:async';

import 'package:pilipalaz/http/video_api.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/services/download/download_dao.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';
import 'package:pilipalaz/services/download/download_task_executor.dart';
import 'package:pilipalaz/utils/video_utils.dart';

/// 解析视频/音频下载地址函数类型，便于依赖注入与测试。
typedef DownloadUrlResolver =
    Future<ResolvedDownloadUrls?> Function(DownloadTask task);

/// 下载执行器构建工厂函数类型，便于依赖注入与测试。
typedef DownloadExecutorFactory =
    DownloadTaskExecutor Function({
      required DownloadTask task,
      required DownloadStorageManager storageManager,
      required String videoUrl,
      required String audioUrl,
      void Function(int downloaded, int total, int speed)? onProgress,
    });

/// 解析完成的音视频下载直链地址。
class ResolvedDownloadUrls {
  const ResolvedDownloadUrls({required this.videoUrl, required this.audioUrl});
  final String videoUrl;
  final String audioUrl;
}

/// 默认最大并发下载数。
const int kDefaultMaxConcurrent = 2;

/// 全局下载服务单例。
class DownloadService {
  DownloadService._({
    required DownloadDao dao,
    required DownloadStorageManager storageManager,
    int maxConcurrent = kDefaultMaxConcurrent,
    DownloadUrlResolver? urlResolver,
    DownloadExecutorFactory? executorFactory,
  }) : _dao = dao,
       _storageManager = storageManager,
       _maxConcurrent = maxConcurrent.clamp(1, 4),
       _urlResolver = urlResolver,
       _executorFactory = executorFactory;

  static DownloadService? _instance;

  /// 检查是否已初始化。
  static bool get isInitialized => _instance != null;

  /// 获取已初始化的单例。
  static DownloadService get instance {
    assert(_instance != null, 'DownloadService.init() must be called first');
    return _instance!;
  }

  final DownloadDao _dao;
  final DownloadStorageManager _storageManager;
  int _maxConcurrent;
  final DownloadUrlResolver? _urlResolver;
  final DownloadExecutorFactory? _executorFactory;

  /// 活跃执行器映射。
  final Map<String, DownloadTaskExecutor> _executors =
      <String, DownloadTaskExecutor>{};

  /// 正在启动（解析 URL / 初始化）的任务 ID 集合，用于排队并发槽位即时锁定。
  final Set<String> _startingTaskIds = <String>{};

  /// 任务状态变更广播流。
  final StreamController<DownloadTask> _taskUpdatesController =
      StreamController<DownloadTask>.broadcast();

  /// 订阅此流以接收任务状态/进度更新。
  Stream<DownloadTask> get taskUpdates => _taskUpdatesController.stream;

  /// 初始化下载服务。
  ///
  /// 冷启动自愈：将所有残留 `downloading` 状态的僵尸任务重置为 `paused`。
  static Future<DownloadService> init({
    required DownloadDao dao,
    required DownloadStorageManager storageManager,
    int maxConcurrent = kDefaultMaxConcurrent,
    DownloadUrlResolver? urlResolver,
    DownloadExecutorFactory? executorFactory,
  }) async {
    final DownloadService service = DownloadService._(
      dao: dao,
      storageManager: storageManager,
      maxConcurrent: maxConcurrent,
      urlResolver: urlResolver,
      executorFactory: executorFactory,
    );
    await service._healZombieTasks();
    _instance = service;
    return service;
  }

  /// 冷启动僵尸状态自愈。
  Future<void> _healZombieTasks() async {
    final List<DownloadTask> zombies = _dao
        .getAllTasks()
        .where((DownloadTask t) => t.status == DownloadTaskStatus.downloading)
        .toList();

    if (zombies.isEmpty) return;

    final List<DownloadTask> healed = <DownloadTask>[];
    for (final DownloadTask zombie in zombies) {
      healed.add(zombie.copyWith(status: DownloadTaskStatus.paused));
    }
    await _dao.saveTasks(healed);
  }

  // ── 公开接口 ──

  /// 批量创建并启动新下载任务（原子入库与统一调度）。
  Future<List<DownloadTask>> startTasks(List<DownloadTask> tasks) async {
    if (tasks.isEmpty) return <DownloadTask>[];

    // 前置服务层磁盘水位安全红线强检
    if (await _storageManager.isBelowSafetyThreshold()) {
      final List<DownloadTask> failedTasks = <DownloadTask>[];
      for (final DownloadTask task in tasks) {
        task
          ..status = DownloadTaskStatus.failed
          ..errorMessage = '存储空间不足 (低于安全水位 200MB)';
        failedTasks.add(task);
      }
      await _dao.saveTasks(failedTasks);
      for (final DownloadTask task in failedTasks) {
        _emit(task);
      }
      return failedTasks;
    }

    final List<DownloadTask> toSave = <DownloadTask>[];

    for (final DownloadTask task in tasks) {
      final DownloadTask? existing = _dao.getTask(task.id);
      if (existing != null) {
        if (existing.isResumable) {
          existing
            ..status = DownloadTaskStatus.pending
            ..errorMessage = null
            ..resetRetry();
          toSave.add(existing);
        }
      } else {
        final DownloadPaths paths = _storageManager.pathsForTask(task);
        task
          ..videoRelativePath = paths.videoRelativePath
          ..audioRelativePath = paths.audioRelativePath
          ..danmakuRelativePath = paths.danmakuRelativePath
          ..coverRelativePath = paths.coverRelativePath
          ..subtitlesRelativePath = paths.subtitlesRelativePath
          ..chaptersRelativePath = paths.chaptersRelativePath
          ..status = DownloadTaskStatus.pending
          ..errorMessage = null
          ..resetRetry();
        toSave.add(task);
      }
    }

    if (toSave.isNotEmpty) {
      await _dao.saveTasks(toSave);
      for (final DownloadTask task in toSave) {
        _emit(task);
      }
      _scheduleNext();
    }

    return toSave;
  }

  /// 创建并启动新下载任务。
  Future<DownloadTask?> startTask(DownloadTask task) async {
    final List<DownloadTask> result = await startTasks(<DownloadTask>[task]);
    return result.isNotEmpty ? result.first : _dao.getTask(task.id);
  }

  /// 暂停指定任务。
  Future<void> pauseTask(String id) async {
    _startingTaskIds.remove(id);
    final DownloadTaskExecutor? executor = _executors.remove(id);
    executor?.cancel();

    final DownloadTask? task = _dao.getTask(id);
    if (task == null) return;

    if (task.status == DownloadTaskStatus.downloading ||
        task.status == DownloadTaskStatus.pending) {
      task.status = DownloadTaskStatus.paused;
      await _dao.saveTask(task);
      _emit(task);
    }
  }

  /// 恢复指定任务。
  Future<void> resumeTask(String id) async {
    final DownloadTask? task = _dao.getTask(id);
    if (task == null || !task.isResumable) return;

    if (await _storageManager.isBelowSafetyThreshold()) {
      task
        ..status = DownloadTaskStatus.failed
        ..errorMessage = '存储空间不足 (低于安全水位 200MB)';
      await _dao.saveTask(task);
      _emit(task);
      return;
    }

    task
      ..status = DownloadTaskStatus.pending
      ..errorMessage = null
      ..resetRetry();
    await _dao.saveTask(task);
    _emit(task);

    _scheduleNext();
  }

  /// 取消并删除任务。
  Future<void> cancelTask(String id, {bool deleteFiles = true}) async {
    _startingTaskIds.remove(id);
    // 停止执行
    final DownloadTaskExecutor? executor = _executors.remove(id);
    executor?.cancel();
    executor?.dispose();

    final DownloadTask? task = _dao.getTask(id);
    if (task == null) return;

    // 删除本地文件
    if (deleteFiles) {
      await _storageManager.deleteTaskFiles(task);
    }

    // 删除元数据
    await _dao.deleteTask(id);

    _scheduleNext();
  }

  /// 暂停所有正在下载或等待中的任务。
  Future<void> pauseAll() async {
    _startingTaskIds.clear();
    // 停止所有活跃执行器
    final List<String> executorIds = _executors.keys.toList();
    for (final String id in executorIds) {
      final DownloadTaskExecutor? executor = _executors.remove(id);
      executor?.cancel();
    }

    // 将 DAO 中所有 downloading/pending 状态的任务重置为 paused
    final List<DownloadTask> active = _dao
        .getAllTasks()
        .where(
          (DownloadTask t) =>
              t.status == DownloadTaskStatus.downloading ||
              t.status == DownloadTaskStatus.pending,
        )
        .toList();
    for (final DownloadTask task in active) {
      task.status = DownloadTaskStatus.paused;
      await _dao.saveTask(task);
      _emit(task);
    }
  }

  /// 恢复所有可恢复的任务。
  Future<void> resumeAll() async {
    if (await _storageManager.isBelowSafetyThreshold()) {
      final List<DownloadTask> resumable = _dao
          .getAllTasks()
          .where((DownloadTask t) => t.isResumable)
          .toList();
      for (final DownloadTask task in resumable) {
        task
          ..status = DownloadTaskStatus.failed
          ..errorMessage = '存储空间不足 (低于安全水位 200MB)';
      }
      await _dao.saveTasks(resumable);
      for (final DownloadTask task in resumable) {
        _emit(task);
      }
      return;
    }

    final List<DownloadTask> resumable = _dao
        .getAllTasks()
        .where((DownloadTask t) => t.isResumable)
        .toList();
    for (final DownloadTask task in resumable) {
      task
        ..status = DownloadTaskStatus.pending
        ..errorMessage = null
        ..resetRetry();
    }
    await _dao.saveTasks(resumable);
    for (final DownloadTask task in resumable) {
      _emit(task);
    }
    _scheduleNext();
  }

  /// 获取所有任务。
  List<DownloadTask> getAllTasks() => _dao.getAllTasks();

  /// 获取指定任务。
  DownloadTask? getTask(String id) => _dao.getTask(id);

  /// 当前活跃下载数量（含正在启动解析与已挂载执行器）。
  int get activeCount => _executors.length + _startingTaskIds.length;

  /// 当前最大并发数。
  int get maxConcurrent => _maxConcurrent;

  /// 动态修改最大并发下载数（支持 1~4）。
  void updateMaxConcurrent(int slots) {
    final int clamped = slots.clamp(1, 4);
    if (_maxConcurrent == clamped) return;
    _maxConcurrent = clamped;
    _scheduleNext();
  }

  // ── 调度器 ──

  /// 尝试调度下一个 pending 任务。
  void _scheduleNext() {
    if (activeCount >= _maxConcurrent) return;

    final List<DownloadTask> pending =
        _dao
            .getAllTasks()
            .where((DownloadTask t) => t.status == DownloadTaskStatus.pending)
            .toList()
          ..sort((DownloadTask a, DownloadTask b) {
            final int timeDiff = a.createdAt
                .difference(b.createdAt)
                .inMilliseconds;
            // 若创建时间差在 2 秒内（同一批次任务），按分 P (cid) 正序调度保序
            if (timeDiff.abs() < 2000 && a.bvid == b.bvid) {
              return a.cid.compareTo(b.cid);
            }
            return a.createdAt.compareTo(b.createdAt);
          });

    for (final DownloadTask task in pending) {
      if (activeCount >= _maxConcurrent) break;
      if (_executors.containsKey(task.id) ||
          _startingTaskIds.contains(task.id)) {
        continue;
      }
      _startingTaskIds.add(task.id);
      _executeTask(task);
    }
  }

  /// 启动单个任务的下载执行。
  Future<void> _executeTask(DownloadTask task) async {
    try {
      // 调度前磁盘安全水位检测
      if (await _storageManager.isBelowSafetyThreshold()) {
        task
          ..status = DownloadTaskStatus.failed
          ..errorMessage = '存储空间不足 (低于安全水位 200MB)';
        await _dao.saveTask(task);
        _emit(task);
        _scheduleNext();
        return;
      }

      // 获取播放地址
      final ResolvedDownloadUrls? urls = _urlResolver != null
          ? await _urlResolver(task)
          : await _resolveUrls(task);
      if (urls == null) {
        task
          ..status = DownloadTaskStatus.failed
          ..errorMessage = '无法获取下载地址';
        await _dao.saveTask(task);
        _emit(task);
        _scheduleNext();
        return;
      }

      // 若在异步等待期间任务已被暂停或取消，则退出并尝试调度后续任务
      if (!_startingTaskIds.contains(task.id)) {
        _scheduleNext();
        return;
      }

      task.status = DownloadTaskStatus.downloading;
      await _dao.saveTask(task);
      _emit(task);

      void onProgress(int downloaded, int total, int speed) {
        task
          ..downloadedBytes = downloaded
          ..totalBytes = total
          ..downloadSpeed = speed;
        // 节流持久化：每 5% 或每 5MB 落盘一次
        final bool shouldPersist =
            total > 0 &&
            (downloaded % (total ~/ 20 + 1) < speed ||
                downloaded % (5 * 1024 * 1024) < speed);
        if (shouldPersist) {
          _dao.saveTask(task);
        }
        _emit(task);
      }

      final DownloadTaskExecutor executor = _executorFactory != null
          ? _executorFactory(
              task: task,
              storageManager: _storageManager,
              videoUrl: urls.videoUrl,
              audioUrl: urls.audioUrl,
              onProgress: onProgress,
            )
          : DownloadTaskExecutor(
              task: task,
              storageManager: _storageManager,
              videoUrl: urls.videoUrl,
              audioUrl: urls.audioUrl,
              onProgress: onProgress,
            );

      _executors[task.id] = executor;
      _startingTaskIds.remove(task.id);

      try {
        final DownloadTaskStatus result = await executor.execute();

        if (result == DownloadTaskStatus.completed) {
          task
            ..status = DownloadTaskStatus.completed
            ..downloadedBytes = task.totalBytes
            ..completedAt = DateTime.now();
        } else {
          task.status = result;
        }
      } on Object catch (e) {
        task
          ..status = DownloadTaskStatus.failed
          ..errorMessage = e.toString();
      } finally {
        _executors.remove(task.id);
        executor.dispose();
      }

      await _dao.saveTask(task);
      _emit(task);
      _scheduleNext();
    } finally {
      _startingTaskIds.remove(task.id);
    }
  }

  /// 解析视频/音频下载 URL。
  Future<ResolvedDownloadUrls?> _resolveUrls(DownloadTask task) async {
    final result = await VideoApi.instance.playUrl(
      bvid: task.bvid,
      cid: task.cid,
    );

    return result.fold(
      success: (PlayUrlModel data) {
        final dash = data.dash;
        if (dash == null) return null;

        // 匹配视频流
        final videoItem = _findVideo(dash, task);
        if (videoItem == null) return null;

        // 匹配音频流
        final audioItem = _findAudio(dash, task);
        if (audioItem == null) return null;

        // 提取并持久化响度均衡元数据
        if (data.volume != null) {
          task.volumeMetadata = data.volume!.toJson();
        }

        return ResolvedDownloadUrls(
          videoUrl: VideoUtils.getCdnUrl(videoItem),
          audioUrl: VideoUtils.getCdnUrl(audioItem),
        );
      },
      failure: (_) => null,
    );
  }

  VideoItem? _findVideo(Dash dash, DownloadTask task) {
    final videos = dash.video;
    if (videos == null) return null;
    for (final VideoItem v in videos) {
      if (v.id == task.videoQuality &&
          _codecPrefixMatch(v.codecs, task.videoCodec)) {
        return v;
      }
    }
    // 降级：仅匹配画质
    for (final VideoItem v in videos) {
      if (v.id == task.videoQuality) return v;
    }
    return null;
  }

  AudioItem? _findAudio(Dash dash, DownloadTask task) {
    final audios = dash.audio;
    if (audios == null) return null;
    for (final AudioItem a in audios) {
      if (a.id == task.audioQuality) return a;
    }
    // 降级：取第一个音频
    return audios.isNotEmpty ? audios.first : null;
  }

  bool _codecPrefixMatch(String? actual, String expected) {
    if (actual == null) return false;
    return actual.split('.').first.toLowerCase() ==
        expected.split('.').first.toLowerCase();
  }

  void _emit(DownloadTask task) {
    if (!_taskUpdatesController.isClosed) {
      _taskUpdatesController.add(task);
    }
  }

  /// 释放服务资源（仅用于测试）。
  Future<void> dispose() async {
    for (final executor in _executors.values) {
      executor.cancel();
      executor.dispose();
    }
    _executors.clear();
    _startingTaskIds.clear();
    await _taskUpdatesController.close();
    _instance = null;
  }
}

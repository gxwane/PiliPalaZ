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

/// 默认最大并发下载数。
const int kDefaultMaxConcurrent = 2;

/// 全局下载服务单例。
class DownloadService {
  DownloadService._({
    required DownloadDao dao,
    required DownloadStorageManager storageManager,
    int maxConcurrent = kDefaultMaxConcurrent,
  }) : _dao = dao,
       _storageManager = storageManager,
       _maxConcurrent = maxConcurrent;

  static DownloadService? _instance;

  /// 获取已初始化的单例。
  static DownloadService get instance {
    assert(_instance != null, 'DownloadService.init() must be called first');
    return _instance!;
  }

  final DownloadDao _dao;
  final DownloadStorageManager _storageManager;
  final int _maxConcurrent;

  /// 活跃执行器映射。
  final Map<String, DownloadTaskExecutor> _executors =
      <String, DownloadTaskExecutor>{};

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
  }) async {
    final DownloadService service = DownloadService._(
      dao: dao,
      storageManager: storageManager,
      maxConcurrent: maxConcurrent,
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

  /// 创建并启动新下载任务。
  ///
  /// 1. 前置磁盘水位检查
  /// 2. 获取播放地址
  /// 3. 分配本地路径
  /// 4. 持久化任务
  /// 5. 加入执行队列
  Future<DownloadTask?> startTask(DownloadTask task) async {
    // 若任务已存在则直接返回
    final DownloadTask? existing = _dao.getTask(task.id);
    if (existing != null) {
      if (existing.isResumable) {
        await resumeTask(existing.id);
      }
      return existing;
    }

    // 分配本地路径
    final DownloadPaths paths = _storageManager.pathsForTask(task);
    task
      ..videoRelativePath = paths.videoRelativePath
      ..audioRelativePath = paths.audioRelativePath
      ..danmakuRelativePath = paths.danmakuRelativePath
      ..coverRelativePath = paths.coverRelativePath
      ..status = DownloadTaskStatus.pending;

    await _dao.saveTask(task);
    _emit(task);

    // 尝试立即调度
    _scheduleNext();

    return task;
  }

  /// 暂停指定任务。
  Future<void> pauseTask(String id) async {
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

    task.status = DownloadTaskStatus.pending;
    await _dao.saveTask(task);
    _emit(task);

    _scheduleNext();
  }

  /// 取消并删除任务。
  Future<void> cancelTask(String id, {bool deleteFiles = true}) async {
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
    final List<DownloadTask> resumable = _dao
        .getAllTasks()
        .where((DownloadTask t) => t.isResumable)
        .toList();
    for (final DownloadTask task in resumable) {
      task.status = DownloadTaskStatus.pending;
      await _dao.saveTask(task);
      _emit(task);
    }
    _scheduleNext();
  }

  /// 获取所有任务。
  List<DownloadTask> getAllTasks() => _dao.getAllTasks();

  /// 获取指定任务。
  DownloadTask? getTask(String id) => _dao.getTask(id);

  /// 当前活跃下载数量。
  int get activeCount => _executors.length;

  // ── 调度器 ──

  /// 尝试调度下一个 pending 任务。
  void _scheduleNext() {
    if (_executors.length >= _maxConcurrent) return;

    final List<DownloadTask> pending =
        _dao
            .getAllTasks()
            .where((DownloadTask t) => t.status == DownloadTaskStatus.pending)
            .toList()
          ..sort(
            (DownloadTask a, DownloadTask b) =>
                a.createdAt.compareTo(b.createdAt),
          );

    for (final DownloadTask task in pending) {
      if (_executors.length >= _maxConcurrent) break;
      if (_executors.containsKey(task.id)) continue;
      _executeTask(task);
    }
  }

  /// 启动单个任务的下载执行。
  Future<void> _executeTask(DownloadTask task) async {
    // 获取播放地址
    final urls = await _resolveUrls(task);
    if (urls == null) {
      task
        ..status = DownloadTaskStatus.failed
        ..errorMessage = '无法获取下载地址';
      await _dao.saveTask(task);
      _emit(task);
      _scheduleNext();
      return;
    }

    task.status = DownloadTaskStatus.downloading;
    await _dao.saveTask(task);
    _emit(task);

    final DownloadTaskExecutor executor = DownloadTaskExecutor(
      task: task,
      storageManager: _storageManager,
      videoUrl: urls.videoUrl,
      audioUrl: urls.audioUrl,
      onProgress: (int downloaded, int total, int speed) {
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
      },
    );

    _executors[task.id] = executor;

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
  }

  /// 解析视频/音频下载 URL。
  Future<_ResolvedUrls?> _resolveUrls(DownloadTask task) async {
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

        return _ResolvedUrls(
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
    await _taskUpdatesController.close();
    _instance = null;
  }
}

class _ResolvedUrls {
  const _ResolvedUrls({required this.videoUrl, required this.audioUrl});
  final String videoUrl;
  final String audioUrl;
}

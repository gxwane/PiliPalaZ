import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';

class DownloadPageController extends GetxController
    with GetSingleTickerProviderStateMixin {
  DownloadPageController({
    DownloadService? downloadService,
    DownloadStorageManager? storageManager,
  }) : _service = downloadService ?? DownloadService.instance,
       _storage = storageManager ?? DownloadStorageManager();

  final DownloadService _service;
  final DownloadStorageManager _storage;

  late final TabController tabController;
  StreamSubscription<DownloadTask>? _subscription;

  final RxList<DownloadTask> completedTasks = <DownloadTask>[].obs;
  final RxList<DownloadTask> activeTasks = <DownloadTask>[].obs;

  final RxInt usedDiskBytes = 0.obs;
  final RxInt availableDiskBytes = 0.obs;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);
    refreshTasks();
    refreshDiskSpace();

    _subscription = _service.taskUpdates.listen((DownloadTask _) {
      refreshTasks();
    });
  }

  @override
  void onClose() {
    _subscription?.cancel();
    tabController.dispose();
    super.onClose();
  }

  /// 刷新所有任务分类列表。
  void refreshTasks() {
    final List<DownloadTask> all = _service.getAllTasks();
    final List<DownloadTask> completed = <DownloadTask>[];
    final List<DownloadTask> active = <DownloadTask>[];

    for (final DownloadTask task in all) {
      if (task.status == DownloadTaskStatus.completed) {
        completed.add(task);
      } else {
        active.add(task);
      }
    }

    // 已完成按完成时间或创建时间倒序
    completed.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );

    // 进行中按创建时间正序
    active.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    completedTasks.value = completed;
    activeTasks.value = active;
  }

  /// 刷新磁盘使用情况。
  Future<void> refreshDiskSpace() async {
    try {
      int totalUsed = 0;
      final List<DownloadTask> all = _service.getAllTasks();
      for (final DownloadTask task in all) {
        totalUsed += await _storage.taskDiskUsage(task);
      }
      usedDiskBytes.value = totalUsed;
      availableDiskBytes.value = await _storage.availableDiskSpace();
    } catch (_) {}
  }

  Future<void> pauseTask(String id) async {
    await _service.pauseTask(id);
    refreshTasks();
  }

  Future<void> resumeTask(String id) async {
    await _service.resumeTask(id);
    refreshTasks();
  }

  Future<void> deleteTask(String id, {bool deleteFiles = true}) async {
    await _service.cancelTask(id, deleteFiles: deleteFiles);
    refreshTasks();
    await refreshDiskSpace();
    SmartDialog.showToast('已删除任务');
  }

  Future<void> pauseAll() async {
    await _service.pauseAll();
    refreshTasks();
  }

  Future<void> resumeAll() async {
    await _service.resumeAll();
    refreshTasks();
  }

  /// 格式化字节大小。
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value < 10 && unitIndex > 0 ? 1 : 0)} ${units[unitIndex]}';
  }

  /// 格式化下载速度。
  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 KB/s';
    return '${formatBytes(bytesPerSecond)}/s';
  }

  /// 格式化时长。
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    if (min < 60) {
      return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    final int hour = min ~/ 60;
    final int remMin = min % 60;
    return '${hour.toString().padLeft(2, '0')}:${remMin.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

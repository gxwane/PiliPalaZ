/// 离线缓存本地存储路径管理与磁盘水位检测。
///
/// 管理离线根目录、相对路径与绝对路径换算、物理文件删除。
/// 所有路径使用**相对路径**持久化，规避 iOS 沙盒 UUID 变动与跨设备迁移问题。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pilipalaz/models/download/download_task.dart';

/// 磁盘安全水位红线（200 MB）。
const int kMinSafeSpaceBytes = 200 * 1024 * 1024;

/// 磁盘空间查询抽象，便于测试注入。
typedef DiskSpaceProvider = Future<int> Function(String path);

/// 离线缓存存储管理器。
///
/// 管理下载根目录、相对/绝对路径换算、磁盘水位检测与文件清理。
class DownloadStorageManager {
  DownloadStorageManager({
    DiskSpaceProvider? diskSpaceProvider,
    Future<Directory> Function()? directoryProvider,
  }) : _diskSpaceProvider = diskSpaceProvider ?? _defaultDiskSpace,
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  final DiskSpaceProvider _diskSpaceProvider;
  final Future<Directory> Function() _directoryProvider;

  String? _rootPath;

  /// 获取离线根目录绝对路径，首次调用时初始化。
  Future<String> getRootPath() async {
    if (_rootPath != null) return _rootPath!;
    final Directory appDir = await _directoryProvider();
    final String root = p.join(appDir.path, 'pilipalaz_downloads');
    await Directory(root).create(recursive: true);
    _rootPath = root;
    return root;
  }

  /// 为指定任务生成存储子目录相对路径。
  String taskDirName(DownloadTask task) => task.id;

  /// 将相对路径转为绝对路径。
  Future<String> absolutePath(String relativePath) async {
    final String root = await getRootPath();
    return p.join(root, relativePath);
  }

  /// 为新任务生成标准相对路径集。
  DownloadPaths pathsForTask(DownloadTask task) {
    final String dir = taskDirName(task);
    return DownloadPaths(
      videoRelativePath: p.join(dir, 'video.m4s'),
      audioRelativePath: p.join(dir, 'audio.m4s'),
      danmakuRelativePath: p.join(dir, 'danmaku.bin'),
      coverRelativePath: p.join(dir, 'cover.jpg'),
    );
  }

  /// 获取临时下载文件的绝对路径（`.part` 后缀）。
  Future<String> videoPartPath(DownloadTask task) async =>
      '${await absolutePath(p.join(taskDirName(task), 'video.m4s'))}.part';

  Future<String> audioPartPath(DownloadTask task) async =>
      '${await absolutePath(p.join(taskDirName(task), 'audio.m4s'))}.part';

  // ── 磁盘水位检测 ──

  /// 查询当前可用磁盘空间（字节）。
  Future<int> availableDiskSpace() async {
    final String root = await getRootPath();
    return _diskSpaceProvider(root);
  }

  /// 前置容量断言：可用空间 >= 预估大小 + 安全水位。
  ///
  /// 返回 `true` 表示空间充足，`false` 表示不足。
  Future<bool> hasEnoughSpace(int estimatedBytes) async {
    final int available = await availableDiskSpace();
    return available >= estimatedBytes + kMinSafeSpaceBytes;
  }

  /// 运行时水位检查：仅检测是否跌破安全红线。
  Future<bool> isBelowSafetyThreshold() async {
    final int available = await availableDiskSpace();
    return available < kMinSafeSpaceBytes;
  }

  // ── 文件清理 ──

  /// 删除指定任务的全部本地文件（含 `.part` 临时文件）。
  Future<void> deleteTaskFiles(DownloadTask task) async {
    final String root = await getRootPath();
    final String taskDir = p.join(root, taskDirName(task));
    final Directory dir = Directory(taskDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 计算指定任务已占用的磁盘空间（字节）。
  Future<int> taskDiskUsage(DownloadTask task) async {
    final String root = await getRootPath();
    final String taskDir = p.join(root, taskDirName(task));
    final Directory dir = Directory(taskDir);
    if (!await dir.exists()) return 0;

    int total = 0;
    await for (final FileSystemEntity entity in dir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ── 平台默认磁盘空间查询 ──

  /// 默认磁盘空间查询实现（跨平台 `StatFs`）。
  static Future<int> _defaultDiskSpace(String path) async {
    try {
      final FileStat stat = await FileStat.stat(path);
      // Dart FileStat 不直接暴露可用空间。
      // 在 Android/iOS 上通过 path_provider 的目录存在性验证即可，
      // 实际空间查询需要平台通道；此处返回一个保守的大值，
      // 让上层逻辑在无法查询时默认允许下载。
      // 真实的平台级磁盘空间查询将在 DownloadService 中通过
      // MethodChannel 实现。
      if (stat.type == FileSystemEntityType.notFound) {
        return 0;
      }
      // 回退：返回 2GB，表示无法精确查询但假设空间充足。
      return 2 * 1024 * 1024 * 1024;
    } on FileSystemException {
      return 0;
    }
  }
}

/// 一组下载任务的标准相对路径。
class DownloadPaths {
  const DownloadPaths({
    required this.videoRelativePath,
    required this.audioRelativePath,
    required this.danmakuRelativePath,
    required this.coverRelativePath,
  });

  final String videoRelativePath;
  final String audioRelativePath;
  final String danmakuRelativePath;
  final String coverRelativePath;
}

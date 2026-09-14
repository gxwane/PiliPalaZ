/// 下载任务持久化数据访问对象。
///
/// 使用 Hive [Box<Map>] 进行任务元数据持久化，
/// 不直接持有 [BuildContext] 或触发 UI 操作。
library;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:pilipalaz/models/download/download_task.dart';

/// Hive Box 名称常量。
const String _boxName = 'downloadTasks';

/// [DownloadTask] 的持久化 DAO 层。
///
/// 使用 `Box<Map>` 存储序列化后的 Map 结构，
/// 避免依赖 `@HiveType` 注解与 `build_runner` 代码生成。
///
/// 内存缓存 [_cache] 与 Hive Box 保持同步，
/// 读操作直接命中缓存，写操作先更新缓存再落盘。
class DownloadDao {
  DownloadDao._();

  static DownloadDao? _instance;

  /// 获取单例。必须在 [init] 之后调用。
  static DownloadDao get instance {
    assert(_instance != null, 'DownloadDao.init() must be called first');
    return _instance!;
  }

  late final Box<Map> _box;

  /// 内存任务缓存，以 [DownloadTask.id] 为键。
  final Map<String, DownloadTask> _cache = <String, DownloadTask>{};

  /// 初始化 DAO：打开 Hive Box 并加载全部任务到内存缓存。
  ///
  /// 应在应用启动阶段（[GStorage.init] 之后）调用一次。
  static Future<DownloadDao> init() async {
    final DownloadDao dao = DownloadDao._();
    dao._box = await Hive.openBox<Map>(_boxName);
    dao._loadCache();
    _instance = dao;
    return dao;
  }

  /// 从 Hive Box 加载全部条目到内存缓存。
  void _loadCache() {
    _cache.clear();
    for (final dynamic key in _box.keys) {
      final Map? raw = _box.get(key);
      if (raw == null) continue;
      try {
        final DownloadTask task = DownloadTask.fromMap(raw);
        _cache[task.id] = task;
      } on Object {
        // 跳过损坏条目，避免阻塞初始化。
      }
    }
  }

  /// 获取所有任务的快照（不可变副本）。
  List<DownloadTask> getAllTasks() {
    return List<DownloadTask>.unmodifiable(_cache.values.toList());
  }

  /// 按 ID 获取单个任务，不存在返回 `null`。
  DownloadTask? getTask(String id) => _cache[id];

  /// 保存（新增或更新）任务。
  ///
  /// 先更新内存缓存，再原子写入 Hive Box。
  Future<void> saveTask(DownloadTask task) async {
    _cache[task.id] = task;
    await _box.put(task.id, task.toMap());
  }

  /// 删除任务元数据（不处理物理文件）。
  Future<void> deleteTask(String id) async {
    _cache.remove(id);
    await _box.delete(id);
  }

  /// 批量保存多个任务，减少 I/O 次数。
  Future<void> saveTasks(List<DownloadTask> tasks) async {
    final Map<String, Map<String, dynamic>> entries =
        <String, Map<String, dynamic>>{};
    for (final DownloadTask task in tasks) {
      _cache[task.id] = task;
      entries[task.id] = task.toMap();
    }
    await _box.putAll(entries);
  }

  /// 当前缓存的任务数量。
  int get taskCount => _cache.length;

  /// 仅用于测试：关闭并清理 Box。
  Future<void> dispose() async {
    _cache.clear();
    if (_box.isOpen) {
      await _box.close();
    }
    _instance = null;
  }
}

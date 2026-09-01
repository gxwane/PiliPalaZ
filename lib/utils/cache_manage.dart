import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef CacheDirectoryProvider = Future<Directory> Function();

abstract interface class ApplicationCacheService {
  int? get cachedApplicationCacheSizeBytes;

  Future<int?> refreshApplicationCacheSize();

  Future<void> clearApplicationCache();
}

class CacheManage implements ApplicationCacheService {
  CacheManage({
    CacheDirectoryProvider? temporaryDirectoryProvider,
    CacheDirectoryProvider? applicationDocumentsDirectoryProvider,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _applicationDocumentsDirectoryProvider =
           applicationDocumentsDirectoryProvider ??
           getApplicationDocumentsDirectory;

  static final CacheManage instance = CacheManage();

  final CacheDirectoryProvider _temporaryDirectoryProvider;
  final CacheDirectoryProvider _applicationDocumentsDirectoryProvider;

  int _generation = 0;
  int? _cachedApplicationCacheSizeBytes;
  Future<int?>? _refreshInFlight;
  Future<void>? _clearInFlight;

  @override
  int? get cachedApplicationCacheSizeBytes => _cachedApplicationCacheSizeBytes;

  @override
  Future<int?> refreshApplicationCacheSize() {
    final clearing = _clearInFlight;
    if (clearing != null) {
      return clearing.then((_) => refreshApplicationCacheSize());
    }

    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final generation = _generation;
    late final Future<int?> operation;
    operation = _calculateApplicationCacheSize(generation)
        .then((bytes) {
          if (bytes == null || generation != _generation) {
            return null;
          }
          _cachedApplicationCacheSizeBytes = bytes;
          return bytes;
        })
        .whenComplete(() {
          if (identical(_refreshInFlight, operation)) {
            _refreshInFlight = null;
          }
        });
    _refreshInFlight = operation;
    return operation;
  }

  Future<int?> _calculateApplicationCacheSize(int generation) async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    if (generation != _generation) {
      return null;
    }
    final documentsDirectory = await _applicationDocumentsDirectoryProvider();
    if (generation != _generation) {
      return null;
    }

    final temporarySize = await _sizeOfEntity(temporaryDirectory, generation);
    if (temporarySize == null) {
      return null;
    }

    final dioCache = File(
      '${documentsDirectory.path}${Platform.pathSeparator}DioCache.db',
    );
    final dioCacheSize = await _sizeOfEntity(dioCache, generation);
    if (dioCacheSize == null) {
      return null;
    }
    return temporarySize + dioCacheSize;
  }

  Future<int?> _sizeOfEntity(FileSystemEntity entity, int generation) async {
    if (generation != _generation) {
      return null;
    }

    try {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (generation != _generation) {
        return null;
      }

      if (type == FileSystemEntityType.notFound ||
          type == FileSystemEntityType.link) {
        return 0;
      }
      if (type == FileSystemEntityType.file) {
        final length = await File(entity.path).length();
        return generation == _generation ? length : null;
      }
      if (type != FileSystemEntityType.directory) {
        return 0;
      }

      var total = 0;
      await for (final child in Directory(
        entity.path,
      ).list(followLinks: false)) {
        if (generation != _generation) {
          return null;
        }
        final childSize = await _sizeOfEntity(child, generation);
        if (childSize == null) {
          return null;
        }
        total += childSize;
      }
      return generation == _generation ? total : null;
    } on PathNotFoundException {
      return generation == _generation ? 0 : null;
    }
  }

  @override
  Future<void> clearApplicationCache() {
    final inFlight = _clearInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    _generation++;
    _cachedApplicationCacheSizeBytes = null;
    _refreshInFlight = null;

    late final Future<void> operation;
    operation = _clearApplicationCacheTargets().whenComplete(() {
      if (identical(_clearInFlight, operation)) {
        _clearInFlight = null;
      }
    });
    _clearInFlight = operation;
    return operation;
  }

  Future<void> _clearApplicationCacheTargets() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    void recordError(Object error, StackTrace stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    try {
      final temporaryDirectory = await _temporaryDirectoryProvider();
      await _clearDirectoryContents(temporaryDirectory, recordError);
    } on PathNotFoundException {
      // The operating system may remove an empty cache directory at any time.
    } catch (error, stackTrace) {
      recordError(error, stackTrace);
    }

    try {
      final documentsDirectory = await _applicationDocumentsDirectoryProvider();
      final dioCache = File(
        '${documentsDirectory.path}${Platform.pathSeparator}DioCache.db',
      );
      try {
        await dioCache.delete();
      } on PathNotFoundException {
        // The cache database is optional and may already have been removed.
      }
    } on PathNotFoundException {
      // The application documents directory may not exist yet.
    } catch (error, stackTrace) {
      recordError(error, stackTrace);
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> _clearDirectoryContents(
    Directory directory,
    void Function(Object error, StackTrace stackTrace) recordError,
  ) async {
    await for (final child in directory.list(followLinks: false)) {
      try {
        await child.delete(recursive: true);
      } on PathNotFoundException {
        // Another cache operation may have removed this entry first.
      } catch (error, stackTrace) {
        recordError(error, stackTrace);
      }
    }
  }
}

String formatCacheSize(int bytes) {
  const units = <String>['B', 'K', 'M', 'G', 'T'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(2)}${units[unitIndex]}';
}

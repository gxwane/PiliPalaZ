import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/http/init.dart';
import 'package:pilipalaz/models/github/latest.dart';
import 'package:pilipalaz/utils/app_update.dart';
import 'package:pilipalaz/utils/storage.dart';

enum AppUpdateErrorCode {
  invalidResponse,
  assetUnavailable,
  checksumUnavailable,
  checksumMismatch,
  downloadNotReady,
  downloadFailed,
  taskMissing,
  unsupported,
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.code, this.message);

  final AppUpdateErrorCode code;
  final String message;

  @override
  String toString() => message;
}

enum UpdateDownloadStatus {
  missing,
  pending,
  running,
  paused,
  successful,
  failed,
}

class UpdateDownloadSnapshot {
  const UpdateDownloadSnapshot({
    required this.status,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.reason,
  });

  final UpdateDownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final String? reason;

  double? get progress {
    if (totalBytes <= 0) {
      return null;
    }
    return (downloadedBytes / totalBytes).clamp(0, 1);
  }
}

class AppUpdateTask {
  const AppUpdateTask({
    required this.downloadId,
    required this.versionTag,
    required this.releaseUrl,
    required this.fileName,
    required this.downloadUrl,
    required this.expectedSha256,
    required this.prerelease,
    this.verified = false,
    this.awaitingInstallPermission = false,
  });

  final int downloadId;
  final String versionTag;
  final String releaseUrl;
  final String fileName;
  final String downloadUrl;
  final String expectedSha256;
  final bool prerelease;
  final bool verified;
  final bool awaitingInstallPermission;

  AppUpdateTask copyWith({
    int? downloadId,
    bool? verified,
    bool? awaitingInstallPermission,
  }) {
    return AppUpdateTask(
      downloadId: downloadId ?? this.downloadId,
      versionTag: versionTag,
      releaseUrl: releaseUrl,
      fileName: fileName,
      downloadUrl: downloadUrl,
      expectedSha256: expectedSha256,
      prerelease: prerelease,
      verified: verified ?? this.verified,
      awaitingInstallPermission:
          awaitingInstallPermission ?? this.awaitingInstallPermission,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'downloadId': downloadId,
      'versionTag': versionTag,
      'releaseUrl': releaseUrl,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'expectedSha256': expectedSha256,
      'prerelease': prerelease,
      'verified': verified,
      'awaitingInstallPermission': awaitingInstallPermission,
    };
  }

  static AppUpdateTask? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(value);
    final downloadId = json['downloadId'];
    final versionTag = json['versionTag'];
    final releaseUrl = json['releaseUrl'];
    final fileName = json['fileName'];
    final downloadUrl = json['downloadUrl'];
    final expectedSha256 = json['expectedSha256'];
    if (downloadId is! int ||
        versionTag is! String ||
        releaseUrl is! String ||
        fileName is! String ||
        downloadUrl is! String ||
        expectedSha256 is! String) {
      return null;
    }
    return AppUpdateTask(
      downloadId: downloadId,
      versionTag: versionTag,
      releaseUrl: releaseUrl,
      fileName: fileName,
      downloadUrl: downloadUrl,
      expectedSha256: expectedSha256,
      prerelease: json['prerelease'] == true,
      verified: json['verified'] == true,
      awaitingInstallPermission: json['awaitingInstallPermission'] == true,
    );
  }
}

abstract class AppUpdateReleaseRepository {
  Future<List<LatestDataModel>> fetchReleases();

  Future<LatestDataModel?> fetchLatestStable();

  Future<String> fetchText(String url);
}

class GitHubAppUpdateReleaseRepository implements AppUpdateReleaseRepository {
  @override
  Future<List<LatestDataModel>> fetchReleases() async {
    final response = await Request().get(
      '${ProjectLinks.releasesApi}?per_page=30',
      extra: const <String, dynamic>{'ua': 'mob'},
    );
    final data = response.data;
    if (data is! List) {
      throw const AppUpdateException(
        AppUpdateErrorCode.invalidResponse,
        'GitHub Releases 返回了无效数据',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(LatestDataModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<LatestDataModel?> fetchLatestStable() async {
    final response = await Request().get(
      ProjectLinks.latestReleaseApi,
      extra: const <String, dynamic>{'ua': 'mob'},
    );
    final data = response.data;
    if (data is! Map<String, dynamic> || data['tag_name'] is! String) {
      throw const AppUpdateException(
        AppUpdateErrorCode.invalidResponse,
        'GitHub Release 返回了无效数据',
      );
    }
    return LatestDataModel.fromJson(data);
  }

  @override
  Future<String> fetchText(String url) async {
    final response = await Request().get(
      url,
      extra: const <String, dynamic>{
        'ua': 'mob',
        'resType': ResponseType.plain,
      },
    );
    final data = response.data;
    if (data is! String) {
      throw const AppUpdateException(
        AppUpdateErrorCode.checksumUnavailable,
        '无法获取安装包校验清单',
      );
    }
    return data;
  }
}

abstract class AppUpdateTaskStore {
  AppUpdateTask? read();

  Future<void> write(AppUpdateTask value);

  Future<void> clear();
}

class HiveAppUpdateTaskStore implements AppUpdateTaskStore {
  HiveAppUpdateTaskStore([Box<dynamic>? box])
    : _box = box ?? GStorage.localCache;

  static const String _key = 'activeAppUpdateDownload';
  final Box<dynamic> _box;

  @override
  Future<void> clear() => _box.delete(_key);

  @override
  AppUpdateTask? read() => AppUpdateTask.fromJson(_box.get(_key));

  @override
  Future<void> write(AppUpdateTask value) => _box.put(_key, value.toJson());
}

abstract class AppUpdatePlatform {
  bool get supportsInAppInstall;

  Future<int> enqueue({
    required String url,
    required String fileName,
    required String title,
  });

  Future<UpdateDownloadSnapshot> query(int downloadId);

  Future<void> cancel(int downloadId);

  Future<String> sha256(int downloadId);

  Future<bool> canInstallPackages();

  Future<void> openInstallPermissionSettings();

  Future<void> install({required int downloadId, required String fileName});
}

class AppUpdateService {
  AppUpdateService({
    required this.repository,
    required this.platform,
    required this.taskStore,
  });

  final AppUpdateReleaseRepository repository;
  final AppUpdatePlatform platform;
  final AppUpdateTaskStore taskStore;

  Future<AppUpdateCandidates> findCandidates(String localVersion) async {
    final releases = await repository.fetchReleases();
    return AppUpdatePolicy.selectCandidates(
      localVersion: localVersion,
      releases: releases,
    );
  }

  Future<LatestDataModel?> findStableUpdate(String localVersion) async {
    final release = await repository.fetchLatestStable();
    if (release == null) {
      return null;
    }
    return AppUpdatePolicy.selectCandidates(
      localVersion: localVersion,
      releases: <LatestDataModel>[release],
    ).stable;
  }

  AppUpdateTask? get activeTask => taskStore.read();

  Future<AppUpdateTask> startDownload(
    LatestDataModel release,
    String abi,
  ) async {
    if (!platform.supportsInAppInstall) {
      throw const AppUpdateException(
        AppUpdateErrorCode.unsupported,
        '当前平台不支持应用内安装',
      );
    }
    final asset = AppUpdatePolicy.selectAndroidAsset(release.assets, abi);
    if (asset == null) {
      throw const AppUpdateException(
        AppUpdateErrorCode.assetUnavailable,
        '未找到适用于当前设备的安全安装包',
      );
    }
    final existing = taskStore.read();
    if (existing != null &&
        existing.versionTag == release.tagName &&
        existing.fileName == asset.name) {
      return existing;
    }

    final checksumAsset = _selectChecksumAsset(release.assets);
    if (checksumAsset == null) {
      throw const AppUpdateException(
        AppUpdateErrorCode.checksumUnavailable,
        '此版本未提供 SHA-256 校验清单',
      );
    }
    final manifest = await repository.fetchText(checksumAsset.downloadUrl!);
    final checksum = AppUpdatePolicy.selectChecksum(manifest, asset.name!);
    if (checksum == null) {
      throw const AppUpdateException(
        AppUpdateErrorCode.checksumUnavailable,
        '校验清单中未找到当前安装包',
      );
    }

    if (existing != null) {
      await platform.cancel(existing.downloadId);
      await taskStore.clear();
    }
    final downloadId = await platform.enqueue(
      url: asset.downloadUrl!,
      fileName: asset.name!,
      title: 'PiliPalaZ ${release.tagName ?? ''}',
    );
    final task = AppUpdateTask(
      downloadId: downloadId,
      versionTag: release.tagName ?? '',
      releaseUrl: release.htmlUrl ?? ProjectLinks.releases,
      fileName: asset.name!,
      downloadUrl: asset.downloadUrl!,
      expectedSha256: checksum,
      prerelease: release.prerelease,
    );
    await taskStore.write(task);
    return task;
  }

  Future<UpdateDownloadSnapshot?> refreshActiveTask() async {
    var task = taskStore.read();
    if (task == null) {
      return null;
    }
    final snapshot = await platform.query(task.downloadId);
    if (snapshot.status == UpdateDownloadStatus.missing) {
      await taskStore.clear();
      return snapshot;
    }
    if (snapshot.status == UpdateDownloadStatus.successful && !task.verified) {
      final digest = (await platform.sha256(task.downloadId)).toLowerCase();
      if (digest != task.expectedSha256.toLowerCase()) {
        await platform.cancel(task.downloadId);
        await taskStore.clear();
        throw const AppUpdateException(
          AppUpdateErrorCode.checksumMismatch,
          '安装包完整性校验失败，已删除下载文件',
        );
      }
      task = task.copyWith(verified: true);
      await taskStore.write(task);
    }
    return snapshot;
  }

  Future<void> cancelActiveTask() async {
    final task = taskStore.read();
    if (task == null) {
      return;
    }
    await platform.cancel(task.downloadId);
    await taskStore.clear();
  }

  Future<AppUpdateTask> retryActiveTask() async {
    final task = taskStore.read();
    if (task == null) {
      throw const AppUpdateException(
        AppUpdateErrorCode.taskMissing,
        '没有可重试的更新任务',
      );
    }
    await platform.cancel(task.downloadId);
    final downloadId = await platform.enqueue(
      url: task.downloadUrl,
      fileName: task.fileName,
      title: 'PiliPalaZ ${task.versionTag}',
    );
    final replacement = task.copyWith(
      downloadId: downloadId,
      verified: false,
      awaitingInstallPermission: false,
    );
    await taskStore.write(replacement);
    return replacement;
  }

  Future<bool> installActiveTask() async {
    var task = taskStore.read();
    if (task == null) {
      throw const AppUpdateException(
        AppUpdateErrorCode.taskMissing,
        '没有可安装的更新任务',
      );
    }
    final snapshot = await refreshActiveTask();
    task = taskStore.read();
    if (snapshot?.status != UpdateDownloadStatus.successful ||
        task == null ||
        !task.verified) {
      throw const AppUpdateException(
        AppUpdateErrorCode.downloadNotReady,
        '安装包尚未下载并校验完成',
      );
    }
    if (!await platform.canInstallPackages()) {
      task = task.copyWith(awaitingInstallPermission: true);
      await taskStore.write(task);
      await platform.openInstallPermissionSettings();
      return false;
    }
    if (task.awaitingInstallPermission) {
      task = task.copyWith(awaitingInstallPermission: false);
      await taskStore.write(task);
    }
    await platform.install(
      downloadId: task.downloadId,
      fileName: task.fileName,
    );
    return true;
  }

  Future<bool> resumePendingInstall() async {
    var task = taskStore.read();
    if (task == null || !task.awaitingInstallPermission || !task.verified) {
      return false;
    }
    if (!await platform.canInstallPackages()) {
      return false;
    }
    task = task.copyWith(awaitingInstallPermission: false);
    await taskStore.write(task);
    await platform.install(
      downloadId: task.downloadId,
      fileName: task.fileName,
    );
    return true;
  }

  Future<void> cleanupInstalledTask(String localVersion) async {
    final task = taskStore.read();
    final local = AppUpdatePolicy.parseVersion(localVersion);
    final target = AppUpdatePolicy.parseVersion(task?.versionTag);
    if (task == null || local == null || target == null || local < target) {
      return;
    }
    await platform.cancel(task.downloadId);
    await taskStore.clear();
  }

  AssetItem? _selectChecksumAsset(Iterable<AssetItem> assets) {
    for (final asset in assets) {
      final url = Uri.tryParse(asset.downloadUrl ?? '');
      if (asset.name == 'SHA256SUMS' &&
          url != null &&
          url.scheme == 'https' &&
          url.host.isNotEmpty) {
        return asset;
      }
    }
    return null;
  }
}

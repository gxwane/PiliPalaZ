import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pilipalaz/services/app_update_service.dart';
import 'package:pilipalaz/services/github_app_update_repository.dart';

AppUpdateService? _appUpdateService;

AppUpdateService get appUpdateService {
  return _appUpdateService ??= AppUpdateService(
    repository: GitHubAppUpdateReleaseRepository(),
    platform: const MethodChannelAppUpdatePlatform(),
    taskStore: HiveAppUpdateTaskStore(),
  );
}

class MethodChannelAppUpdatePlatform implements AppUpdatePlatform {
  const MethodChannelAppUpdatePlatform();

  static const MethodChannel _channel = MethodChannel(
    'io.github.gxwane.pilipalaz/app_update',
  );

  @override
  bool get supportsInAppInstall => Platform.isAndroid;

  @override
  Future<void> cancel(int downloadId) {
    return _channel.invokeMethod<void>('cancel', <String, dynamic>{
      'downloadId': downloadId,
    });
  }

  @override
  Future<bool> canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  @override
  Future<int> enqueue({
    required String url,
    required String fileName,
    required String title,
  }) async {
    final id = await _channel.invokeMethod<int>('enqueue', <String, dynamic>{
      'url': url,
      'fileName': fileName,
      'title': title,
    });
    if (id == null) {
      throw const AppUpdateException(
        AppUpdateErrorCode.downloadFailed,
        '系统下载服务未返回任务编号',
      );
    }
    return id;
  }

  @override
  Future<void> install({required int downloadId, required String fileName}) {
    return _channel.invokeMethod<void>('install', <String, dynamic>{
      'downloadId': downloadId,
      'fileName': fileName,
    });
  }

  @override
  Future<void> openInstallPermissionSettings() {
    return _channel.invokeMethod<void>('openInstallSettings');
  }

  @override
  Future<UpdateDownloadSnapshot> query(int downloadId) async {
    final value = await _channel.invokeMapMethod<String, dynamic>(
      'query',
      <String, dynamic>{'downloadId': downloadId},
    );
    if (value == null) {
      return const UpdateDownloadSnapshot(status: UpdateDownloadStatus.missing);
    }
    return UpdateDownloadSnapshot(
      status: _parseStatus(value['status']),
      downloadedBytes: (value['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (value['totalBytes'] as num?)?.toInt() ?? 0,
      reason: value['reason']?.toString(),
    );
  }

  @override
  Future<String> sha256(int downloadId) async {
    final value = await _channel.invokeMethod<String>(
      'sha256',
      <String, dynamic>{'downloadId': downloadId},
    );
    if (value == null || !RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(value)) {
      throw const AppUpdateException(
        AppUpdateErrorCode.checksumMismatch,
        '系统无法计算安装包摘要',
      );
    }
    return value.toLowerCase();
  }

  UpdateDownloadStatus _parseStatus(Object? value) {
    return switch (value) {
      'pending' => UpdateDownloadStatus.pending,
      'running' => UpdateDownloadStatus.running,
      'paused' => UpdateDownloadStatus.paused,
      'successful' => UpdateDownloadStatus.successful,
      'failed' => UpdateDownloadStatus.failed,
      _ => UpdateDownloadStatus.missing,
    };
  }
}

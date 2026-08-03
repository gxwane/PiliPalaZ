import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/models/github/latest.dart';
import 'package:pilipalaz/services/app_update_platform.dart';
import 'package:pilipalaz/services/app_update_service.dart';
import 'package:pilipalaz/utils/app_update.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateCoordinator with WidgetsBindingObserver {
  AppUpdateCoordinator._();

  static final AppUpdateCoordinator instance = AppUpdateCoordinator._();

  bool _initialized = false;
  bool _polling = false;
  Timer? _pollTimer;
  int? _lastPromptedDownloadId;

  AppUpdateService get service => appUpdateService;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final localVersion = await _localVersion();
    await service.cleanupInstalledTask(localVersion);
    await _handleResume();
  }

  Future<void> checkStableAutomatically() async {
    try {
      final release = await service.findStableUpdate(await _localVersion());
      if (release == null) {
        return;
      }
      SmartDialog.show(
        useSystem: true,
        builder: (context) =>
            StableUpdateDialog(release: release, coordinator: this),
      );
    } catch (_) {
      // Automatic checks intentionally stay silent.
    }
  }

  Future<void> showManualUpdateCenter(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          UpdateCenterDialog(localVersion: '', coordinator: this),
    );
  }

  Future<bool> startDownload(
    BuildContext context,
    LatestDataModel release,
  ) async {
    if (release.prerelease && !await showPrereleaseWarning(context, release)) {
      return false;
    }
    if (!Platform.isAndroid || !service.platform.supportsInAppInstall) {
      await _openRelease(release);
      return true;
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final abi = androidInfo.supportedAbis.isEmpty
          ? ''
          : androidInfo.supportedAbis.first;
      await service.startDownload(release, abi);
      SmartDialog.showToast('已加入系统下载，可在通知栏查看进度');
      watchActiveTask();
      return true;
    } on AppUpdateException catch (error) {
      if (error.code == AppUpdateErrorCode.checksumUnavailable ||
          error.code == AppUpdateErrorCode.assetUnavailable) {
        if (!context.mounted) {
          return false;
        }
        await _showExternalFallback(context, release, error.message);
      } else {
        SmartDialog.showToast(error.message);
      }
      return false;
    } catch (_) {
      SmartDialog.showToast('创建系统下载任务失败，请稍后重试');
      return false;
    }
  }

  Future<bool> retryActiveTask(BuildContext context) async {
    final task = service.activeTask;
    if (task == null) {
      return false;
    }
    if (task.prerelease) {
      final release = LatestDataModel(
        tagName: task.versionTag,
        htmlUrl: task.releaseUrl,
        prerelease: true,
      );
      if (!await showPrereleaseWarning(context, release)) {
        return false;
      }
    }
    try {
      await service.retryActiveTask();
      SmartDialog.showToast('已重新加入系统下载');
      watchActiveTask();
      return true;
    } on AppUpdateException catch (error) {
      SmartDialog.showToast(error.message);
      return false;
    } catch (_) {
      SmartDialog.showToast('重新下载失败，请稍后重试');
      return false;
    }
  }

  Future<void> installActiveTask(BuildContext context) async {
    try {
      if (!await service.platform.canInstallPackages()) {
        if (!context.mounted ||
            !await showInstallPermissionExplanation(context)) {
          return;
        }
      }
      await service.installActiveTask();
    } on AppUpdateException catch (error) {
      SmartDialog.showToast(error.message);
    } catch (_) {
      SmartDialog.showToast('无法打开系统安装器');
    }
  }

  Future<bool> showPrereleaseWarning(
    BuildContext context,
    LatestDataModel release,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PrereleaseWarningDialog(release: release),
        ) ??
        false;
  }

  Future<bool> showInstallPermissionExplanation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('允许安装此来源的应用'),
            content: const Text(
              'Android 需要你单独授权 PiliPalaZ 打开已下载的安装包。'
              '授权只用于本次及以后由 PiliPalaZ 发起的系统安装确认，'
              '应用不会静默安装。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('前往设置'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void watchActiveTask() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollActiveTask(),
    );
    unawaited(_pollActiveTask());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  Future<void> _handleResume() async {
    try {
      if (await service.resumePendingInstall()) {
        return;
      }
      if (service.activeTask != null) {
        watchActiveTask();
      }
    } catch (_) {
      // A recoverable task remains available in the update center.
    }
  }

  Future<void> _pollActiveTask() async {
    if (_polling) {
      return;
    }
    final taskBeforeRefresh = service.activeTask;
    if (taskBeforeRefresh == null) {
      _stopPolling();
      return;
    }
    _polling = true;
    try {
      final snapshot = await service.refreshActiveTask();
      final task = service.activeTask;
      if (snapshot?.status == UpdateDownloadStatus.successful &&
          task?.verified == true) {
        _stopPolling();
        if (_lastPromptedDownloadId != task!.downloadId) {
          _lastPromptedDownloadId = task.downloadId;
          _showInstallReady(task);
        }
      } else if (snapshot?.status == UpdateDownloadStatus.failed ||
          snapshot?.status == UpdateDownloadStatus.missing) {
        _stopPolling();
      }
    } on AppUpdateException catch (error) {
      _stopPolling();
      SmartDialog.showToast(error.message);
    } finally {
      _polling = false;
    }
  }

  void _showInstallReady(AppUpdateTask task) {
    SmartDialog.show(
      useSystem: true,
      builder: (context) => AlertDialog(
        title: const Text('更新已下载并通过校验'),
        content: Text('${task.versionTag} 已准备好，是否立即打开系统安装器？'),
        actions: [
          TextButton(onPressed: SmartDialog.dismiss, child: const Text('稍后')),
          FilledButton(
            onPressed: () async {
              await installActiveTask(context);
              SmartDialog.dismiss();
            },
            child: const Text('立即安装'),
          ),
        ],
      ),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<String> _localVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  Future<void> _showExternalFallback(
    BuildContext context,
    LatestDataModel release,
    String reason,
  ) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('无法安全地在应用内更新'),
        content: Text('$reason。你仍可前往项目 Release 页面手动下载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('打开 Release 页面'),
          ),
        ],
      ),
    );
    if (open == true) {
      await _openRelease(release);
    }
  }

  Future<void> _openRelease(LatestDataModel release) {
    return launchUrl(
      Uri.parse(release.htmlUrl ?? ProjectLinks.releases),
      mode: LaunchMode.externalApplication,
    ).then((_) {});
  }
}

class PrereleaseWarningDialog extends StatelessWidget {
  const PrereleaseWarningDialog({required this.release, super.key});

  final LatestDataModel release;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('安装测试版前请确认'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              release.tagName ?? '测试版',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              '这是稳定性低于正式版的预发布版本，可能出现崩溃、播放异常、'
              '功能回退或设置兼容问题。',
            ),
            const SizedBox(height: 8),
            const Text(
              '安装较新的测试版后，通常无法直接覆盖安装版本号更低的正式版；'
              '卸载后降级会清除应用数据。',
            ),
            const SizedBox(height: 8),
            const Text('建议继续前先在“关于 → 导入/导出设置”中导出设置。'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            launchUrl(
              Uri.parse(release.htmlUrl ?? ProjectLinks.releases),
              mode: LaunchMode.externalApplication,
            );
          },
          child: const Text('查看发行说明'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('我已了解风险，继续下载'),
        ),
      ],
    );
  }
}

class StableUpdateDialog extends StatelessWidget {
  const StableUpdateDialog({
    required this.release,
    required this.coordinator,
    super.key,
  });

  final LatestDataModel release;
  final AppUpdateCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🎉 发现正式版更新'),
      content: SizedBox(
        width: 480,
        height: 280,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                release.tagName ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(release.body),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            GStorage.setting.put(SettingBoxKey.autoUpdate, false);
            SmartDialog.dismiss();
          },
          child: const Text('关闭启动检查'),
        ),
        TextButton(onPressed: SmartDialog.dismiss, child: const Text('稍后')),
        FilledButton(
          onPressed: () async {
            if (await coordinator.startDownload(context, release)) {
              SmartDialog.dismiss();
            }
          },
          child: Text(Platform.isAndroid ? '下载更新' : '打开 Release'),
        ),
      ],
    );
  }
}

class UpdateCenterDialog extends StatefulWidget {
  const UpdateCenterDialog({
    required this.localVersion,
    required this.coordinator,
    super.key,
  });

  final String localVersion;
  final AppUpdateCoordinator coordinator;

  @override
  State<UpdateCenterDialog> createState() => _UpdateCenterDialogState();
}

class _UpdateCenterDialogState extends State<UpdateCenterDialog> {
  AppUpdateCandidates? _candidates;
  AppUpdateTask? _task;
  UpdateDownloadSnapshot? _snapshot;
  String _localVersion = '';
  String? _error;
  Timer? _timer;

  AppUpdateService get _service => widget.coordinator.service;

  @override
  void initState() {
    super.initState();
    _localVersion = widget.localVersion;
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshDownload(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      if (_localVersion.isEmpty) {
        final info = await PackageInfo.fromPlatform();
        _localVersion = '${info.version}+${info.buildNumber}';
      }
      final candidates = await _service.findCandidates(_localVersion);
      if (!mounted) {
        return;
      }
      setState(() => _candidates = candidates);
      await _refreshDownload();
    } on AppUpdateException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '检查更新失败，请检查网络后重试');
      }
    }
  }

  Future<void> _refreshDownload() async {
    try {
      final snapshot = await _service.refreshActiveTask();
      if (!mounted) {
        return;
      }
      setState(() {
        _task = _service.activeTask;
        _snapshot = snapshot;
      });
    } on AppUpdateException catch (error) {
      if (mounted) {
        setState(() {
          _task = _service.activeTask;
          _snapshot = null;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _download(LatestDataModel release) async {
    if (await widget.coordinator.startDownload(context, release)) {
      await _refreshDownload();
    }
  }

  Future<void> _cancelDownload() async {
    await _service.cancelActiveTask();
    if (mounted) {
      setState(() {
        _task = null;
        _snapshot = null;
      });
    }
  }

  Future<void> _retryDownload() async {
    if (await widget.coordinator.retryActiveTask(context)) {
      await _refreshDownload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('检查更新'),
      content: SizedBox(width: 560, child: _buildContent(context)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_candidates == null && _error == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_candidates == null) {
      return SizedBox(
        height: 180,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前版本：$_localVersion'),
          const SizedBox(height: 12),
          _releaseCard(
            title: '正式版',
            release: _candidates!.stable,
            icon: Icons.verified_outlined,
          ),
          const SizedBox(height: 8),
          _releaseCard(
            title: '测试版',
            release: _candidates!.prerelease,
            icon: Icons.science_outlined,
            prerelease: true,
          ),
          if (_task != null) ...[const SizedBox(height: 12), _downloadCard()],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _releaseCard({
    required String title,
    required LatestDataModel? release,
    required IconData icon,
    bool prerelease = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (prerelease) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('不稳定版本'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (release == null)
              const Text('暂无可升级版本')
            else ...[
              Text(
                release.tagName ?? '',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (release.createdAt?.isNotEmpty == true)
                Text('发布时间：${release.createdAt!.split('T').first}'),
              if (release.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  release.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _download(release),
                  child: Text(prerelease ? '下载测试版' : '下载正式版'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _downloadCard() {
    final status = _snapshot?.status;
    final progress = _snapshot?.progress;
    final statusText = switch (status) {
      UpdateDownloadStatus.pending => '等待系统下载',
      UpdateDownloadStatus.running => '正在下载',
      UpdateDownloadStatus.paused => '下载已暂停，等待网络恢复',
      UpdateDownloadStatus.successful => _task!.verified ? '校验完成' : '正在校验',
      UpdateDownloadStatus.failed => '下载失败${_reasonSuffix()}',
      UpdateDownloadStatus.missing => '系统下载任务已丢失',
      null => '正在读取下载状态',
    };
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '下载任务 ${_task!.versionTag}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(statusText),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(_progressText()),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  if (status == UpdateDownloadStatus.failed ||
                      status == UpdateDownloadStatus.missing)
                    TextButton(
                      onPressed: _retryDownload,
                      child: const Text('重试'),
                    ),
                  if (status != UpdateDownloadStatus.successful)
                    TextButton(
                      onPressed: _cancelDownload,
                      child: const Text('取消下载'),
                    ),
                  if (status == UpdateDownloadStatus.successful &&
                      _task!.verified)
                    FilledButton(
                      onPressed: () =>
                          widget.coordinator.installActiveTask(context),
                      child: const Text('立即安装'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _reasonSuffix() {
    final reason = _snapshot?.reason;
    return reason == null || reason.isEmpty ? '' : '（$reason）';
  }

  String _progressText() {
    final downloaded = _snapshot?.downloadedBytes ?? 0;
    final total = _snapshot?.totalBytes ?? 0;
    if (total <= 0) {
      return '${_formatBytes(downloaded)} / 未知大小';
    }
    return '${_formatBytes(downloaded)} / ${_formatBytes(total)}';
  }

  String _formatBytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '$value B';
  }
}

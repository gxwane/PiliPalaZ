import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/my_dialog.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/models/video/play/quality.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/download/controller.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';

/// 视频详情页离线缓存面板
class DownloadSheet extends StatefulWidget {
  const DownloadSheet({
    super.key,
    required this.videoDetail,
    this.playUrlData,
    this.downloadService,
    this.storageManager,
  });

  final VideoDetailData videoDetail;
  final PlayUrlModel? playUrlData;
  final DownloadService? downloadService;
  final DownloadStorageManager? storageManager;

  /// 前置权益与试看拦截校验。
  ///
  /// 返回 `true` 表示内容受限，不支持缓存；`false` 表示可以缓存。
  static bool isRestricted(PlayUrlModel? playUrlData) {
    if (playUrlData == null) return false;
    if (playUrlData.isDrm) return true;
    if (playUrlData.isPreview) return true;
    final int? err = playUrlData.errorCode;
    if (err == -10403 || err == 10403) return true;
    return false;
  }

  /// 快捷唤起缓存弹窗方法。
  static void show(
    BuildContext context, {
    required VideoDetailData videoDetail,
    PlayUrlModel? playUrlData,
    DownloadService? downloadService,
    DownloadStorageManager? storageManager,
  }) {
    if (isRestricted(playUrlData)) {
      SmartDialog.showToast('当前内容受版权保护或为试看片段，不支持离线缓存');
      return;
    }

    MyDialog.showCorner(
      context,
      DownloadSheet(
        videoDetail: videoDetail,
        playUrlData: playUrlData,
        downloadService: downloadService,
        storageManager: storageManager,
      ),
    );
  }

  @override
  State<DownloadSheet> createState() => DownloadSheetState();
}

class DownloadSheetState extends State<DownloadSheet> {
  late final Set<int> selectedCids;
  late int selectedQualityCode;
  late String selectedQualityDesc;
  late final List<int> availableQualityCodes;

  final Map<int, DownloadTask> _tasksMap = <int, DownloadTask>{};
  StreamSubscription<DownloadTask>? _subscription;

  DownloadService? get _service {
    if (widget.downloadService != null) return widget.downloadService;
    if (DownloadService.isInitialized) return DownloadService.instance;
    return null;
  }

  DownloadStorageManager get _storage =>
      widget.storageManager ?? DownloadStorageManager();

  List<Part> get _pages => widget.videoDetail.pages ?? <Part>[];

  @override
  void initState() {
    super.initState();
    selectedCids = <int>{};

    // 预检本地已有任务 (BAC-16)
    final DownloadService? service = _service;
    if (service != null) {
      final String? bvid = widget.videoDetail.bvid;
      final List<DownloadTask> all = service.getAllTasks();
      for (final DownloadTask t in all) {
        if (t.bvid == bvid) {
          _tasksMap[t.cid] = t;
        }
      }
      _subscription = service.taskUpdates.listen((DownloadTask task) {
        if (task.bvid == bvid && mounted) {
          setState(() {
            _tasksMap[task.cid] = task;
          });
        }
      });
    }

    // 智能默认勾选：首个未完成的分P (BAC-18)
    if (_pages.isNotEmpty) {
      int? firstUncompletedCid;
      for (final Part p in _pages) {
        final int c = p.cid ?? 0;
        if (c > 0 && _tasksMap[c]?.status != DownloadTaskStatus.completed) {
          firstUncompletedCid = c;
          break;
        }
      }
      if (firstUncompletedCid != null) {
        selectedCids.add(firstUncompletedCid);
      }
    } else {
      final int cid = widget.videoDetail.cid ?? 0;
      if (cid > 0 && _tasksMap[cid]?.status != DownloadTaskStatus.completed) {
        selectedCids.add(cid);
      }
    }

    // 解析可用清晰度列表
    final acceptQ = widget.playUrlData?.acceptQuality;
    if (acceptQ != null && acceptQ.isNotEmpty) {
      availableQualityCodes = List<int>.from(acceptQ);
    } else {
      availableQualityCodes = <int>[80, 64, 32, 16]; // 1080P, 720P, 480P, 360P
    }

    // 默认选择 1080P (80) 或首个可用清晰度
    selectedQualityCode = availableQualityCodes.contains(80)
        ? 80
        : availableQualityCodes.first;
    selectedQualityDesc = _getQualityDesc(selectedQualityCode);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _getQualityDesc(int code) {
    final VideoQuality? vq = VideoQualityCode.fromCode(code);
    return vq?.description ?? '${code}P';
  }

  void toggleCid(int cid) {
    setState(() {
      if (selectedCids.contains(cid)) {
        selectedCids.remove(cid);
      } else {
        selectedCids.add(cid);
      }
    });
  }

  List<int> get _allAvailableCids {
    if (_pages.isNotEmpty) {
      return _pages
          .map((Part p) => p.cid ?? 0)
          .where((int cid) => cid > 0)
          .toList();
    }
    final int? cid = widget.videoDetail.cid;
    return cid != null && cid > 0 ? <int>[cid] : <int>[];
  }

  List<int> get _uncachedCids {
    return _allAvailableCids
        .where(
          (int cid) => _tasksMap[cid]?.status != DownloadTaskStatus.completed,
        )
        .toList();
  }

  bool get _hasCompletedParts {
    return _allAvailableCids.any(
      (int cid) => _tasksMap[cid]?.status == DownloadTaskStatus.completed,
    );
  }

  String get _selectAllButtonText {
    final int total = _allAvailableCids.length;
    if (total <= 1) return '全选';

    final List<int> uncached = _uncachedCids;
    final bool allSelected = selectedCids.length == total;
    if (allSelected) return '取消全选';

    if (_hasCompletedParts && uncached.isNotEmpty) {
      final bool uncachedAllSelected =
          uncached.every((int cid) => selectedCids.contains(cid)) &&
          selectedCids.length == uncached.length;
      if (uncachedAllSelected) return '全选所有';
      return '全选未缓存';
    }
    return '全选';
  }

  void toggleSelectAll() {
    setState(() {
      final int total = _allAvailableCids.length;
      final List<int> uncached = _uncachedCids;

      if (selectedCids.length == total) {
        selectedCids.clear();
      } else if (_hasCompletedParts && uncached.isNotEmpty) {
        final bool uncachedAllSelected =
            uncached.every((int cid) => selectedCids.contains(cid)) &&
            selectedCids.length == uncached.length;
        if (!uncachedAllSelected) {
          selectedCids
            ..clear()
            ..addAll(uncached);
        } else {
          selectedCids.addAll(_allAvailableCids);
        }
      } else {
        selectedCids.addAll(_allAvailableCids);
      }
    });
  }

  Future<void> submitDownload() async {
    if (selectedCids.isEmpty) {
      SmartDialog.showToast('请至少选择一个分P进行缓存');
      return;
    }

    final DownloadService? service = _service;
    if (service == null) {
      SmartDialog.showToast('下载服务未就绪');
      return;
    }

    // 状态四分法前置分类 (BAC-17)
    final List<int> toStartCids = <int>[];
    final List<DownloadTask> sameQualitySkipped = <DownloadTask>[];
    final List<DownloadTask> differentQualityTasks = <DownloadTask>[];

    for (final int cid in selectedCids) {
      final DownloadTask? existing = _tasksMap[cid];
      if (existing == null) {
        toStartCids.add(cid);
      } else if (existing.videoQuality == selectedQualityCode) {
        if (existing.status == DownloadTaskStatus.completed ||
            existing.status == DownloadTaskStatus.downloading ||
            existing.status == DownloadTaskStatus.pending) {
          sameQualitySkipped.add(existing);
        } else {
          // paused / failed 相同规格允许恢复
          toStartCids.add(cid);
        }
      } else {
        // 画质规格冲突，挂起等待二次确认
        differentQualityTasks.add(existing);
      }
    }

    // 批量不同画质替换确认 (BAC-17)
    if (differentQualityTasks.isNotEmpty) {
      final bool? confirm = await _showQualityReplacementDialog(
        differentQualityTasks,
        selectedQualityDesc,
      );
      if (confirm != true) {
        // 用户取消，操作终止，保留面板
        return;
      }
      // 确认替换：清理旧规格文件及内存索引后加入待启动集合
      for (final DownloadTask oldTask in differentQualityTasks) {
        await service.cancelTask(oldTask.id, deleteFiles: true);
        _tasksMap.remove(oldTask.cid);
        toStartCids.add(oldTask.cid);
      }
    }

    // 检查是否有实际任务需要启动
    if (toStartCids.isEmpty) {
      if (sameQualitySkipped.isNotEmpty) {
        SmartDialog.showToast('所选分 P 已全部在本地缓存，无需重复下载');
      }
      return;
    }

    // 仅针对实际待启动的集合计算容量预估 (BAC-17)
    final int estimatedBytes = toStartCids.length * 150 * 1024 * 1024;
    final bool hasSpace = await _storage.hasEnoughSpace(estimatedBytes);
    if (!hasSpace) {
      SmartDialog.showToast('存储空间不足 (低于安全水位 200MB)，无法开始下载');
      return;
    }

    final String bvid = widget.videoDetail.bvid ?? '';
    final int? aid = widget.videoDetail.aid;
    final String title = widget.videoDetail.title ?? '';
    final String cover = widget.videoDetail.pic ?? '';
    final String ownerName = widget.videoDetail.owner?.name ?? '';

    for (final int cid in toStartCids) {
      Part? part;
      if (_pages.isNotEmpty) {
        final matches = _pages.where((Part p) => p.cid == cid);
        if (matches.isNotEmpty) part = matches.first;
      }

      final String partTitle =
          part?.pagePart ?? (part != null ? 'P${part.page}' : '');
      final int duration = part?.duration ?? widget.videoDetail.duration ?? 0;

      final DownloadTask task = DownloadTask.create(
        bvid: bvid,
        cid: cid,
        aid: aid,
        title: title,
        partTitle: partTitle,
        cover: cover,
        ownerName: ownerName,
        duration: duration,
        videoQuality: selectedQualityCode,
        videoQualityDesc: selectedQualityDesc,
        videoCodec: 'avc1',
        audioQuality: 30280,
      );

      await service.startTask(task);
      _tasksMap[cid] = task;
    }

    // 精确反馈
    if (sameQualitySkipped.isNotEmpty) {
      SmartDialog.showToast(
        '已加入 ${toStartCids.length} 项，已自动跳过 ${sameQualitySkipped.length} 项已缓存分P',
      );
    } else {
      SmartDialog.showToast('已加入缓存队列 (${toStartCids.length} 项)');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _showQualityReplacementDialog(
    List<DownloadTask> tasks,
    String newQualityDesc,
  ) {
    final String contentText;
    if (tasks.length == 1) {
      final DownloadTask t = tasks.first;
      final String partName = t.partTitle.isNotEmpty ? t.partTitle : '当前视频';
      contentText =
          '检测到「$partName」已缓存「${t.videoQualityDesc}」，是否替换重新下载为「$newQualityDesc」？\n\n（确认后将清除本地旧画质文件）';
    } else {
      final StringBuffer buffer = StringBuffer(
        '检测到以下 ${tasks.length} 个分P已缓存其他画质：\n',
      );
      for (final DownloadTask t in tasks.take(5)) {
        final String partName = t.partTitle.isNotEmpty
            ? t.partTitle
            : 'P${t.cid}';
        buffer.writeln('• $partName (已缓存 ${t.videoQualityDesc})');
      }
      if (tasks.length > 5) {
        buffer.writeln('...等共 ${tasks.length} 项');
      }
      buffer.write('\n是否统一替换重新下载为「$newQualityDesc」？\n（确认后将清除本地旧画质文件）');
      contentText = buffer.toString();
    }

    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('替换下载确认'),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('替换下载'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final double width = isLandscape
        ? min(500.0, MediaQuery.of(context).size.width * 0.6)
        : MediaQuery.of(context).size.width;
    final double maxHeight = isLandscape
        ? MediaQuery.of(context).size.height * 0.85
        : MediaQuery.of(context).size.height * 0.65;

    return Container(
      width: width,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: StyleString.mdRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶栏
          _buildHeader(theme),
          const Divider(height: 1),
          // 清晰度选择
          _buildQualitySelector(theme),
          const Divider(height: 1),
          // 分 P 列表
          Expanded(child: _buildPartList(theme)),
          const Divider(height: 1),
          // 底栏提交
          _buildBottomAction(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '离线缓存',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              if (_allAvailableCids.length > 1)
                Semantics(
                  button: true,
                  label: _selectAllButtonText,
                  child: TextButton(
                    onPressed: toggleSelectAll,
                    child: Text(_selectAllButtonText),
                  ),
                ),
              Semantics(
                button: true,
                label: '关闭',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '清晰度: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableQualityCodes.map((int code) {
                  final bool isSelected = code == selectedQualityCode;
                  final String desc = _getQualityDesc(code);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: desc,
                      child: ChoiceChip(
                        label: Text(desc),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() {
                              selectedQualityCode = code;
                              selectedQualityDesc = desc;
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(int? duration, DownloadTask? task, ThemeData theme) {
    final String? durationStr = duration != null
        ? DownloadPageController.formatDuration(duration)
        : null;
    final Widget? badge = _buildTaskStatusBadge(task, theme);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (durationStr != null)
            Text(
              durationStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (badge != null) badge,
        ],
      ),
    );
  }

  Widget? _buildTaskStatusBadge(DownloadTask? task, ThemeData theme) {
    if (task == null) return null;

    final String label;
    final Color bgColor;
    final Color fgColor;

    switch (task.status) {
      case DownloadTaskStatus.completed:
        label = '已缓存 · ${task.videoQualityDesc}';
        bgColor = theme.colorScheme.primaryContainer;
        fgColor = theme.colorScheme.onPrimaryContainer;
        break;
      case DownloadTaskStatus.downloading:
        label = '下载中';
        bgColor = theme.colorScheme.tertiaryContainer;
        fgColor = theme.colorScheme.onTertiaryContainer;
        break;
      case DownloadTaskStatus.pending:
        label = '等待中';
        bgColor = theme.colorScheme.secondaryContainer;
        fgColor = theme.colorScheme.onSecondaryContainer;
        break;
      case DownloadTaskStatus.paused:
        label = '已暂停';
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
        break;
      case DownloadTaskStatus.failed:
        label = '下载失败';
        bgColor = theme.colorScheme.errorContainer;
        fgColor = theme.colorScheme.onErrorContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: fgColor,
        ),
      ),
    );
  }

  Widget _buildPartList(ThemeData theme) {
    if (_pages.isEmpty) {
      // 单视频
      final int cid = widget.videoDetail.cid ?? 0;
      final bool isSelected = selectedCids.contains(cid);
      final DownloadTask? task = _tasksMap[cid];
      final String title = widget.videoDetail.title ?? '完整视频';
      final int? duration = widget.videoDetail.duration;

      final String durationText = duration != null
          ? DownloadPageController.formatDuration(duration)
          : '';
      final String semanticsLabel = durationText.isNotEmpty
          ? '$title，时长 $durationText'
          : title;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            button: true,
            selected: isSelected,
            label: semanticsLabel,
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (_) => toggleCid(cid),
              title: Text(title),
              subtitle: _buildSubtitle(duration, task, theme),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _pages.length,
      itemBuilder: (BuildContext context, int index) {
        final Part part = _pages[index];
        final int cid = part.cid ?? 0;
        final bool isSelected = selectedCids.contains(cid);
        final DownloadTask? task = _tasksMap[cid];
        final String title = part.pagePart ?? 'P${part.page}';
        final int? duration = part.duration;

        final String durationText = duration != null
            ? DownloadPageController.formatDuration(duration)
            : '';
        final String semanticsLabel =
            '第 ${part.page ?? index + 1} 集 $title${durationText.isNotEmpty ? '，时长 $durationText' : ''}';

        return Semantics(
          button: true,
          selected: isSelected,
          label: semanticsLabel,
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (_) => toggleCid(cid),
            title: Text(
              'P${part.page ?? index + 1} $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: _buildSubtitle(duration, task, theme),
          ),
        );
      },
    );
  }

  Widget _buildBottomAction(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '已选 ${selectedCids.length} 项',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Semantics(
            button: true,
            label: '开始缓存',
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
              onPressed: selectedCids.isEmpty ? null : submitDownload,
              child: Text('开始缓存 (${selectedCids.length})'),
            ),
          ),
        ],
      ),
    );
  }
}

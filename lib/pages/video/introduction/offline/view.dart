import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/pages/download/controller.dart';
import 'package:pilipalaz/pages/video/controller.dart';
import 'package:pilipalaz/services/download/download_service.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';

/// 离线视频信息面板（纯本地，无在线社交功能）。
///
/// 物理隔离：不实例化 [VideoIntroController]，不发起任何网络请求。
/// 包含：标题、UP 主名称、离线资产规格卡、分 P 选集（同 bvid 多 P 时显示）、
/// 「查看在线视频」跳转入口。
class OfflineVideoIntroPanel extends StatelessWidget {
  const OfflineVideoIntroPanel({required this.heroTag, super.key});

  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final VideoDetailController ctr = Get.find<VideoDetailController>(
      tag: heroTag,
    );
    return Obx(() {
      final DownloadTask? task = ctr.offlineTask;
      final int currentCid = ctr.cid.value;

      if (task == null) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      return SliverList(
        delegate: SliverChildListDelegate([
          _OfflineIntroPanelBody(
            task: task,
            currentCid: currentCid,
            heroTag: heroTag,
          ),
        ]),
      );
    });
  }
}

class _OfflineIntroPanelBody extends StatefulWidget {
  const _OfflineIntroPanelBody({
    required this.task,
    required this.currentCid,
    required this.heroTag,
  });

  final DownloadTask task;
  final int currentCid;
  final String heroTag;

  @override
  State<_OfflineIntroPanelBody> createState() => _OfflineIntroPanelBodyState();
}

class _OfflineIntroPanelBodyState extends State<_OfflineIntroPanelBody> {
  List<DownloadTask> _siblingParts = const [];
  String _videoSize = '计算中...';
  String _audioSize = '计算中...';
  bool _danmakuExists = false;

  @override
  void initState() {
    super.initState();
    _loadSiblingParts();
    _loadAssetSpecs();
  }

  @override
  void didUpdateWidget(covariant _OfflineIntroPanelBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.bvid != widget.task.bvid ||
        oldWidget.task.cid != widget.task.cid) {
      _loadSiblingParts();
      _loadAssetSpecs();
    }
  }

  void _loadSiblingParts() {
    if (!DownloadService.isInitialized) return;
    final List<DownloadTask> all = DownloadService.instance.getAllTasks();
    final List<DownloadTask> siblings =
        all
            .where(
              (t) =>
                  t.bvid == widget.task.bvid &&
                  t.status == DownloadTaskStatus.completed,
            )
            .toList()
          ..sort((a, b) => a.cid.compareTo(b.cid));
    if (mounted) setState(() => _siblingParts = siblings);
  }

  Future<void> _loadAssetSpecs() async {
    final storage = DownloadStorageManager();
    String vSize = '未知';
    String aSize = '未知';
    bool dExists = false;

    if (widget.task.videoRelativePath != null) {
      try {
        final path = await storage.absolutePath(widget.task.videoRelativePath!);
        final f = File(path);
        if (await f.exists()) {
          vSize = DownloadPageController.formatBytes(await f.length());
        }
      } catch (_) {}
    }

    if (widget.task.audioRelativePath != null) {
      try {
        final path = await storage.absolutePath(widget.task.audioRelativePath!);
        final f = File(path);
        if (await f.exists()) {
          aSize = DownloadPageController.formatBytes(await f.length());
        }
      } catch (_) {}
    }

    if (widget.task.danmakuRelativePath != null) {
      try {
        final path = await storage.absolutePath(
          widget.task.danmakuRelativePath!,
        );
        dExists = await File(path).exists();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _videoSize = vSize;
        _audioSize = aSize;
        _danmakuExists = dExists;
      });
    }
  }

  String _formatDuration(int seconds) =>
      DownloadPageController.formatDuration(seconds);

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final DownloadTask task = widget.task;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题 ────────────────────────────────────────────────
          Text(
            task.title,
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.partTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.partTitle,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.outline,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          // ── UP 主 & 时长 ─────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: t.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  task.ownerName.isNotEmpty ? task.ownerName : '未知 UP 主',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.access_time_outlined,
                size: 14,
                color: t.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDuration(task.duration),
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── 离线资产规格卡 ──────────────────────────────────────
          _OfflineAssetCard(
            task: task,
            videoSize: _videoSize,
            audioSize: _audioSize,
          ),
          // ── 弹幕状态 ────────────────────────────────────────────
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                _danmakuExists
                    ? Icons.comment_outlined
                    : Icons.comments_disabled_outlined,
                size: 14,
                color: t.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                _danmakuExists ? '离线弹幕已缓存' : '无离线弹幕',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.outline,
                ),
              ),
            ],
          ),
          // ── 多 P 选集 ───────────────────────────────────────────
          if (_siblingParts.length > 1) ...[
            const SizedBox(height: 16),
            Text('选集', style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            _OfflinePartSelector(
              parts: _siblingParts,
              currentCid: widget.currentCid,
              heroTag: widget.heroTag,
            ),
          ],
          const SizedBox(height: 16),
          // ── 查看在线视频入口 ─────────────────────────────────────
          _OnlineEntryButton(task: task, heroTag: widget.heroTag),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── 子组件：离线资产规格卡 ─────────────────────────────────────────────────

class _OfflineAssetCard extends StatelessWidget {
  const _OfflineAssetCard({
    required this.task,
    required this.videoSize,
    required this.audioSize,
  });

  final DownloadTask task;
  final String videoSize;
  final String audioSize;

  String get _audioQualityLabel {
    const Map<int, String> map = {30280: '192K', 30232: '132K', 30216: '64K'};
    return map[task.audioQuality] ?? '未知';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SpecRow(label: '画质', value: task.videoQualityDesc),
          _SpecRow(label: '编码', value: task.videoCodec),
          _SpecRow(label: '音质', value: _audioQualityLabel),
          _SpecRow(label: '视频大小', value: videoSize),
          _SpecRow(label: '音频大小', value: audioSize),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: t.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 子组件：多 P 选集 ───────────────────────────────────────────────────────

class _OfflinePartSelector extends StatelessWidget {
  const _OfflinePartSelector({
    required this.parts,
    required this.currentCid,
    required this.heroTag,
  });

  final List<DownloadTask> parts;
  final int currentCid;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: parts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, int i) {
          final DownloadTask part = parts[i];
          final bool isCurrent = part.cid == currentCid;
          return _PartChip(part: part, isCurrent: isCurrent, heroTag: heroTag);
        },
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  const _PartChip({
    required this.part,
    required this.isCurrent,
    required this.heroTag,
  });

  final DownloadTask part;
  final bool isCurrent;
  final String heroTag;

  void _switchPart(BuildContext context) {
    try {
      final ctr = Get.find<VideoDetailController>(tag: heroTag);
      ctr.switchOfflineTask(part);
    } catch (_) {
      // 兜底路由跳转
      Get.offNamed(
        '/video',
        arguments: {
          'heroTag':
              'offline_${part.cid}_${DateTime.now().millisecondsSinceEpoch}',
          'offlineTask': part,
          'isOffline': true,
          'pic': part.cover,
        },
        parameters: {'bvid': part.bvid, 'cid': part.cid.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final String label = part.partTitle.isNotEmpty
        ? part.partTitle
        : 'P${part.cid}';

    return GestureDetector(
      onTap: isCurrent ? null : () => _switchPart(context),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrent
              ? t.colorScheme.primaryContainer
              : t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: isCurrent
              ? Border.all(color: t.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: t.textTheme.bodySmall?.copyWith(
            color: isCurrent
                ? t.colorScheme.onPrimaryContainer
                : t.colorScheme.onSurface,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── 子组件：查看在线视频按钮 ──────────────────────────────────────────────

class _OnlineEntryButton extends StatelessWidget {
  const _OnlineEntryButton({required this.task, required this.heroTag});

  final DownloadTask task;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('查看在线视频'),
        onPressed: () {
          Duration defaultST = Duration.zero;
          try {
            final ctr = Get.find<VideoDetailController>(tag: heroTag);
            defaultST = ctr.plPlayerController?.position.value ?? Duration.zero;
          } catch (_) {}
          final String saltedTag =
              'online_${task.cid}_${DateTime.now().millisecondsSinceEpoch}';
          Get.toNamed(
            '/video',
            arguments: {
              'heroTag': saltedTag,
              'pic': task.cover,
              'videoType': null,
              'defaultST': defaultST,
            },
            parameters: {'bvid': task.bvid, 'cid': task.cid.toString()},
          );
        },
      ),
    );
  }
}

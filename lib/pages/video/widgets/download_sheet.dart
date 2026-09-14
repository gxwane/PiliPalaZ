import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/my_dialog.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/models/video/play/quality.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
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

  DownloadService get _service =>
      widget.downloadService ?? DownloadService.instance;

  DownloadStorageManager get _storage =>
      widget.storageManager ?? DownloadStorageManager();

  List<Part> get _pages => widget.videoDetail.pages ?? <Part>[];

  @override
  void initState() {
    super.initState();
    selectedCids = <int>{};

    // 默认全选或选当前首个
    if (_pages.isNotEmpty) {
      selectedCids.add(_pages.first.cid ?? widget.videoDetail.cid ?? 0);
    } else if (widget.videoDetail.cid != null) {
      selectedCids.add(widget.videoDetail.cid!);
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

  void toggleSelectAll() {
    setState(() {
      if (selectedCids.length == _allAvailableCids.length) {
        selectedCids.clear();
      } else {
        selectedCids.addAll(_allAvailableCids);
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

  Future<void> submitDownload() async {
    if (selectedCids.isEmpty) {
      SmartDialog.showToast('请至少选择一个分P进行缓存');
      return;
    }

    // 预估大小：每集按约 150MB 估算
    final int estimatedBytes = selectedCids.length * 150 * 1024 * 1024;
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

    for (final int cid in selectedCids) {
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

      await _service.startTask(task);
    }

    SmartDialog.showToast('已加入缓存队列 (${selectedCids.length} 项)');
    if (mounted) {
      Navigator.of(context).pop();
    }
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
    final bool allSelected =
        selectedCids.length == _allAvailableCids.length &&
        _allAvailableCids.isNotEmpty;

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
                  label: allSelected ? '取消全选' : '全选',
                  child: TextButton(
                    onPressed: toggleSelectAll,
                    child: Text(allSelected ? '取消全选' : '全选'),
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

  Widget _buildPartList(ThemeData theme) {
    if (_pages.isEmpty) {
      // 单视频
      final int cid = widget.videoDetail.cid ?? 0;
      final bool isSelected = selectedCids.contains(cid);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CheckboxListTile(
            value: isSelected,
            onChanged: (_) => toggleCid(cid),
            title: Text(widget.videoDetail.title ?? '完整视频'),
            subtitle: widget.videoDetail.duration != null
                ? Text('${widget.videoDetail.duration}秒')
                : null,
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
        final String title = part.pagePart ?? 'P${part.page}';

        return Semantics(
          button: true,
          selected: isSelected,
          label: '第 ${part.page ?? index + 1} 集 $title',
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (_) => toggleCid(cid),
            title: Text(
              'P${part.page ?? index + 1} $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: part.duration != null ? Text('${part.duration}秒') : null,
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

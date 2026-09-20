import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/models/diagnostics/playback_snapshot.dart';
import 'package:pilipalaz/pages/video/controller.dart';

/// 播放信息与统计排障对话框
class PlayerInfoDialog extends StatefulWidget {
  final VideoDetailController videoDetailCtr;

  const PlayerInfoDialog({super.key, required this.videoDetailCtr});

  @override
  State<PlayerInfoDialog> createState() => _PlayerInfoDialogState();
}

class _PlayerInfoDialogState extends State<PlayerInfoDialog> {
  late PlaybackSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _snapshot = widget.videoDetailCtr.generatePlaybackSnapshot();
    });
  }

  void _copyRow(String label, String value) {
    Clipboard.setData(ClipboardData(text: '$label: $value'));
    SmartDialog.showToast('已复制 $label');
  }

  void _copyAllMarkdown() {
    Clipboard.setData(ClipboardData(text: _snapshot.toMarkdown()));
    SmartDialog.showToast('已复制完整播放信息到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size screenSize = MediaQuery.sizeOf(context);
    final double maxDialogHeight = min(560.0, screenSize.height * 0.85);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Icon(Icons.analytics_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '播放信息',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 20),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: maxDialogHeight,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                title: '内核与管线',
                colorScheme: colorScheme,
                items: [
                  _InfoItem('播放内核', _snapshot.engineName),
                  _InfoItem('渲染后端', _snapshot.rendererType),
                  _InfoItem('硬件解码', _snapshot.hwdec),
                  _InfoItem('音频输出', _snapshot.audioOutput),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: '视频流规格',
                colorScheme: colorScheme,
                items: [
                  _InfoItem('当前画质', _snapshot.videoQuality),
                  _InfoItem('画面尺寸', _snapshot.resolution),
                  _InfoItem('视频编码', _snapshot.videoCodec),
                  _InfoItem('视频帧率', _snapshot.frameRate),
                  _InfoItem('视频码率', _snapshot.videoBitrate),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: '音频流规格',
                colorScheme: colorScheme,
                items: [
                  _InfoItem('当前音质', _snapshot.audioQuality),
                  _InfoItem('音频编码', _snapshot.audioCodec),
                  _InfoItem('音频码率', _snapshot.audioBitrate),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: '播放与缓冲',
                colorScheme: colorScheme,
                items: [
                  _InfoItem(
                    '播放进度',
                    '${_snapshot.formattedPosition} / ${_snapshot.formattedDuration}',
                  ),
                  _InfoItem(
                    '缓冲进度',
                    '${_snapshot.formattedBuffered} (${_snapshot.bufferPercent}%)',
                  ),
                  _InfoItem(
                    '播放状态',
                    '${_snapshot.playbackState} (${_snapshot.playbackSpeed.toStringAsFixed(1)}x)',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: '网络与元数据',
                colorScheme: colorScheme,
                items: [
                  _InfoItem('视频来源', _snapshot.sourceType),
                  _InfoItem('BVID', _snapshot.bvid),
                  _InfoItem('CID', '${_snapshot.cid}'),
                  _InfoItem('CDN 节点', _snapshot.cdnHost),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: _copyAllMarkdown,
          icon: const Icon(Icons.copy, size: 15),
          label: const Text('复制全部'),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required ColorScheme colorScheme,
    required List<_InfoItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 12,
                      endIndent: 12,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  InkWell(
                    onTap: () => _copyRow(items[i].label, items[i].value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].label,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              items[i].value,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  const _InfoItem(this.label, this.value);
}

/// 显示播放信息对话框快捷入口
Future<void> showPlayerInfoDialog(
  BuildContext context,
  VideoDetailController videoDetailCtr,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) =>
        PlayerInfoDialog(videoDetailCtr: videoDetailCtr),
  );
}

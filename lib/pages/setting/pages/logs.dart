import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_record.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_report_formatter.dart';
import 'package:pilipalaz/services/diagnostics/local_diagnostics.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, this.diagnostics});

  final LocalDiagnostics? diagnostics;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late final LocalDiagnostics _diagnostics;
  List<DiagnosticRecord> _records = const <DiagnosticRecord>[];
  int _storageBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _diagnostics = widget.diagnostics ?? LocalDiagnostics.instance;
    _load();
  }

  Future<void> _load() async {
    final records = await _diagnostics.readFailures();
    final storageBytes = await _diagnostics.storageBytes();
    if (!mounted) return;
    setState(() {
      _records = records.reversed.toList(growable: false);
      _storageBytes = storageBytes;
      _loading = false;
    });
  }

  Future<void> _preview(DiagnosticRecord record) async {
    var includeDeviceInfo = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final report = formatDiagnosticReport(
            record,
            includeDeviceInfo: includeDeviceInfo,
          );
          return AlertDialog(
            title: const Text('审阅诊断报告'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: includeDeviceInfo,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('包含设备兼容信息'),
                    subtitle: const Text('厂商、型号、系统版本和 ABI'),
                    onChanged: (value) => setDialogState(
                      () => includeDeviceInfo = value ?? false,
                    ),
                  ),
                  const Divider(),
                  Flexible(
                    child: SingleChildScrollView(child: SelectableText(report)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: report));
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(const SnackBar(content: Text('诊断报告已复制到剪贴板')));
                },
                child: const Text('复制'),
              ),
              TextButton(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: report, subject: 'PiliPalaZ 本地诊断'),
                ),
                child: const Text('系统分享'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本地诊断'),
        content: const Text('此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _diagnostics.clear();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('本地诊断已清空')));
  }

  Future<void> _feedback() async {
    await launchUrl(
      Uri.parse(ProjectLinks.issues),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text('本地诊断', style: Theme.of(context).textTheme.titleMedium),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'feedback':
                  _feedback();
                case 'clear':
                  _clear();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'feedback', child: Text('前往 GitHub 反馈')),
              PopupMenuItem(value: 'clear', child: Text('清空本地诊断')),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.privacy_tip_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _diagnostics.enabled ? '本地记录已开启' : '本地记录已关闭',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '只在故障发生时保存在本设备，PiliPalaZ 不会自动上传。'
                            '记录最多保留 7 天，合计不超过 1 MiB。',
                          ),
                          const SizedBox(height: 8),
                          Text('当前占用：${_formatBytes(_storageBytes)}'),
                        ],
                      ),
                    ),
                  ),
                  if (_records.isEmpty)
                    const SizedBox(
                      height: 360,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 72),
                          SizedBox(height: 16),
                          Text('没有故障记录'),
                        ],
                      ),
                    )
                  else
                    ..._records.map(
                      (record) => Card(
                        child: ExpansionTile(
                          title: Text(record.kind.label),
                          subtitle: Text(record.timestamp.toLocal().toString()),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            12,
                          ),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(record.message),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonalIcon(
                                onPressed: () => _preview(record),
                                icon: const Icon(Icons.preview_outlined),
                                label: const Text('生成反馈内容'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  return '${(bytes / 1024).toStringAsFixed(1)} KiB';
}

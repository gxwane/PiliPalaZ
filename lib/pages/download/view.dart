import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/pages/download/controller.dart';
import 'package:pilipalaz/pages/download/widgets/cache_disk_indicator.dart';
import 'package:pilipalaz/utils/utils.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  late final DownloadPageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(DownloadPageController());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('离线缓存'),
        bottom: TabBar(
          controller: _controller.tabController,
          tabs: [
            Obx(() => Tab(text: '已完成 (${_controller.completedTasks.length})')),
            Obx(() => Tab(text: '下载中 (${_controller.activeTasks.length})')),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String val) {
              if (val == 'pauseAll') {
                _controller.pauseAll();
              } else if (val == 'resumeAll') {
                _controller.resumeAll();
              } else if (val == 'refresh') {
                _controller.refreshTasks();
                _controller.refreshDiskSpace();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'pauseAll', child: Text('全部暂停')),
              const PopupMenuItem(value: 'resumeAll', child: Text('全部继续')),
              const PopupMenuItem(value: 'refresh', child: Text('刷新')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _controller.tabController,
        children: [_buildCompletedList(theme), _buildActiveList(theme)],
      ),
      bottomNavigationBar: Obx(
        () => CacheDiskIndicator(
          usedBytes: _controller.usedDiskBytes.value,
          availableBytes: _controller.availableDiskBytes.value,
        ),
      ),
    );
  }

  Widget _buildCompletedList(ThemeData theme) {
    return Obx(() {
      final tasks = _controller.completedTasks;
      if (tasks.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_download_off_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无已完成的离线缓存',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: tasks.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final task = tasks[index];
          return _buildCompletedCard(theme, task);
        },
      );
    });
  }

  Widget _buildCompletedCard(ThemeData theme, DownloadTask task) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          // 离线播放导航
          Get.toNamed(
            '/video',
            arguments: {
              'heroTag': Utils.makeHeroTag(task.cid),
              'offlineTask': task,
              'isOffline': true,
              'pic': task.cover,
            },
            parameters: {'bvid': task.bvid, 'cid': task.cid.toString()},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 100,
                  height: 62,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkImgLayer(src: task.cover, width: 100, height: 62),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            DownloadPageController.formatDuration(
                              task.duration,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (task.partTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.partTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.videoQualityDesc,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            DownloadPageController.formatBytes(task.totalBytes),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 删除按键
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: theme.colorScheme.outline,
                onPressed: () => _confirmDelete(task),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveList(ThemeData theme) {
    return Obx(() {
      final tasks = _controller.activeTasks;
      if (tasks.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_done_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '没有正在下载的任务',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: tasks.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final task = tasks[index];
          return _buildActiveCard(theme, task);
        },
      );
    });
  }

  Widget _buildActiveCard(ThemeData theme, DownloadTask task) {
    final bool isDownloading = task.status == DownloadTaskStatus.downloading;
    final bool isPaused = task.status == DownloadTaskStatus.paused;
    final bool isFailed = task.status == DownloadTaskStatus.failed;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onLongPress: () => _confirmDelete(task),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧：100x62 封面缩略图与时长胶囊
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 100,
                  height: 62,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkImgLayer(src: task.cover, width: 100, height: 62),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            DownloadPageController.formatDuration(
                              task.duration,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 中间：信息、进度与状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 微型进度条
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: task.progress > 0 ? task.progress : null,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFailed
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 进度大小与速率（双端弹性约束，防止小屏溢出）
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${DownloadPageController.formatBytes(task.downloadedBytes)} / '
                            '${DownloadPageController.formatBytes(task.totalBytes)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (isDownloading && task.downloadSpeed > 0)
                          Flexible(
                            flex: 2,
                            child: Text(
                              DownloadPageController.formatSpeed(
                                task.downloadSpeed,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else if (isFailed)
                          Flexible(
                            flex: 2,
                            child: Text(
                              '下载失败',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else if (isPaused)
                          Flexible(
                            flex: 2,
                            child: Text(
                              '已暂停',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // 右侧：单一播放/暂停控制按钮（长按删除）
              SizedBox(
                width: 40,
                height: 48,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(isDownloading ? Icons.pause : Icons.play_arrow),
                  color: theme.colorScheme.primary,
                  tooltip: isDownloading ? '暂停（长按删除）' : '继续（长按删除）',
                  onPressed: isDownloading
                      ? () => _controller.pauseTask(task.id)
                      : () => _controller.resumeTask(task.id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(DownloadTask task) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('删除离线缓存'),
          content: Text('确定要删除 "${task.title}" 及其本地文件吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _controller.deleteTask(task.id);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
}

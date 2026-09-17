/// 单任务双流断点续传下载执行器。
///
/// 负责视频流与音频流的 HTTP Range 断点下载、
/// HTTP 206/200 校验与回退、CDN 403 过期 URL 续期。
/// 不直接持有 [BuildContext]，所有进度与状态通过回调外露。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video_api.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/services/download/download_storage_manager.dart';
import 'package:pilipalaz/services/download/offline_danmaku_service.dart';
import 'package:pilipalaz/services/download/offline_subtitle_service.dart';
import 'package:pilipalaz/utils/video_utils.dart';

/// URL 续期结果。
class RenewedUrls {
  const RenewedUrls({required this.videoUrl, required this.audioUrl});
  final String videoUrl;
  final String audioUrl;
}

/// 进度回调签名：已下载字节数、总字节数、瞬时速率(bytes/s)。
typedef DownloadProgressCallback =
    void Function(int downloadedBytes, int totalBytes, int speed);

/// 单任务双流断点续传下载执行器。
///
/// 核心职责：
/// 1. 按 HTTP `Range: bytes=$start-` 断点续传下载视频/音频流
/// 2. 校验 206 vs 200 响应，防止重复数据拼接
/// 3. 捕获 403/410 触发同编码规格 URL 续期
/// 4. 隔离 `DioExceptionType.cancel` 为暂停态
class DownloadTaskExecutor {
  DownloadTaskExecutor({
    required this.task,
    required this.storageManager,
    required String videoUrl,
    required String audioUrl,
    Dio? dio,
    OfflineDanmakuService? danmakuService,
    OfflineSubtitleService? subtitleService,
    this.onProgress,
    this.onUrlRenewed,
  }) : _videoUrl = videoUrl,
       _audioUrl = audioUrl,
       _dio = dio ?? Dio(),
       _danmakuService = danmakuService ?? OfflineDanmakuService(),
       _subtitleService = subtitleService ?? OfflineSubtitleService();

  final DownloadTask task;
  final DownloadStorageManager storageManager;
  final DownloadProgressCallback? onProgress;
  final OfflineDanmakuService _danmakuService;
  final OfflineSubtitleService _subtitleService;

  /// URL 续期成功后回调，让上层缓存新 URL。
  final void Function(RenewedUrls urls)? onUrlRenewed;

  String _videoUrl;
  String _audioUrl;
  final Dio _dio;
  CancelToken? _cancelToken;

  int _videoDownloaded = 0;
  int _audioDownloaded = 0;
  int _videoTotal = 0;
  int _audioTotal = 0;

  /// 速率采样状态。
  int _lastReportedBytes = 0;
  DateTime _lastReportedTime = DateTime.now();

  /// 是否已被取消。
  bool get isCancelled => _cancelToken?.isCancelled ?? false;

  /// 执行下载。
  ///
  /// 返回 [DownloadTaskStatus.completed] 或 [DownloadTaskStatus.failed]。
  /// 用户暂停时返回 [DownloadTaskStatus.paused]。
  Future<DownloadTaskStatus> execute() async {
    _cancelToken = CancelToken();

    try {
      // 确保任务子目录存在
      final String videoPartFile = await storageManager.videoPartPath(task);
      final String audioPartFile = await storageManager.audioPartPath(task);
      await Directory(File(videoPartFile).parent.path).create(recursive: true);

      // 下载视频流
      await _downloadStream(
        url: _videoUrl,
        partFilePath: videoPartFile,
        isVideo: true,
      );

      // 下载音频流
      await _downloadStream(
        url: _audioUrl,
        partFilePath: audioPartFile,
        isVideo: false,
      );

      // 原子重命名：.part → 正式文件
      await _atomicRename(videoPartFile);
      await _atomicRename(audioPartFile);

      // 非致命辅助资产拉取（弹幕 + 封面）(BAC-3)
      await _downloadAuxiliaryAssets();

      return DownloadTaskStatus.completed;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return DownloadTaskStatus.paused;
      }
      rethrow;
    }
  }

  /// 拉取非致命辅助资产（离线弹幕与封面），失败仅记录并降级。
  Future<void> _downloadAuxiliaryAssets() async {
    // 1. 离线弹幕
    try {
      if (!isCancelled && task.cid > 0) {
        final String danmakuPath = await storageManager.absolutePath(
          storageManager.pathsForTask(task).danmakuRelativePath,
        );
        final File danmakuFile = File(danmakuPath);
        if (!await danmakuFile.exists()) {
          await _danmakuService.downloadDanmaku(
            cid: task.cid,
            duration: task.duration,
            targetFile: danmakuFile,
            cancelToken: _cancelToken,
          );
        }
      }
    } catch (_) {
      // 辅助资产非致命降级
    }

    // 2. 离线封面
    try {
      if (!isCancelled && task.cover.isNotEmpty) {
        final String coverPath = await storageManager.absolutePath(
          storageManager.pathsForTask(task).coverRelativePath,
        );
        final File coverFile = File(coverPath);
        if (!await coverFile.exists()) {
          final String normalizedCover = NetworkImgLayer.normalizeUrl(
            task.cover,
          );
          await _dio.download(
            normalizedCover,
            coverPath,
            cancelToken: _cancelToken,
            options: Options(receiveTimeout: const Duration(seconds: 8)),
          );
        }
      }
    } catch (_) {
      // 辅助资产非致命降级
    }

    // 3. 离线字幕
    try {
      if (!isCancelled && task.cid > 0) {
        final String subtitlePath = await storageManager.absolutePath(
          storageManager.pathsForTask(task).subtitlesRelativePath,
        );
        final File subtitleFile = File(subtitlePath);
        if (!await subtitleFile.exists()) {
          await _subtitleService.downloadSubtitles(
            bvid: task.bvid,
            cid: task.cid,
            targetFile: subtitleFile,
            cancelToken: _cancelToken,
          );
        }
      }
    } catch (_) {
      // 辅助资产非致命降级
    }
  }

  /// 取消当前下载（用于暂停/删除）。
  void cancel() {
    _cancelToken?.cancel('user_cancelled');
  }

  /// 释放资源。
  void dispose() {
    cancel();
    _dio.close(force: true);
  }

  // ── 单流下载核心 ──

  Future<void> _downloadStream({
    required String url,
    required String partFilePath,
    required bool isVideo,
  }) async {
    final File partFile = File(partFilePath);
    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    }

    // 首次尝试
    try {
      await _doRangeDownload(
        url: url,
        partFile: partFile,
        existingBytes: existingBytes,
        isVideo: isVideo,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;

      // 403/410 → URL 续期后重试
      if (_isUrlExpired(e)) {
        await _renewUrls();
        final String newUrl = isVideo ? _videoUrl : _audioUrl;
        // 重新读取已有字节数（可能在之前的下载中有增长）
        if (await partFile.exists()) {
          existingBytes = await partFile.length();
        }
        await _doRangeDownload(
          url: newUrl,
          partFile: partFile,
          existingBytes: existingBytes,
          isVideo: isVideo,
        );
      } else {
        rethrow;
      }
    }
  }

  /// 执行带 Range 头的流式下载。
  Future<void> _doRangeDownload({
    required String url,
    required File partFile,
    required int existingBytes,
    required bool isVideo,
  }) async {
    final Map<String, dynamic> headers = <String, dynamic>{
      'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
      'referer': 'https://www.bilibili.com',
    };

    if (existingBytes > 0) {
      headers['Range'] = 'bytes=$existingBytes-';
    }

    final Response<ResponseBody> response = await _dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream, headers: headers),
      cancelToken: _cancelToken,
    );

    // HTTP 206/200 校验
    final bool isPartial = response.statusCode == 206;
    final FileMode fileMode;
    if (isPartial) {
      fileMode = FileMode.append;
    } else {
      // 服务端返回 200 → 忽略 Range，从头写入
      fileMode = FileMode.write;
      existingBytes = 0;
    }

    // 从 Content-Length / Content-Range 解析总大小
    final int contentLength = _parseContentLength(response.headers);
    final int totalBytes = isPartial
        ? existingBytes + contentLength
        : contentLength;

    if (isVideo) {
      _videoTotal = totalBytes;
      _videoDownloaded = existingBytes;
    } else {
      _audioTotal = totalBytes;
      _audioDownloaded = existingBytes;
    }
    _emitProgress();

    // 流式写入文件
    final IOSink sink = partFile.openWrite(mode: fileMode);
    try {
      await for (final List<int> chunk in response.data!.stream) {
        sink.add(chunk);
        if (isVideo) {
          _videoDownloaded += chunk.length;
        } else {
          _audioDownloaded += chunk.length;
        }
        _emitProgress();

        // 运行时磁盘水位检查（每 2MB 检查一次）
        if ((_videoDownloaded + _audioDownloaded) % (2 * 1024 * 1024) <
            chunk.length) {
          if (await storageManager.isBelowSafetyThreshold()) {
            cancel();
            throw DioException(
              requestOptions: response.requestOptions,
              message: 'insufficient_disk_space',
              type: DioExceptionType.unknown,
            );
          }
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  // ── URL 过期检测与续期 ──

  bool _isUrlExpired(DioException e) {
    final int? statusCode = e.response?.statusCode;
    return statusCode == 403 || statusCode == 410;
  }

  /// 调用 B 站 API 刷新同编码规格的 CDN 地址。
  Future<void> _renewUrls() async {
    final result = await VideoApi.instance.playUrl(
      bvid: task.bvid,
      cid: task.cid,
    );

    switch (result) {
      case ApiSuccess<PlayUrlModel>(:final data):
        final dash = data.dash;
        if (dash == null) {
          throw StateError('URL renewal failed: no DASH data');
        }

        // 严格匹配原任务的画质 + 编码格式
        final newVideo = _findMatchingVideo(dash);
        final newAudio = _findMatchingAudio(dash);

        if (newVideo == null || newAudio == null) {
          throw StateError(
            'URL renewal failed: codec/quality mismatch '
            '(q=${task.videoQuality}, c=${task.videoCodec}, '
            'a=${task.audioQuality})',
          );
        }

        _videoUrl = VideoUtils.getCdnUrl(newVideo);
        _audioUrl = VideoUtils.getCdnUrl(newAudio);

        onUrlRenewed?.call(
          RenewedUrls(videoUrl: _videoUrl, audioUrl: _audioUrl),
        );

      case ApiFailure():
        throw StateError('URL renewal API request failed');
    }
  }

  /// 从 DASH 视频列表中查找匹配原任务画质和编码的流。
  VideoItem? _findMatchingVideo(Dash dash) {
    final List<VideoItem>? videos = dash.video;
    if (videos == null) return null;

    for (final VideoItem v in videos) {
      if (v.id == task.videoQuality &&
          _codecMatches(v.codecs, task.videoCodec)) {
        return v;
      }
    }
    return null;
  }

  /// 从 DASH 音频列表中查找匹配原任务音质的流。
  AudioItem? _findMatchingAudio(Dash dash) {
    final List<AudioItem>? audios = dash.audio;
    if (audios == null) return null;

    for (final AudioItem a in audios) {
      if (a.id == task.audioQuality) return a;
    }
    return null;
  }

  /// 编码格式前缀匹配（如 "avc1.640032" 匹配 "avc1"）。
  bool _codecMatches(String? actual, String expected) {
    if (actual == null) return false;
    // 取编码族前缀比较
    final String actualPrefix = actual.split('.').first.toLowerCase();
    final String expectedPrefix = expected.split('.').first.toLowerCase();
    return actualPrefix == expectedPrefix;
  }

  // ── 工具方法 ──

  /// 原子重命名 `.part` → 正式文件。
  Future<void> _atomicRename(String partFilePath) async {
    final File partFile = File(partFilePath);
    if (!await partFile.exists()) return;
    final String finalPath = partFilePath.endsWith('.part')
        ? partFilePath.substring(0, partFilePath.length - 5)
        : partFilePath;
    await partFile.rename(finalPath);
  }

  /// 从响应头解析 Content-Length。
  int _parseContentLength(Headers headers) {
    final String? cl = headers.value('content-length');
    if (cl != null) {
      final int? parsed = int.tryParse(cl);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  /// 发射进度回调（限制频率，最多每 500ms 一次）。
  void _emitProgress() {
    final int totalDownloaded = _videoDownloaded + _audioDownloaded;
    final int totalSize = _videoTotal + _audioTotal;

    final DateTime now = DateTime.now();
    final int elapsedMs = now.difference(_lastReportedTime).inMilliseconds;

    if (elapsedMs < 500 && totalDownloaded < totalSize) return;

    final int byteDelta = totalDownloaded - _lastReportedBytes;
    final int speed = elapsedMs > 0 ? (byteDelta * 1000 ~/ elapsedMs) : 0;

    _lastReportedBytes = totalDownloaded;
    _lastReportedTime = now;

    onProgress?.call(totalDownloaded, totalSize, speed);
  }
}

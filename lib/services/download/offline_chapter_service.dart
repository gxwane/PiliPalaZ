/// 离线章节下载与本地持久化服务。
///
/// 负责拉取视频章节（view_points）元信息，原子持久化为本地单一 JSON 文件，
/// 并在离线播放时提供纯本地反序列化与时间戳归一化排序。
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video.dart';

/// 视频章节拉取函数类型，便于依赖注入与测试。
typedef ChapterFetcher =
    Future<ApiResult<List<VideoChapter>>> Function({
      String? aid,
      String? bvid,
      required int cid,
    });

/// 离线章节下载与装载服务。
class OfflineChapterService {
  OfflineChapterService({ChapterFetcher? chapterFetcher})
    : _chapterFetcher = chapterFetcher ?? VideoHttp.videoChapters;

  final ChapterFetcher _chapterFetcher;

  /// 下载并持久化指定 bvid / cid 的全部章节分段数据。
  ///
  /// [bvid] 视频 BV 号。
  /// [cid] 视频分 P 编号。
  /// [aid] 可选 AV 号。
  /// [targetFile] 本地目标文件（如 `.../chapters.json`）。
  /// [cancelToken] 可选 Dio 取消令牌，用于感知任务暂停/取消。
  Future<bool> downloadChapters({
    required String bvid,
    required int cid,
    int? aid,
    required File targetFile,
    CancelToken? cancelToken,
  }) async {
    try {
      if (cancelToken?.isCancelled == true) return false;

      final ApiResult<List<VideoChapter>> metaResult = await _chapterFetcher(
        aid: aid?.toString(),
        bvid: bvid,
        cid: cid,
      );

      if (cancelToken?.isCancelled == true) return false;

      if (metaResult case ApiSuccess<List<VideoChapter>>(:final data)) {
        if (data.isEmpty) {
          // 视频本身无章节分段，优雅正常返回且不创建 0 字节垃圾文件
          return true;
        }

        // 防御性时间戳单调升序排序
        final List<VideoChapter> sorted = List<VideoChapter>.from(data)
          ..sort((VideoChapter a, VideoChapter b) => a.from.compareTo(b.from));

        final List<Map<String, dynamic>> jsonList = sorted
            .map((VideoChapter c) => c.toJson())
            .toList(growable: false);

        // 临时文件原子写入并重命名（Write-to-Temp-Rename），防断电或进程划退损坏
        final File tempFile = File('${targetFile.path}.tmp');
        await tempFile.parent.create(recursive: true);
        await tempFile.writeAsString(jsonEncode(jsonList), flush: true);

        if (cancelToken?.isCancelled == true) {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          return false;
        }

        await tempFile.rename(targetFile.path);
        return true;
      }
      return false;
    } on Exception {
      return false;
    }
  }

  /// 从本地 JSON 文件读取离线章节列表。
  ///
  /// 若文件不存在、损坏或内容非列表则安全返回 `null`。
  /// 严格保证反序列化后章节按时间戳单调升序排列。
  static Future<List<VideoChapter>?> loadChaptersFromFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final String content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final dynamic decoded = jsonDecode(content);
      if (decoded is! List) return null;

      final List<VideoChapter> chapters = <VideoChapter>[];
      for (final dynamic item in decoded) {
        if (item is Map<String, dynamic>) {
          chapters.add(VideoChapter.fromJson(item));
        } else if (item is Map) {
          chapters.add(VideoChapter.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      if (chapters.isEmpty) return null;

      chapters.sort(
        (VideoChapter a, VideoChapter b) => a.from.compareTo(b.from),
      );
      return chapters;
    } on Exception {
      return null;
    }
  }
}

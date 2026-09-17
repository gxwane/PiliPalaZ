/// 离线字幕下载与本地持久化服务。
///
/// 负责拉取视频字幕元信息，转换为 WebVTT 格式并聚合持久化为单一 JSON 文件。
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video.dart';

/// 视频元信息拉取函数类型，便于依赖注入与测试。
typedef VideoMetaFetcher =
    Future<ApiResult<List<VideoSubtitleSource>>> Function({
      String? aid,
      String? bvid,
      required int cid,
    });

/// WebVTT 字幕转换函数类型，便于依赖注入与测试。
typedef VttConverter =
    Future<ApiResult<List<Map<String, String>>>> Function(
      List<VideoSubtitleSource> subtitles,
    );

/// 离线字幕下载与装载服务。
class OfflineSubtitleService {
  OfflineSubtitleService({
    VideoMetaFetcher? videoMetaFetcher,
    VttConverter? vttConverter,
  }) : _videoMetaFetcher = videoMetaFetcher ?? VideoHttp.videoMetaInfo,
       _vttConverter = vttConverter ?? VideoHttp.vttSubtitles;

  final VideoMetaFetcher _videoMetaFetcher;
  final VttConverter _vttConverter;

  /// 下载并持久化指定 bvid / cid 的全部字幕数据。
  ///
  /// [bvid] 视频 BV 号。
  /// [cid] 视频分 P 编号。
  /// [targetFile] 本地目标文件（如 `.../subtitles.json`）。
  /// [cancelToken] 可选 Dio 取消令牌，用于感知任务暂停/取消。
  Future<bool> downloadSubtitles({
    required String bvid,
    required int cid,
    required File targetFile,
    CancelToken? cancelToken,
  }) async {
    try {
      if (cancelToken?.isCancelled == true) return false;

      final ApiResult<List<VideoSubtitleSource>> metaResult =
          await _videoMetaFetcher(bvid: bvid, cid: cid);

      if (cancelToken?.isCancelled == true) return false;

      if (metaResult case ApiSuccess<List<VideoSubtitleSource>>(:final data)) {
        if (data.isEmpty) {
          return true; // 视频本身无字幕，优雅正常返回
        }

        final ApiResult<List<Map<String, String>>> vttResult =
            await _vttConverter(data);

        if (cancelToken?.isCancelled == true) return false;

        if (vttResult case ApiSuccess<List<Map<String, String>>>(:final data)) {
          if (data.isEmpty) return true;

          final List<Map<String, String>> tracksToSave = [];
          for (final track in data) {
            // 剔除可能已存在的占位'关闭字幕'，保持存储层纯粹
            if (track['title'] == '关闭字幕' && (track['text'] ?? '').isEmpty) {
              continue;
            }
            tracksToSave.add({
              'language': track['language'] ?? '',
              'title': track['title'] ?? '',
              'text': track['text'] ?? '',
            });
          }

          if (tracksToSave.isEmpty) return true;

          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsString(jsonEncode(tracksToSave), flush: true);
          return true;
        }
      }
      return false;
    } on Exception {
      return false;
    }
  }

  /// 从本地 JSON 文件读取离线字幕。
  ///
  /// 若文件不存在、损坏或内容非列表则返回 `null`。
  /// 严格保证 Index 0 具有唯一的 '关闭字幕' 轨道契约。
  static Future<List<Map<String, String>>?> loadSubtitlesFromFile(
    File file,
  ) async {
    try {
      if (!await file.exists()) return null;
      final String content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final dynamic decoded = jsonDecode(content);
      if (decoded is! List) return null;

      final List<Map<String, String>> tracks = [];
      for (final item in decoded) {
        if (item is Map) {
          tracks.add({
            'language': (item['language'] as String?) ?? '',
            'title': (item['title'] as String?) ?? '',
            'text': (item['text'] as String?) ?? '',
          });
        }
      }

      if (tracks.isEmpty) return null;

      // 幂等补齐 Index 0 '关闭字幕'
      if (tracks.first['title'] != '关闭字幕') {
        tracks.insert(0, const <String, String>{
          'language': '',
          'title': '关闭字幕',
          'text': '',
        });
      }

      return tracks;
    } on Exception {
      return null;
    }
  }
}

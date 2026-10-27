/// 轻量级纯 Dart WebVTT / SRT 文本时码解析器与字幕查询器。
///
/// 遵循 Gate 3 架构分层守卫：零 Flutter UI 依赖，内存纯函数。
library;

/// 单条字幕时间切片模型
class SubtitleCue {
  /// 起始时间戳
  final Duration start;

  /// 结束时间戳
  final Duration end;

  /// 清洗后的纯净字幕文本
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  @override
  String toString() => 'SubtitleCue($start --> $end: $text)';
}

/// WebVTT / SRT 解析与查询工具类
abstract final class WebVttParser {
  /// 时码正则匹配器：
  /// - 支持可选小时：(?:(\d{1,2}):)?
  /// - 分钟与秒：(\d{2}):(\d{2})
  /// - 毫秒分隔符（支持 . 与 ,）：[.,](\d{3})
  /// - 箭头分隔：\s*-->\s*
  static final RegExp _timecodePattern = RegExp(
    r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[.,](\d{3})',
  );

  /// HTML / VTT 样式标签匹配正则
  static final RegExp _htmlTagPattern = RegExp(r'<[^>]+>');

  /// 解析 WebVTT / SRT 字符串为结构化 [SubtitleCue] 列表
  static List<SubtitleCue> parse(String content) {
    if (content.trim().isEmpty) return const [];

    final List<SubtitleCue> cues = [];
    final List<String> lines = content.split(RegExp(r'\r?\n'));

    Duration? currentStart;
    Duration? currentEnd;
    final List<String> currentTextLines = [];

    void commitCurrentCue() {
      if (currentStart != null &&
          currentEnd != null &&
          currentTextLines.isNotEmpty) {
        final rawText = currentTextLines.join('\n').trim();
        final sanitizedText = sanitizeText(rawText);
        if (sanitizedText.isNotEmpty) {
          cues.add(
            SubtitleCue(
              start: currentStart!,
              end: currentEnd!,
              text: sanitizedText,
            ),
          );
        }
      }
      currentStart = null;
      currentEnd = null;
      currentTextLines.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      final match = _timecodePattern.firstMatch(trimmed);

      if (match != null) {
        commitCurrentCue();
        currentStart = _parseDuration(
          match.group(1),
          match.group(2)!,
          match.group(3)!,
          match.group(4)!,
        );
        currentEnd = _parseDuration(
          match.group(5),
          match.group(6)!,
          match.group(7)!,
          match.group(8)!,
        );
      } else if (currentStart != null && currentEnd != null) {
        if (trimmed.isEmpty) {
          commitCurrentCue();
        } else {
          currentTextLines.add(line);
        }
      }
    }

    commitCurrentCue();
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  /// 根据当前媒体播放时间查找匹配的活动字幕文本。
  ///
  /// 若同一时间命中多个切片（如双人同框说话），按时间序以换行拼接；若无命中则返回空字符串。
  static String findActiveText(List<SubtitleCue> cues, Duration position) {
    if (cues.isEmpty) return '';

    final List<String> matched = [];
    for (int i = 0; i < cues.length; i++) {
      final cue = cues[i];
      if (position >= cue.start && position < cue.end) {
        matched.add(cue.text);
      } else if (cue.start > position && matched.isNotEmpty) {
        // 因列表已按 start 升序排序，若已经产生匹配且当前起始点已超前，则可提前退出
        break;
      }
    }

    return matched.isEmpty ? '' : matched.join('\n');
  }

  /// 过滤 HTML/VTT 标签并反转义常见 HTML 实体
  static String sanitizeText(String input) {
    if (input.isEmpty) return '';

    String cleaned = input.replaceAll(_htmlTagPattern, '');
    cleaned = cleaned
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    return cleaned.trim();
  }

  static Duration _parseDuration(
    String? hoursStr,
    String minutesStr,
    String secondsStr,
    String millisStr,
  ) {
    final int hours = hoursStr != null ? int.tryParse(hoursStr) ?? 0 : 0;
    final int minutes = int.tryParse(minutesStr) ?? 0;
    final int seconds = int.tryParse(secondsStr) ?? 0;
    final int millis = int.tryParse(millisStr) ?? 0;

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }
}

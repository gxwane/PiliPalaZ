import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/models/video/play/chapter.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/play_status.dart';

class ReplyTimestampParser {
  /// Regular expression for matching timestamps in comment strings:
  /// - Supports mm:ss and hh:mm:ss
  /// - Supports single-digit minute (e.g. 1:23)
  /// - Supports Chinese full-width colon (：)
  /// - Guards against URLs (like http://127.0.0.1:8080), alphanumeric characters and chained colons
  static final RegExp timestampPattern = RegExp(
    r'(?<![\d\w\/:：])(?:(?:(\d{1,2})[:：])?([0-5]?\d)[:：]([0-5]\d))(?![\d\w\/:：])',
  );

  /// Strict regex to check if an entire trimmed string is a timestamp
  static final RegExp strictTimestampPattern = RegExp(
    r'^(?:(?:(\d{1,2})[:：])?([0-5]?\d)[:：]([0-5]\d))$',
  );

  /// Normalizes full-width colon to half-width colon and trims
  static String normalizeTimestamp(String text) {
    return text.replaceAll('：', ':').trim();
  }

  /// Checks if a string represents a valid timestamp
  static bool isTimestamp(String text) {
    final trimmed = text.trim();
    return strictTimestampPattern.hasMatch(trimmed);
  }

  /// Parses timestamp string into total seconds.
  /// Returns null if string is invalid or cannot be parsed.
  static int? parseToSeconds(String text) {
    final trimmed = text.trim();
    final match = strictTimestampPattern.firstMatch(trimmed);
    if (match == null) return null;

    final hoursStr = match.group(1);
    final minutesStr = match.group(2);
    final secondsStr = match.group(3);

    final hours = hoursStr != null ? int.tryParse(hoursStr) ?? 0 : 0;
    final minutes = minutesStr != null ? int.tryParse(minutesStr) : null;
    final seconds = secondsStr != null ? int.tryParse(secondsStr) : null;

    if (minutes == null || seconds == null) return null;
    if (minutes < 0 || minutes > 59 || seconds < 0 || seconds > 59) return null;

    return hours * 3600 + minutes * 60 + seconds;
  }

  /// Extracts all timestamps found within text
  static List<String> extractTimestamps(String text) {
    return timestampPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Safely seeks active player to the target timestamp and auto-plays
  static Future<bool> seekToTimestamp(
    String text, {
    PlPlayerController? controller,
    BuildContext? context,
    VoidCallback? onSeek,
  }) async {
    final targetSeconds = parseToSeconds(text);
    if (targetSeconds == null) return false;

    final player =
        controller ??
        (PlPlayerController.instanceExists()
            ? PlPlayerController.getInstance()
            : null);
    if (player == null ||
        !player.canControlPlayback ||
        player.playerStatus.status.value == PlayerStatus.disabled) {
      SmartDialog.showToast('播放器未就绪');
      return false;
    }

    final totalSeconds = player.durationSeconds.value;
    if (totalSeconds > 0 && targetSeconds > totalSeconds) {
      SmartDialog.showToast('时间戳超出视频总时长');
      return false;
    }

    // Invoke onSeek callback (e.g. to dismiss drawer/panel)
    onSeek?.call();

    // Seek to destination
    await player.seekTo(Duration(seconds: targetSeconds), type: 'slider');

    // Auto play if not playing
    if (!player.isPlaying) {
      await player.play(hideControls: false);
    }

    // Haptic feedback
    unawaited(HapticFeedback.selectionClick());

    // Chapter-aware feedback
    final normalized = normalizeTimestamp(text);
    final chapters = player.chapters;
    VideoChapter? chapter;
    if (chapters.isNotEmpty) {
      final isLastIndex = chapters.length - 1;
      for (int i = 0; i < chapters.length; i++) {
        if (chapters[i].contains(targetSeconds, isLast: i == isLastIndex)) {
          chapter = chapters[i];
          break;
        }
      }
    }
    final String chapterTitle = chapter?.title.trim() ?? '';
    final feedbackMsg = chapterTitle.isNotEmpty
        ? '跳转至 $normalized · $chapterTitle'
        : '跳转至 $normalized';
    SmartDialog.showToast(feedbackMsg);

    return true;
  }
}

import 'package:pilipalaz/models/video/play/quality.dart';
import 'package:pilipalaz/models/video/play/url.dart';

const List<VideoQuality> standardVideoQualityPreference = <VideoQuality>[
  VideoQuality.super8k,
  VideoQuality.super4K,
  VideoQuality.high108060,
  VideoQuality.high1080plus,
  VideoQuality.high1080,
  VideoQuality.high72060,
  VideoQuality.high720,
  VideoQuality.clear480,
  VideoQuality.fluent360,
  VideoQuality.speed240,
];

bool isSpecialVideoQuality(VideoQuality quality) {
  return quality == VideoQuality.hdr || quality == VideoQuality.dolbyVision;
}

bool hasSelectableDashVideo(PlayUrlModel videoInfo) {
  return videoInfo.dash?.video?.isNotEmpty == true;
}

final class HardwareAlternativeRecoveryGuard {
  bool _attempted = false;

  bool tryBegin() {
    if (_attempted) return false;
    _attempted = true;
    return true;
  }

  void reset() => _attempted = false;
}

int? selectPreferredVideoQualityCode({
  required int? preferredCode,
  required Iterable<int> availableCodes,
}) {
  final List<int> available = availableCodes.toSet().toList();
  if (available.isEmpty) return null;

  final VideoQuality? preferred = preferredCode == null
      ? null
      : VideoQualityCode.fromCode(preferredCode);
  if (preferred != null &&
      isSpecialVideoQuality(preferred) &&
      available.contains(preferred.code)) {
    return preferred.code;
  }

  final Set<int> availableSet = available.toSet();
  final List<VideoQuality> availableStandard = standardVideoQualityPreference
      .where((VideoQuality quality) => availableSet.contains(quality.code))
      .toList();
  if (availableStandard.isNotEmpty) {
    if (preferred != null && !isSpecialVideoQuality(preferred)) {
      final int preferredIndex = standardVideoQualityPreference.indexOf(
        preferred,
      );
      if (preferredIndex >= 0) {
        for (
          int index = preferredIndex;
          index < standardVideoQualityPreference.length;
          index++
        ) {
          final VideoQuality candidate = standardVideoQualityPreference[index];
          if (availableSet.contains(candidate.code)) return candidate.code;
        }
        for (int index = preferredIndex - 1; index >= 0; index--) {
          final VideoQuality candidate = standardVideoQualityPreference[index];
          if (availableSet.contains(candidate.code)) return candidate.code;
        }
      }
    }
    return availableStandard.first.code;
  }

  // A title containing only a special representation should remain playable.
  return available.first;
}

VideoItem? selectCompatibleFallbackVideo({
  required VideoItem current,
  required Iterable<VideoItem> candidates,
}) {
  final int? currentArea = _pixelArea(current);
  final List<VideoItem> compatible = candidates.where((VideoItem candidate) {
    if (identical(candidate, current) || _sameSource(candidate, current)) {
      return false;
    }
    if (candidate.baseUrl?.isNotEmpty != true &&
        candidate.backupUrl?.isNotEmpty != true) {
      return false;
    }
    final VideoQuality? quality =
        candidate.quality ??
        (candidate.id == null
            ? null
            : VideoQualityCode.fromCode(candidate.id!));
    if (quality == null || isSpecialVideoQuality(quality)) return false;

    return _doesNotExceedCurrentQuality(
      current: current,
      candidate: candidate,
      currentArea: currentArea,
    );
  }).toList();

  compatible.sort((VideoItem left, VideoItem right) {
    final int areaOrder = (_pixelArea(right) ?? -1).compareTo(
      _pixelArea(left) ?? -1,
    );
    if (areaOrder != 0) return areaOrder;

    final int codecOrder = _codecCompatibilityRank(
      left.codecs,
    ).compareTo(_codecCompatibilityRank(right.codecs));
    if (codecOrder != 0) return codecOrder;

    final int qualityOrder = _qualityPreferenceIndex(
      left,
    ).compareTo(_qualityPreferenceIndex(right));
    if (qualityOrder != 0) return qualityOrder;

    return (right.bandWidth ?? -1).compareTo(left.bandWidth ?? -1);
  });
  return compatible.firstOrNull;
}

String describeVideoCodec(String? codec) {
  final String normalized = codec?.trim() ?? '';
  if (normalized.isEmpty) return '未知';
  final VideoDecodeFormats? format = VideoDecodeFormatsCode.fromString(
    normalized,
  );
  if (format != null) return format.description;
  return normalized.split('.').first.toUpperCase();
}

int? _pixelArea(VideoItem item) {
  final int? width = item.width;
  final int? height = item.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return width * height;
}

bool _doesNotExceedCurrentQuality({
  required VideoItem current,
  required VideoItem candidate,
  required int? currentArea,
}) {
  final int? candidateArea = _pixelArea(candidate);
  if (currentArea != null && candidateArea != null) {
    return candidateArea <= currentArea;
  }

  final VideoQuality? currentQuality =
      current.quality ??
      (current.id == null ? null : VideoQualityCode.fromCode(current.id!));
  final VideoQuality? candidateQuality =
      candidate.quality ??
      (candidate.id == null ? null : VideoQualityCode.fromCode(candidate.id!));
  if (currentQuality == null || candidateQuality == null) return false;
  if (isSpecialVideoQuality(currentQuality)) {
    return candidateQuality.code < currentQuality.code;
  }
  final int currentIndex = standardVideoQualityPreference.indexOf(
    currentQuality,
  );
  final int candidateIndex = standardVideoQualityPreference.indexOf(
    candidateQuality,
  );
  return currentIndex >= 0 &&
      candidateIndex >= 0 &&
      candidateIndex >= currentIndex;
}

bool _sameSource(VideoItem left, VideoItem right) {
  final Set<String> leftUrls = <String>{
    if (left.baseUrl?.isNotEmpty == true) left.baseUrl!,
    if (left.backupUrl?.isNotEmpty == true) left.backupUrl!,
  };
  return leftUrls.contains(right.baseUrl) || leftUrls.contains(right.backupUrl);
}

int _codecCompatibilityRank(String? codec) {
  return switch (VideoDecodeFormatsCode.fromString(codec ?? '')) {
    VideoDecodeFormats.AVC => 0,
    VideoDecodeFormats.HEVC => 1,
    VideoDecodeFormats.AV1 => 2,
    VideoDecodeFormats.DVH1 => 4,
    null => 3,
  };
}

int _qualityPreferenceIndex(VideoItem item) {
  final VideoQuality? quality =
      item.quality ??
      (item.id == null ? null : VideoQualityCode.fromCode(item.id!));
  final int index = quality == null
      ? -1
      : standardVideoQualityPreference.indexOf(quality);
  return index < 0 ? standardVideoQualityPreference.length : index;
}

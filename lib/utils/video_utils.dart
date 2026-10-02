import 'package:fl_pip/fl_pip.dart';
import 'package:pilipalaz/models/video/play/CDN.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/utils/storage.dart';

import '../models/live/room_info.dart';

class VideoUtils {
  static bool isMCDNorPCDN(String url) {
    return url.contains("szbdyd.com") ||
        url.contains(".mcdn.bilivideo") ||
        RegExp(r'^https?://\d{1,3}\.\d{1,3}').hasMatch(url);
  }

  static String getLiveCdnUrl(CodecItem? item, {int lineIndex = 0}) {
    if (item == null) return "";
    final urlInfo = item.urlInfo;
    final baseUrl = item.baseUrl ?? "";
    if (urlInfo == null || urlInfo.isEmpty || baseUrl.isEmpty) {
      return "";
    }
    final int safeIndex = (lineIndex >= 0 && lineIndex < urlInfo.length)
        ? lineIndex
        : 0;
    final info = urlInfo[safeIndex];
    final host = info.host ?? "";
    final extra = info.extra ?? "";
    if (host.isEmpty) {
      return "";
    }
    return host + baseUrl + extra;
  }

  static Set<int> parseAcceptQn(dynamic acceptQn) {
    if (acceptQn is! Iterable) return <int>{};
    final result = <int>{};
    for (final item in acceptQn) {
      if (item is int && item > 0) {
        result.add(item);
      } else if (item is num && item > 0) {
        result.add(item.toInt());
      } else if (item is String) {
        final parsed = int.tryParse(item);
        if (parsed != null && parsed > 0) {
          result.add(parsed);
        }
      }
    }
    return result;
  }

  static List<GQnDesc> filterAndSortQualities({
    required List<GQnDesc>? allQualities,
    required dynamic acceptQn,
  }) {
    if (allQualities == null || allQualities.isEmpty) return <GQnDesc>[];
    final validQns = parseAcceptQn(acceptQn);
    if (validQns.isEmpty) {
      return List<GQnDesc>.from(allQualities)
        ..sort((a, b) => (b.qn ?? 0).compareTo(a.qn ?? 0));
    }
    final filtered = allQualities.where((q) {
      return q.qn != null && validQns.contains(q.qn!);
    }).toList();
    if (filtered.isEmpty) {
      return List<GQnDesc>.from(allQualities)
        ..sort((a, b) => (b.qn ?? 0).compareTo(a.qn ?? 0));
    }
    filtered.sort((a, b) => (b.qn ?? 0).compareTo(a.qn ?? 0));
    return filtered;
  }

  static int resolveSupportedQn({
    required dynamic acceptQn,
    required int currentQn,
    int fallbackDefault = 10000,
  }) {
    final validQns = parseAcceptQn(acceptQn);
    if (validQns.isEmpty || validQns.contains(currentQn)) {
      return currentQn;
    }
    final sorted = validQns.toList()..sort((a, b) => b.compareTo(a));
    return sorted.isNotEmpty ? sorted.first : fallbackDefault;
  }

  static String getCdnUrl(dynamic item) {
    if (item is CodecItem) {
      return getLiveCdnUrl(item);
    }
    String? backupUrl;
    String? videoUrl;
    String defaultCDNService = GStorage.setting.get(
      SettingBoxKey.CDNService,
      defaultValue: CDNService.backupUrl.code,
    );
    if (item is AudioItem) {
      if (GStorage.setting.get(
        SettingBoxKey.disableAudioCDN,
        defaultValue: true,
      )) {
        return item.backupUrl?.isNotEmpty == true
            ? item.backupUrl!
            : item.baseUrl ?? "";
      }
    }
    if (defaultCDNService == CDNService.baseUrl.code) {
      return item.baseUrl?.isNotEmpty == true
          ? item.baseUrl
          : item.backupUrl ?? "";
    }
    backupUrl = item.backupUrl;
    if (defaultCDNService == CDNService.backupUrl.code) {
      return backupUrl?.isNotEmpty == true ? backupUrl : item.baseUrl ?? "";
    }
    videoUrl = (backupUrl?.isEmpty != false || isMCDNorPCDN(backupUrl!))
        ? item.baseUrl
        : backupUrl;

    if (videoUrl?.isEmpty != false) {
      return "";
    }
    print("videoUrl:$videoUrl");

    String defaultCDNHost = CDNServiceCode.fromCode(defaultCDNService)!.host;
    print("defaultCDNHost:$defaultCDNHost");
    if (videoUrl!.contains("szbdyd.com")) {
      String hostname =
          Uri.parse(videoUrl).queryParameters['xy_usource'] ?? defaultCDNHost;
      videoUrl = Uri.parse(
        videoUrl,
      ).replace(host: hostname, port: 443).toString();
    } else if (videoUrl.contains(".mcdn.bilivideo")) {
      videoUrl = Uri.parse(
        videoUrl,
      ).replace(host: defaultCDNHost, port: 443).toString();
      // videoUrl =
      //     'https://proxy-tf-all-ws.bilivideo.com/?url=${Uri.encodeComponent(videoUrl)}';
    } else if (videoUrl.contains("/upgcxcode/")) {
      videoUrl = Uri.parse(
        videoUrl,
      ).replace(host: defaultCDNHost, port: 443).toString();
    }
    print("videoUrl:$videoUrl");

    // /// 先获取backupUrl 一般是upgcxcode地址 播放更稳定
    // if (item is VideoItem) {
    //   backupUrl = item.backupUrl ?? "";
    //   videoUrl = backupUrl.contains("http") ? backupUrl : (item.baseUrl ?? "");
    // } else if (item is AudioItem) {
    //   backupUrl = item.backupUrl ?? "";
    //   videoUrl = backupUrl.contains("http") ? backupUrl : (item.baseUrl ?? "");
    // } else if (item is CodecItem) {
    //   backupUrl = (item.urlInfo?.first.host)! +
    //       item.baseUrl! +
    //       item.urlInfo!.first.extra!;
    //   videoUrl = backupUrl.contains("http") ? backupUrl : (item.baseUrl ?? "");
    // } else {
    //   return "";
    // }
    //
    // /// issues #70
    // if (videoUrl.contains(".mcdn.bilivideo")) {
    //   videoUrl =
    //       'https://proxy-tf-all-ws.bilivideo.com/?url=${Uri.encodeComponent(videoUrl)}';
    // } else if (videoUrl.contains("/upgcxcode/")) {
    //   //CDN列表
    //   var cdnList = {
    //     'ali': 'upos-sz-mirrorali.bilivideo.com',
    //     'cos': 'upos-sz-mirrorcos.bilivideo.com',
    //     'hw': 'upos-sz-mirrorhw.bilivideo.com',
    //   };
    //   //取一个CDN
    //   var cdn = cdnList['cos'] ?? "";
    //   var reg = RegExp(r'(http|https)://(.*?)/upgcxcode/');
    //   videoUrl = videoUrl.replaceAll(reg, "https://$cdn/upgcxcode/");
    // }

    return videoUrl;
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a.abs();
  }

  static Rational clampPiPRational({
    int? width,
    int? height,
    String fallbackDirection = 'horizontal',
  }) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return fallbackDirection == 'vertical'
          ? const Rational(9, 16)
          : const Rational(16, 9);
    }
    final double ratio = width / height;
    if (ratio > 2.39) {
      return const Rational(239, 100);
    }
    if (ratio < (100 / 239)) {
      return const Rational(100, 239);
    }
    final divisor = _gcd(width, height);
    final safeW = (width ~/ divisor).clamp(1, 10000);
    final safeH = (height ~/ divisor).clamp(1, 10000);
    return Rational(safeW, safeH);
  }
}

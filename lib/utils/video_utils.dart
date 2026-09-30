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

  static String getCdnUrl(dynamic item) {
    String? backupUrl;
    String? videoUrl;
    String defaultCDNService = GStorage.setting.get(
      SettingBoxKey.CDNService,
      defaultValue: CDNService.backupUrl.code,
    );
    if (item is CodecItem) {
      final urlInfo = item.urlInfo;
      if (urlInfo == null || urlInfo.isEmpty || item.baseUrl == null) {
        return "";
      }
      final firstInfo = urlInfo.first;
      final host = firstInfo.host ?? "";
      final extra = firstInfo.extra ?? "";
      final baseUrl = item.baseUrl ?? "";
      if (host.isEmpty && baseUrl.isEmpty) {
        return "";
      }
      final fullLiveUrl = host + baseUrl + extra;
      if (defaultCDNService == CDNService.backupUrl.code ||
          defaultCDNService == CDNService.baseUrl.code) {
        return fullLiveUrl;
      }
      backupUrl = fullLiveUrl;
      videoUrl = fullLiveUrl;
    } else {
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
    }

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
}

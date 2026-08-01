// 工具函数
// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:pilipalaz/utils/storage_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class Utils {
  static final Random random = Random();

  static Future<String> getCookiePath() async {
    final Directory tempDir = await getApplicationSupportDirectory();
    final String tempPath = "${tempDir.path}/${StoragePathName.cookie}/";
    final Directory dir = Directory(tempPath);
    final bool b = await dir.exists();
    if (!b) {
      dir.createSync(recursive: true);
    }
    return tempPath;
  }

  static String numFormat(dynamic number) {
    if (number == null) {
      return '00:00';
    }
    if (number is String) {
      return number;
    }
    if (number >= 100000000) {
      return '${(number / 100000000).toStringAsFixed(1)}亿';
    } else if (number >= 100000) {
      return '${(number ~/ 10000).toString()}万';
    } else if (number > 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    } else {
      return number.toString();
    }
  }

  static String durationReadFormat(String duration) {
    List<String> durationParts = duration.split(':');

    if (durationParts.length == 3) {
      if (durationParts[0] != '00') {
        return '${int.parse(durationParts[0])}小时${durationParts[1]}分钟${durationParts[2]}秒';
      }
      durationParts.removeAt(0);
    }
    if (durationParts.length == 2) {
      if (durationParts[0] != '00') {
        return '${int.parse(durationParts[0])}分钟${durationParts[1]}秒';
      }
      durationParts.removeAt(0);
    }
    return '${int.parse(durationParts[0])}秒';
  }

  static String videoItemSemantics(dynamic videoItem) {
    String semanticsLabel = "";
    bool emptyStatCheck(dynamic stat) {
      return stat == null ||
          stat == '' ||
          stat == 0 ||
          stat == '0' ||
          stat == '-';
    }

    if (videoItem.runtimeType.toString() == "RecVideoItemAppModel") {
      if (videoItem.goto == 'picture') {
        semanticsLabel += '动态,';
      } else if (videoItem.goto == 'bangumi') {
        semanticsLabel += '番剧,';
      }
    }
    if (videoItem.title is String) {
      semanticsLabel += videoItem.title;
    } else {
      semanticsLabel += videoItem.title
          .map((e) => e['text'] as String)
          .join('');
    }

    if (!emptyStatCheck(videoItem.stat.view)) {
      semanticsLabel += ',${Utils.numFormat(videoItem.stat.view)}';
      semanticsLabel +=
          (videoItem.runtimeType.toString() == "RecVideoItemAppModel" &&
              videoItem.goto == 'picture')
          ? '浏览'
          : '播放';
    }
    if (!emptyStatCheck(videoItem.stat.danmu)) {
      semanticsLabel += ',${Utils.numFormat(videoItem.stat.danmu)}弹幕';
    }
    if (videoItem.rcmdReason != null) {
      semanticsLabel += ',${videoItem.rcmdReason}';
    }
    if (!emptyStatCheck(videoItem.duration) &&
        (videoItem.duration is! int || videoItem.duration > 0)) {
      semanticsLabel +=
          ',时长${Utils.durationReadFormat(Utils.timeFormat(videoItem.duration))}';
    }
    if (videoItem.runtimeType.toString() != "RecVideoItemAppModel" &&
        videoItem.pubdate != null) {
      semanticsLabel +=
          ',${Utils.dateFormat(videoItem.pubdate!, formatType: 'day')}';
    }
    if (videoItem.owner.name != '') {
      semanticsLabel += ',Up主：${videoItem.owner.name}';
    }
    if ((videoItem.runtimeType.toString() == "RecVideoItemAppModel" ||
            videoItem.runtimeType.toString() == "RecVideoItemModel") &&
        videoItem.isFollowed == 1) {
      semanticsLabel += ',已关注';
    }
    return semanticsLabel;
  }

  static String timeFormat(dynamic time) {
    if (time is String && time.contains(':')) {
      return time;
    }
    if (time == null || time == 0) {
      return '00:00';
    }
    int hour = time ~/ 3600;
    int minute = (time % 3600) ~/ 60;
    int second = time % 60;
    String paddingStr(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${hour > 0 ? "${paddingStr(hour)}:" : ""}${paddingStr(minute)}:${paddingStr(second)}';
  }

  static String shortenChineseDateString(String date) {
    if (date.contains("年")) return '${date.split("年").first}年';
    return date;
  }

  // 完全相对时间显示
  static String formatTimestampToRelativeTime(timeStamp) {
    var difference = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000),
    );

    if (difference.inDays > 365) {
      return '${difference.inDays ~/ 365}年前';
    } else if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 时间显示，刚刚，x分钟前
  static String dateFormat(timeStamp, {formatType = 'list'}) {
    if (timeStamp == 0 || timeStamp == null || timeStamp == '') {
      return '';
    }
    // 当前时间
    int time = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    // 对比
    int distance = (time - timeStamp).toInt();
    // 当前年日期
    String currentYearStr = 'MM月DD日 hh:mm';
    String lastYearStr = 'YY年MM月DD日 hh:mm';
    if (formatType == 'detail') {
      currentYearStr = 'MM-DD hh:mm';
      lastYearStr = 'YY-MM-DD hh:mm';
      return CustomStamp_str(
        timestamp: timeStamp,
        date: lastYearStr,
        toInt: false,
      );
    } else if (formatType == 'day') {
      if (distance <= 43200) {
        return CustomStamp_str(
          timestamp: timeStamp,
          date: 'hh:mm',
          toInt: true,
        );
      }
      return CustomStamp_str(
        timestamp: timeStamp,
        date: 'YY-MM-DD',
        toInt: true,
      );
    }
    if (distance <= 60) {
      return '刚刚';
    } else if (distance <= 3600) {
      return '${(distance / 60).floor()}分钟前';
    } else if (distance <= 43200) {
      return '${(distance / 60 / 60).floor()}小时前';
    } else if (DateTime.fromMillisecondsSinceEpoch(time * 1000).year ==
        DateTime.fromMillisecondsSinceEpoch(timeStamp * 1000).year) {
      return CustomStamp_str(
        timestamp: timeStamp,
        date: currentYearStr,
        toInt: false,
      );
    } else {
      return CustomStamp_str(
        timestamp: timeStamp,
        date: lastYearStr,
        toInt: false,
      );
    }
  }

  // 时间戳转时间
  static String CustomStamp_str({
    int? timestamp, // 为空则显示当前时间
    String? date, // 显示格式，比如：'YY年MM月DD日 hh:mm:ss'
    bool toInt = true, // 去除0开头
  }) {
    timestamp ??= (DateTime.now().millisecondsSinceEpoch / 1000).round();
    String timeStr = (DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
    )).toString();

    dynamic dateArr = timeStr.split(' ')[0];
    dynamic timeArr = timeStr.split(' ')[1];

    String YY = dateArr.split('-')[0];
    String MM = dateArr.split('-')[1];
    String DD = dateArr.split('-')[2];

    String hh = timeArr.split(':')[0];
    String mm = timeArr.split(':')[1];
    String ss = timeArr.split(':')[2];

    ss = ss.split('.')[0];

    // 去除0开头
    if (toInt) {
      MM = (int.parse(MM)).toString();
      DD = (int.parse(DD)).toString();
      hh = (int.parse(hh)).toString();
      // mm = (int.parse(mm)).toString();
    }

    if (date == null) {
      return timeStr;
    }

    date = date
        .replaceAll('YY', YY)
        .replaceAll('MM', MM)
        .replaceAll('DD', DD)
        .replaceAll('hh', hh)
        .replaceAll('mm', mm)
        .replaceAll('ss', ss);
    // if (int.parse(YY) == DateTime.now().year &&
    //     int.parse(MM) == DateTime.now().month) {
    //   // 当天
    //   if (int.parse(DD) == DateTime.now().day) {
    //     return '今天';
    //   }
    // }
    return date;
  }

  static String makeHeroTag(v) {
    return v.toString() + random.nextInt(9999).toString();
  }

  static int duration(String duration) {
    List timeList = duration.split(':');
    int len = timeList.length;
    if (len == 2) {
      return int.parse(timeList[0]) * 60 + int.parse(timeList[1]);
    }
    if (len == 3) {
      return int.parse(timeList[0]) * 3600 +
          int.parse(timeList[1]) * 60 +
          int.parse(timeList[2]);
    }
    return 0;
  }

  static int findClosestNumber(int target, List<int> numbers) {
    int minDiff = 127;
    int? closestNumber;
    try {
      for (int number in numbers) {
        int diff = target - number;
        if (diff < 0) {
          continue;
        }
        if (diff < minDiff) {
          minDiff = diff;
          closestNumber = number;
        }
      }
    } catch (_) {
    } finally {
      closestNumber ??= numbers.last;
    }
    return closestNumber;
  }

  // 时间戳转时间
  static tampToSeektime(number) {
    int hours = number ~/ 60;
    int minutes = number % 60;

    String formattedHours = hours.toString().padLeft(2, '0');
    String formattedMinutes = minutes.toString().padLeft(2, '0');

    return '$formattedHours:$formattedMinutes';
  }

  // static double getSheetHeight(BuildContext context) {
  //   double height = context.height.abs();
  //   double width = context.width.abs();
  //   if (height > width) {
  //     //return height * 0.7;
  //     double paddingTop = MediaQueryData.fromView(
  //             WidgetsBinding.instance.platformDispatcher.views.single)
  //         .padding
  //         .top;
  //     print("paddingTop");
  //     print(paddingTop);
  //     paddingTop += width * 9 / 16;
  //     return height - paddingTop;
  //   }
  //   //横屏状态
  //   return height;
  // }

  static String appSign(
    Map<String, dynamic> params,
    String appkey,
    String appsec,
  ) {
    params['appkey'] = appkey;
    var searchParams = Uri(queryParameters: params).query;
    var sortedParams = searchParams.split('&')..sort();
    var sortedQueryString = sortedParams.join('&');

    var appsecString = sortedQueryString + appsec;
    var md5Digest = md5.convert(utf8.encode(appsecString));
    var md5String = md5Digest.toString(); // 获取MD5哈希值

    return md5String;
  }

  static List<int> generateRandomBytes(int minLength, int maxLength) {
    return List<int>.generate(
      random.nextInt(maxLength - minLength + 1),
      (_) => random.nextInt(0x60) + 0x20,
    );
  }

  static String base64EncodeRandomString(int minLength, int maxLength) {
    List<int> randomBytes = generateRandomBytes(minLength, maxLength);
    return base64.encode(randomBytes);
  }
}

import 'package:pilipalaz/models/video/play/quality.dart';

class PlayUrlModel {
  PlayUrlModel({
    this.from,
    this.result,
    this.message,
    this.quality,
    this.format,
    this.timeLength,
    this.acceptFormat,
    this.acceptDesc,
    this.acceptQuality,
    this.videoCodecid,
    this.seekParam,
    this.seekType,
    this.dash,
    this.supportFormats,
    // this.highFormat,
    this.lastPlayTime,
    this.lastPlayCid,
    this.isPreview = false,
    this.errorCode,
    this.isDrm = false,
  });

  String? from;
  String? result;
  String? message;
  int? quality;
  String? format;
  int? timeLength;
  String? acceptFormat;
  List<dynamic>? acceptDesc;
  List<int>? acceptQuality;
  int? videoCodecid;
  String? seekParam;
  String? seekType;
  Dash? dash;
  List<Durl>? durl;
  List<FormatItem>? supportFormats;
  // String? highFormat;
  int? lastPlayTime;
  int? lastPlayCid;
  bool isPreview = false;
  int? errorCode;
  bool isDrm = false;

  Duration? get playableDuration {
    if (durl?.isNotEmpty == true && durl!.first.length != null) {
      return Duration(milliseconds: durl!.first.length!);
    }
    if (timeLength != null) return Duration(milliseconds: timeLength!);
    return null;
  }

  PlayUrlModel.fromJson(Map<String, dynamic> json) {
    from = json['from'];
    result = json['result'];
    message = json['message'];
    quality = json['quality'];
    format = json['format'];
    timeLength = json['timelength'];
    acceptFormat = json['accept_format'];
    acceptDesc = json['accept_description'];
    acceptQuality =
        json['accept_quality']?.map<int>((e) => e as int).toList() ?? <int>[];
    videoCodecid = json['video_codecid'];
    seekParam = json['seek_param'];
    seekType = json['seek_type'];
    dash = json['dash'] != null ? Dash.fromJson(json['dash']) : null;
    durl = json['durl']?.map<Durl>((e) => Durl.fromJson(e)).toList();
    supportFormats = json['support_formats'] != null
        ? json['support_formats']
              .map<FormatItem>((e) => FormatItem.fromJson(e))
              .toList()
        : [];
    lastPlayTime = json['last_play_time'];
    lastPlayCid = json['last_play_cid'];
    isPreview = json['is_preview'] == true || json['is_preview'] == 1;
    errorCode = json['error_code'];
    isDrm = json['is_drm'] == true || json['is_drm'] == 1;
  }
}

class Dash {
  Dash({
    this.duration,
    this.minBufferTime,
    this.video,
    this.audio,
    this.dolby,
    this.flac,
  });

  int? duration;
  double? minBufferTime;
  List<VideoItem>? video;
  List<AudioItem>? audio;
  Dolby? dolby;
  Flac? flac;

  Dash.fromJson(Map<String, dynamic> json) {
    duration = json['duration'];
    minBufferTime = json['minBufferTime'] ?? json['min_buffer_time'];
    video =
        json['video']?.map<VideoItem>((e) => VideoItem.fromJson(e)).toList() ??
        <VideoItem>[];
    audio = json['audio'] != null
        ? json['audio'].map<AudioItem>((e) => AudioItem.fromJson(e)).toList()
        : [];
    dolby = json['dolby'] != null ? Dolby.fromJson(json['dolby']) : null;
    flac = json['flac'] != null ? Flac.fromJson(json['flac']) : null;
  }
}

class Durl {
  int? order;
  int? length;
  int? size;
  String? ahead;
  String? vhead;
  String? url;
  List<String>? backupUrl;

  Durl({
    this.order,
    this.length,
    this.size,
    this.ahead,
    this.vhead,
    this.url,
    this.backupUrl,
  });

  factory Durl.fromJson(Map<String, dynamic> json) {
    return Durl(
      order: json['order'],
      length: json['length'],
      size: json['size'],
      ahead: json['ahead'],
      vhead: json['vhead'],
      url: json['url'],
      backupUrl: json['backup_url'] != null
          ? List<String>.from(json['backup_url'])
          : [],
    );
  }
}

class VideoItem {
  VideoItem({
    this.id,
    this.baseUrl,
    this.backupUrl,
    this.bandWidth,
    this.mimeType,
    this.codecs,
    this.width,
    this.height,
    this.frameRate,
    this.sar,
    this.startWithSap,
    this.segmentBase,
    this.codecid,
    this.quality,
  });

  int? id;
  String? baseUrl;
  String? backupUrl;
  int? bandWidth;
  String? mimeType;
  String? codecs;
  int? width;
  int? height;
  String? frameRate;
  String? sar;
  int? startWithSap;
  Map? segmentBase;
  int? codecid;
  VideoQuality? quality;

  VideoItem.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    baseUrl = json['baseUrl'] ?? json['base_url'];
    final dynamic backups = json['backupUrl'] ?? json['backup_url'];
    backupUrl = backups != null && backups.isNotEmpty ? backups.first : '';
    bandWidth = json['bandWidth'] ?? json['bandwidth'];
    mimeType = json['mime_type'];
    codecs = json['codecs'];
    width = json['width'];
    height = json['height'];
    frameRate = json['frameRate'] ?? json['frame_rate'];
    sar = json['sar'];
    startWithSap = json['startWithSap'] ?? json['start_with_sap'];
    segmentBase = json['segmentBase'] ?? json['segment_base'];
    codecid = json['codecid'];
    quality = VideoQuality.values.firstWhere((i) => i.code == json['id']);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['baseUrl'] = baseUrl;
    data['backupUrl'] = backupUrl;
    data['bandWidth'] = bandWidth;
    data['mime_type'] = mimeType;
    data['codecs'] = codecs;
    data['width'] = width;
    data['height'] = height;
    data['frameRate'] = frameRate;
    data['sar'] = sar;
    data['startWithSap'] = startWithSap;
    data['segmentBase'] = segmentBase;
    data['codecid'] = codecid;
    data['quality'] = quality;
    return data;
  }
}

class AudioItem {
  AudioItem({
    this.id,
    this.baseUrl,
    this.backupUrl,
    this.bandWidth,
    this.mimeType,
    this.codecs,
    this.width,
    this.height,
    this.frameRate,
    this.sar,
    this.startWithSap,
    this.segmentBase,
    this.codecid,
    this.quality,
  });

  int? id;
  String? baseUrl;
  String? backupUrl;
  int? bandWidth;
  String? mimeType;
  String? codecs;
  int? width;
  int? height;
  String? frameRate;
  String? sar;
  int? startWithSap;
  Map? segmentBase;
  int? codecid;
  String? quality;

  AudioItem.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    baseUrl = json['baseUrl'] ?? json['base_url'];
    final dynamic backups = json['backupUrl'] ?? json['backup_url'];
    backupUrl = backups != null && backups.isNotEmpty ? backups.first : '';
    bandWidth = json['bandWidth'] ?? json['bandwidth'];
    mimeType = json['mime_type'];
    codecs = json['codecs'];
    width = json['width'];
    height = json['height'];
    frameRate = json['frameRate'] ?? json['frame_rate'];
    sar = json['sar'];
    startWithSap = json['startWithSap'] ?? json['start_with_sap'];
    segmentBase = json['segmentBase'] ?? json['segment_base'];
    codecid = json['codecid'];
    quality = AudioQuality.values
        .firstWhere((i) => i.code == json['id'])
        .description;
  }
}

class PgcPlaybackRestriction {
  static String messageFor({
    int? errorCode,
    bool isDrm = false,
    String? message,
  }) {
    if (isDrm) {
      return '当前内容受 DRM 保护，暂不支持在本客户端播放';
    }
    if (errorCode == -10403) {
      return '当前内容需要大会员或购买后观看，请前往哔哩哔哩官方客户端';
    }
    if (message?.contains('地区') == true || message?.contains('区域') == true) {
      return '当前地区无法播放此内容';
    }
    final String detail = message?.trim() ?? '';
    return detail.isEmpty ? '影视内容暂不可播放' : '影视内容暂不可播放：$detail';
  }
}

class FormatItem {
  FormatItem({
    this.quality,
    this.format,
    this.newDesc,
    this.displayDesc,
    this.codecs,
  });

  int? quality;
  String? format;
  String? newDesc;
  String? displayDesc;
  List? codecs;

  FormatItem.fromJson(Map<String, dynamic> json) {
    quality = json['quality'];
    format = json['format'];
    newDesc = json['new_description'];
    displayDesc = json['display_desc'];
    codecs = json['codecs'];
  }
}

class Dolby {
  Dolby({this.type, this.audio});

  // 1：普通杜比音效 2：全景杜比音效
  int? type;
  List<AudioItem>? audio;

  Dolby.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    audio = json['audio'] != null
        ? json['audio'].map<AudioItem>((e) => AudioItem.fromJson(e)).toList()
        : [];
  }
}

class Flac {
  Flac({this.display, this.audio});

  bool? display;
  AudioItem? audio;

  Flac.fromJson(Map<String, dynamic> json) {
    display = json['display'];
    audio = json['audio'] != null ? AudioItem.fromJson(json['audio']) : null;
  }
}

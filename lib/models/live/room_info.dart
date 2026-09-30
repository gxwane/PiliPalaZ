class RoomInfoModel {
  RoomInfoModel({
    this.roomId,
    this.liveStatus,
    this.liveTime,
    this.playurlInfo,
  });
  int? roomId;
  int? liveStatus;
  int? liveTime;
  PlayurlInfo? playurlInfo;

  RoomInfoModel.fromJson(Map<String, dynamic> json) {
    roomId = json['room_id'];
    liveStatus = json['live_status'];
    liveTime = json['live_time'];
    playurlInfo = json['playurl_info'] != null
        ? PlayurlInfo.fromJson(json['playurl_info'])
        : null;
  }
}

class PlayurlInfo {
  PlayurlInfo({this.playurl});

  Playurl? playurl;

  PlayurlInfo.fromJson(Map<String, dynamic> json) {
    playurl = json['playurl'] != null
        ? Playurl.fromJson(json['playurl'])
        : null;
  }
}

class Playurl {
  Playurl({this.cid, this.gQnDesc, this.stream});

  int? cid;
  List<GQnDesc>? gQnDesc;
  List<Streams>? stream;

  Playurl.fromJson(Map<String, dynamic> json) {
    cid = json['cid'];
    final dynamic gQnDescList = json['g_qn_desc'];
    gQnDesc = gQnDescList is List
        ? gQnDescList
              .whereType<Map<String, dynamic>>()
              .map<GQnDesc>((e) => GQnDesc.fromJson(e))
              .toList()
        : <GQnDesc>[];
    final dynamic streamList = json['stream'];
    stream = streamList is List
        ? streamList
              .whereType<Map<String, dynamic>>()
              .map<Streams>((e) => Streams.fromJson(e))
              .toList()
        : <Streams>[];
  }
}

class GQnDesc {
  GQnDesc({this.qn, this.desc, this.hdrDesc, this.attrDesc});

  int? qn;
  String? desc;
  String? hdrDesc;
  String? attrDesc;

  GQnDesc.fromJson(Map<String, dynamic> json) {
    qn = json['qn'];
    desc = json['desc'];
    hdrDesc = json['hdr_desc'] ?? json['hedr_desc'];
    attrDesc = json['attr_desc'];
  }
}

class Streams {
  Streams({this.protocolName, this.format});

  String? protocolName;
  List<FormatItem>? format;

  Streams.fromJson(Map<String, dynamic> json) {
    protocolName = json['protocol_name'];
    final dynamic formatList = json['format'];
    format = formatList is List
        ? formatList
              .whereType<Map<String, dynamic>>()
              .map<FormatItem>((e) => FormatItem.fromJson(e))
              .toList()
        : <FormatItem>[];
  }
}

class FormatItem {
  FormatItem({this.formatName, this.codec});

  String? formatName;
  List<CodecItem>? codec;

  FormatItem.fromJson(Map<String, dynamic> json) {
    formatName = json['format_name'];
    final dynamic codecList = json['codec'];
    codec = codecList is List
        ? codecList
              .whereType<Map<String, dynamic>>()
              .map<CodecItem>((e) => CodecItem.fromJson(e))
              .toList()
        : <CodecItem>[];
  }
}

class CodecItem {
  CodecItem({
    this.codecName,
    this.currentQn,
    this.acceptQn,
    this.baseUrl,
    this.urlInfo,
    this.hdrQn,
    this.dolbyType,
    this.attrName,
  });

  String? codecName;
  int? currentQn;
  List? acceptQn;
  String? baseUrl;
  List<UrlInfoItem>? urlInfo;
  String? hdrQn;
  int? dolbyType;
  String? attrName;

  CodecItem.fromJson(Map<String, dynamic> json) {
    codecName = json['codec_name'];
    currentQn = json['current_qn'];
    acceptQn = json['accept_qn'] is List ? (json['accept_qn'] as List) : null;
    baseUrl = json['base_url'];
    final dynamic urlInfoList = json['url_info'];
    urlInfo = urlInfoList is List
        ? urlInfoList
              .whereType<Map<String, dynamic>>()
              .map<UrlInfoItem>((e) => UrlInfoItem.fromJson(e))
              .toList()
        : <UrlInfoItem>[];
    hdrQn = (json['hdr_qn'] ?? json['hdr_n'])?.toString();
    dolbyType = json['dolby_type'];
    attrName = json['attr_name'];
  }
}

class UrlInfoItem {
  UrlInfoItem({this.host, this.extra, this.streamTtl});

  String? host;
  String? extra;
  int? streamTtl;

  UrlInfoItem.fromJson(Map<String, dynamic> json) {
    host = json['host'];
    extra = json['extra'];
    streamTtl = json['stream_ttl'];
  }
}

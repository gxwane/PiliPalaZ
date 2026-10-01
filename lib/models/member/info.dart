class MemberInfoModel {
  MemberInfoModel({this.card, this.liveRoom});

  Card? card;
  LiveRoom? liveRoom;

  MemberInfoModel.fromJson(Map<String, dynamic> json) {
    card = json['card'] != null && json['card'] is Map<String, dynamic>
        ? Card.fromJson(json['card'])
        : (json['card'] is Map
              ? Card.fromJson(Map<String, dynamic>.from(json['card']))
              : null);
    final rawLive =
        json['live'] ??
        json['live_room'] ??
        json['liveRoom'] ??
        (json['card'] is Map
            ? (json['card']['live_room'] ?? json['card']['live'])
            : null);
    if (rawLive is Map<String, dynamic>) {
      liveRoom = LiveRoom.fromJson(rawLive);
    } else if (rawLive is Map) {
      liveRoom = LiveRoom.fromJson(Map<String, dynamic>.from(rawLive));
    }
  }
}

class Card {
  Card({
    this.mid,
    this.name,
    this.face,
    this.sign,
    this.level,
    this.isFollow,
    this.isFollowed,
    this.relationStatus,
    this.officialVerify,
    this.professionVerify,
    this.vip,
    this.fans,
    this.attention,
    this.likes,
    // this.liveRoom,
  });

  String? mid;
  String? name;
  String? face;
  String? sign;
  int? level;
  bool? isFollow;
  bool? isFollowed;
  int? relationStatus;
  Map? officialVerify;
  Map? professionVerify;
  Vip? vip;
  int? fans;
  int? attention;
  int? likes;
  // LiveRoom? liveRoom;

  Card.fromJson(Map<String, dynamic> json) {
    mid = json['mid'];
    name = json['name'];
    face = json['face'];
    sign = (json['sign'] == null || json['sign'] == '')
        ? '该用户还没有签名'
        : json['sign'].toString().replaceAll('\n', '');
    level = json['level_info']?['level'] ?? 0;

    isFollow = json['relation']?['is_follow'] == 1;
    isFollowed = json['relation']?['is_followed'] == 1;
    relationStatus = json['relation']?['status'] ?? 0;
    officialVerify = json['official_verify'];
    professionVerify = json['profession_verify'];
    vip = json['vip'] != null && json['vip'] is Map<String, dynamic>
        ? Vip.fromJson(json['vip'])
        : (json['vip'] is Map
              ? Vip.fromJson(Map<String, dynamic>.from(json['vip']))
              : null);

    fans = json['fans'];
    attention = json['attention'];
    likes = json['likes']?['like_num'];
    // liveRoom =
    //     json['live_room'] != null ? LiveRoom.fromJson(json['live_room']) : null;
  }
}

class Vip {
  Vip({this.type, this.status, this.dueDate, this.label});

  int? type;
  int? status;
  int? dueDate;
  Map? label;

  Vip.fromJson(Map<String, dynamic> json) {
    type = json['vipType'];
    status = json['vipStatus'];
    dueDate = json['vipDueDate'];
    label = json['label'];
  }
}

class LiveRoom {
  LiveRoom({
    this.roomStatus,
    this.liveStatus,
    this.url,
    this.title,
    this.cover,
    this.roomId,
    this.roundStatus,
  });

  int? roomStatus;
  int? liveStatus;
  String? url;
  String? title;
  String? cover;
  int? roomId;
  int? roundStatus;

  LiveRoom.fromJson(Map<String, dynamic> json) {
    roomStatus =
        int.tryParse(json['roomStatus']?.toString() ?? '') ??
        int.tryParse(json['room_status']?.toString() ?? '');
    final rawLiveStatus =
        json['liveStatus'] ?? json['live_status'] ?? json['live'];
    if (rawLiveStatus is bool) {
      liveStatus = rawLiveStatus ? 1 : 0;
    } else {
      liveStatus = int.tryParse(rawLiveStatus?.toString() ?? '');
    }
    url = json['url']?.toString();
    title = json['title']?.toString();
    cover = (json['cover'] ?? json['user_cover'] ?? json['keyframe'])
        ?.toString();
    roomId =
        int.tryParse(json['roomid']?.toString() ?? '') ??
        int.tryParse(json['room_id']?.toString() ?? '') ??
        int.tryParse(json['roomId']?.toString() ?? '');
    roundStatus =
        int.tryParse(json['roundStatus']?.toString() ?? '') ??
        int.tryParse(json['round_status']?.toString() ?? '');
  }
}

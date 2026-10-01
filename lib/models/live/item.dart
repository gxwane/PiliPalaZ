import '../search/result.dart';

class LiveItemModel {
  LiveItemModel({
    this.roomId,
    this.uid,
    this.title,
    this.uname,
    this.online,
    this.userCover,
    this.userCoverFlag,
    this.systemCover,
    this.cover,
    this.pic,
    this.link,
    this.face,
    this.parentId,
    this.parentName,
    this.areaId,
    this.areaName,
    this.sessionId,
    this.groupId,
    this.pkId,
    this.verify,
    this.headBox,
    this.headBoxType,
    this.watchedShow,
    this.liveStatus,
  });

  int? roomId;
  int? uid;
  String? title;
  String? uname;
  int? online;
  String? userCover;
  int? userCoverFlag;
  String? systemCover;
  String? cover;
  String? pic;
  String? link;
  String? face;
  int? parentId;
  String? parentName;
  int? areaId;
  String? areaName;
  String? sessionId;
  int? groupId;
  int? pkId;
  Map? verify;
  Map? headBox;
  int? headBoxType;
  Map? watchedShow;
  int? liveStatus;

  /// 是否正在真人实时直播
  bool get isLive => liveStatus == 1;

  /// 是否为录播轮播
  bool get isRoundRobin => liveStatus == 2;

  /// 是否未开播
  bool get isOffline => liveStatus == 0 || liveStatus == null;

  LiveItemModel.fromJson(Map<String, dynamic> json) {
    roomId = json['roomid'] ?? json['room_id'];
    uid = json['uid'] ?? json['mid'];
    title = json['title'];
    uname = json['uname'] ?? json['nickname'];
    online = json['online'];
    final rawStatus =
        json['live_status'] ?? json['liveStatus'] ?? json['is_live'];
    if (rawStatus is int) {
      liveStatus = rawStatus;
    } else if (rawStatus is String) {
      liveStatus = int.tryParse(rawStatus);
    } else if (rawStatus is bool) {
      liveStatus = rawStatus ? 1 : 0;
    } else {
      liveStatus = null;
    }
    userCover = json['user_cover'] ?? json['keyframe'];
    userCoverFlag = json['user_cover_flag'];
    systemCover = json['system_cover'];
    cover =
        json['cover'] ??
        json['keyframe'] ??
        json['user_cover'] ??
        json['system_cover'];
    pic = cover;
    link = json['link'];
    face = json['face'] ?? json['user_face'] ?? json['avatar'];
    parentId =
        json['parent_id'] ??
        json['area_v2_parent_id'] ??
        json['parent_area_id'];
    parentName =
        json['parent_name'] ??
        json['area_v2_parent_name'] ??
        json['parent_area_name'];
    areaId = json['area_id'] ?? json['area_v2_id'];
    areaName = json['area_name'] ?? json['area_v2_name'];
    sessionId = json['session_id'];
    groupId = json['group_id'];
    pkId = json['pk_id'];
    verify = json['verify'];
    headBox = json['head_box'];
    headBoxType = json['head_box_type'];
    watchedShow = json['watched_show'];
  }

  /// 多态反序列化防御层：安全解构 LiveItemModel、SearchLiveItemModel、Map 及任意动态种子
  static LiveItemModel? fromDynamic(dynamic raw) {
    if (raw == null) return null;
    if (raw is LiveItemModel) return raw;
    if (raw is SearchLiveItemModel) {
      String? parsedTitle;
      if (raw.title != null) {
        parsedTitle = raw.title!
            .map((e) => e is Map ? (e['text']?.toString() ?? '') : e.toString())
            .join();
      }
      return LiveItemModel(
        roomId: raw.roomid,
        uid: raw.uid,
        title: parsedTitle,
        uname: raw.uname,
        cover: raw.cover ?? raw.userCover ?? raw.pic,
        pic: raw.cover ?? raw.userCover ?? raw.pic,
        face: raw.face ?? raw.uface,
        areaName: raw.cateName,
        online: raw.online,
        liveStatus: 1,
      );
    }
    if (raw is Map<String, dynamic>) {
      try {
        return LiveItemModel.fromJson(raw);
      } catch (_) {}
    }
    if (raw is Map) {
      try {
        return LiveItemModel.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {}
    }
    try {
      final dyn = raw as dynamic;
      dynamic getProp(dynamic Function() getter) {
        try {
          return getter();
        } catch (_) {
          return null;
        }
      }

      final rawTitle = getProp(() => dyn.title);
      String? parsedTitle;
      if (rawTitle is String) {
        parsedTitle = rawTitle;
      } else if (rawTitle is List) {
        parsedTitle = rawTitle
            .map((e) => e is Map ? (e['text']?.toString() ?? '') : e.toString())
            .join();
      }
      final rawRoomId = getProp(() => dyn.roomId) ?? getProp(() => dyn.roomid);
      final parsedRoomId = int.tryParse(rawRoomId?.toString() ?? '');
      final rawUid = getProp(() => dyn.uid) ?? getProp(() => dyn.mid);
      final parsedUid = int.tryParse(rawUid?.toString() ?? '');
      final parsedCover =
          (getProp(() => dyn.cover) ??
                  getProp(() => dyn.userCover) ??
                  getProp(() => dyn.pic))
              ?.toString();
      final parsedFace =
          (getProp(() => dyn.face) ??
                  getProp(() => dyn.uface) ??
                  getProp(() => dyn.upic))
              ?.toString();
      final parsedUname = (getProp(() => dyn.uname) ?? getProp(() => dyn.name))
          ?.toString();
      final parsedAreaName =
          (getProp(() => dyn.cateName) ?? getProp(() => dyn.areaName))
              ?.toString();
      final rawOnline = getProp(() => dyn.online);
      final parsedOnline = int.tryParse(rawOnline?.toString() ?? '');
      final rawLiveStatus =
          getProp(() => dyn.liveStatus) ?? getProp(() => dyn.isLive);
      final parsedLiveStatus = int.tryParse(rawLiveStatus?.toString() ?? '');

      if (parsedRoomId != null && parsedRoomId > 0) {
        return LiveItemModel(
          roomId: parsedRoomId,
          uid: parsedUid,
          title: parsedTitle,
          uname: parsedUname,
          cover: parsedCover,
          pic: parsedCover,
          face: parsedFace,
          areaName: parsedAreaName,
          online: parsedOnline,
          liveStatus: parsedLiveStatus ?? 1,
        );
      }
    } catch (_) {}
    return null;
  }
}

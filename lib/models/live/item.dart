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

  LiveItemModel.fromJson(Map<String, dynamic> json) {
    roomId = json['roomid'] ?? json['room_id'];
    uid = json['uid'] ?? json['mid'];
    title = json['title'];
    uname = json['uname'] ?? json['nickname'];
    online = json['online'];
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
}

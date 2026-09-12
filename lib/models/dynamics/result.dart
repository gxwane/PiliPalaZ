import 'dart:convert';

import 'package:flutter/foundation.dart';

class DynamicsDataModel {
  DynamicsDataModel({this.hasMore, this.items, this.offset});
  bool? hasMore;
  List<DynamicItemModel>? items;
  String? offset;

  DynamicsDataModel.fromJson(Map<String, dynamic> json) {
    hasMore = _parseBool(json['has_more']);
    final rawItems = json['items'];
    if (rawItems is List) {
      final parsedItems = <DynamicItemModel>[];
      for (final raw in rawItems) {
        final itemMap = _parseMap(raw);
        if (itemMap == null) {
          if (kDebugMode) {
            debugPrint('DynamicsDataModel: Skipped non-map dynamic item: $raw');
          }
          continue;
        }
        try {
          parsedItems.add(DynamicItemModel.fromJson(itemMap));
        } catch (err, stack) {
          if (kDebugMode) {
            debugPrint(
              'DynamicsDataModel: Failed to parse dynamic item: $err\n$stack',
            );
          }
        }
      }
      items = parsedItems;
    } else {
      items = <DynamicItemModel>[];
    }
    offset = _parseString(json['offset']);
  }
}

// 单个动态
class DynamicItemModel {
  DynamicItemModel({
    this.basic,
    this.idStr,
    this.modules,
    this.orig,
    this.type,
    this.visible,
  });

  Map? basic;
  String? idStr;
  ItemModulesModel? modules;
  ItemOrigModel? orig;
  String? type;
  bool? visible;

  DynamicItemModel.fromJson(Map<String, dynamic> json) {
    basic = _parseMap(json['basic']);
    idStr = _parseString(json['id_str']);
    final modulesMap = _parseMap(json['modules']);
    modules = modulesMap != null ? ItemModulesModel.fromJson(modulesMap) : null;
    final origMap = _parseMap(json['orig']);
    orig = origMap != null ? ItemOrigModel.fromJson(origMap) : null;
    type = _parseString(json['type']);
    visible = _parseBool(json['visible']);
  }
}

class ItemOrigModel {
  ItemOrigModel({
    this.basic,
    this.isStr,
    this.modules,
    this.type,
    this.visible,
  });

  Map? basic;
  String? isStr;
  ItemModulesModel? modules;
  String? type;
  bool? visible;

  ItemOrigModel.fromJson(Map<String, dynamic> json) {
    basic = _parseMap(json['basic']);
    isStr = _parseString(json['is_str']);
    final modulesMap = _parseMap(json['modules']);
    modules = modulesMap != null ? ItemModulesModel.fromJson(modulesMap) : null;
    type = _parseString(json['type']);
    visible = _parseBool(json['visible']);
  }
}

// 单个动态详情
class ItemModulesModel {
  ItemModulesModel({
    this.moduleAuthor,
    this.moduleDynamic,
    // this.moduleInter,
    this.moduleStat,
    this.moduleTag,
  });

  ModuleAuthorModel? moduleAuthor;
  ModuleDynamicModel? moduleDynamic;
  // ModuleInterModel? moduleInter;
  ModuleStatModel? moduleStat;
  Map? moduleTag;

  ItemModulesModel.fromJson(Map<String, dynamic> json) {
    final authorMap = _parseMap(json['module_author']);
    moduleAuthor = authorMap != null
        ? ModuleAuthorModel.fromJson(authorMap)
        : null;
    final dynamicMap = _parseMap(json['module_dynamic']);
    moduleDynamic = dynamicMap != null
        ? ModuleDynamicModel.fromJson(dynamicMap)
        : null;
    // moduleInter = ModuleInterModel.fromJson(json['module_interaction']);
    final statMap = _parseMap(json['module_stat']);
    moduleStat = statMap != null ? ModuleStatModel.fromJson(statMap) : null;
    moduleTag = _parseMap(json['module_tag']);
  }
}

// 单个动态详情 - 作者信息
class ModuleAuthorModel {
  ModuleAuthorModel({
    // this.avatar,
    // this.decorate,
    this.face,
    this.following,
    this.jumpUrl,
    this.label,
    this.mid,
    this.name,
    // this.officialVerify,
    // this.pandant,
    this.pubAction,
    // this.pubLocationText,
    this.pubTime,
    this.pubTs,
    this.type,
    this.vip,
  });

  String? face;
  bool? following;
  String? jumpUrl;
  String? label;
  int? mid;
  String? name;
  String? pubAction;
  String? pubTime;
  int? pubTs;
  String? type;
  Map? vip;

  ModuleAuthorModel.fromJson(Map<String, dynamic> json) {
    face = _parseString(json['face']);
    following = _parseBool(json['following']);
    jumpUrl = _parseString(json['jump_url']);
    label = _parseString(json['label']);
    mid = _parseInt(json['mid']);
    name = _parseString(json['name']);
    pubAction = _parseString(json['pub_action']);
    pubTime = _parseString(json['pub_time']);
    pubTs = _parseInt(json['pub_ts']) == 0 ? null : _parseInt(json['pub_ts']);
    type = _parseString(json['type']);
    vip = _parseMap(json['vip']);
  }
}

// 单个动态详情 - 动态信息
class ModuleDynamicModel {
  ModuleDynamicModel({this.additional, this.desc, this.major, this.topic});

  DynamicAddModel? additional;
  DynamicDescModel? desc;
  DynamicMajorModel? major;
  DynamicTopicModel? topic;

  ModuleDynamicModel.fromJson(Map<String, dynamic> json) {
    final addMap = _parseMap(json['additional']);
    additional = addMap != null ? DynamicAddModel.fromJson(addMap) : null;
    final descMap = _parseMap(json['desc']);
    desc = descMap != null ? DynamicDescModel.fromJson(descMap) : null;
    final majorMap = _parseMap(json['major']);
    major = majorMap != null ? DynamicMajorModel.fromJson(majorMap) : null;
    final topicMap = _parseMap(json['topic']);
    topic = topicMap != null ? DynamicTopicModel.fromJson(topicMap) : null;
  }
}

// 单个动态详情 - 评论？信息
// class ModuleInterModel {
//   ModuleInterModel({

//   });

//   ModuleInterModel.fromJson(Map<String, dynamic> json) {

//   }
// }
class DynamicAddModel {
  DynamicAddModel({this.type, this.vote, this.ugc, this.reserve, this.goods});

  String? type;
  Vote? vote;
  Ugc? ugc;
  Reserve? reserve;
  Good? goods;

  /// TODO 比赛vs
  String? match;

  /// TODO 游戏信息
  String? common;

  DynamicAddModel.fromJson(Map<String, dynamic> json) {
    type = _parseString(json['type']);
    final voteMap = _parseMap(json['vote']);
    vote = voteMap != null ? Vote.fromJson(voteMap) : null;
    final ugcMap = _parseMap(json['ugc']);
    ugc = ugcMap != null ? Ugc.fromJson(ugcMap) : null;
    final reserveMap = _parseMap(json['reserve']);
    reserve = reserveMap != null ? Reserve.fromJson(reserveMap) : null;
    final goodsMap = _parseMap(json['goods']);
    goods = goodsMap != null ? Good.fromJson(goodsMap) : null;
  }
}

class Vote {
  Vote({
    this.choiceCnt,
    this.defaultShare,
    this.share,
    this.endTime,
    this.joinNum,
    this.status,
    this.type,
    this.uid,
    this.voteId,
  });

  int? choiceCnt;
  String? share;
  int? defaultShare;
  int? endTime;
  int? joinNum;
  int? status;
  int? type;
  int? uid;
  int? voteId;

  Vote.fromJson(Map<String, dynamic> json) {
    choiceCnt = _parseInt(json['choice_cnt']);
    share = _parseString(json['share']);
    defaultShare = _parseInt(json['default_share']);
    endTime = _parseInt(json['end_time']);
    joinNum = _parseInt(json['join_num']);
    status = _parseInt(json['status']);
    type = _parseInt(json['type']);
    uid = _parseInt(json['uid']);
    voteId = _parseInt(json['vote_id']);
  }
}

class Ugc {
  Ugc({
    this.cover,
    this.descSecond,
    this.duration,
    this.headText,
    this.idStr,
    this.jumpUrl,
    this.multiLine,
    this.title,
  });

  String? cover;
  String? descSecond;
  String? duration;
  String? headText;
  String? idStr;
  String? jumpUrl;
  bool? multiLine;
  String? title;

  Ugc.fromJson(Map<String, dynamic> json) {
    cover = _parseString(json['cover']);
    descSecond = _parseString(json['desc_second']);
    duration = _parseString(json['duration']);
    headText = _parseString(json['head_text']);
    idStr = _parseString(json['id_str']);
    jumpUrl = _parseString(json['jump_url']);
    multiLine = _parseBool(json['multi_line']);
    title = _parseString(json['title']);
  }
}

class Reserve {
  Reserve({
    this.button,
    this.desc1,
    this.desc2,
    this.jumpUrl,
    this.reserveTotal,
    this.rid,
    this.state,
    this.stype,
    this.title,
    this.upMid,
  });

  Map? button;
  Map? desc1;
  Map? desc2;
  String? jumpUrl;
  int? reserveTotal;
  int? rid;
  int? state;
  int? stype;
  String? title;
  int? upMid;

  Reserve.fromJson(Map<String, dynamic> json) {
    button = _parseMap(json['button']);
    desc1 = _parseMap(json['desc1']);
    desc2 = _parseMap(json['desc2']);
    jumpUrl = _parseString(json['jump_url']);
    reserveTotal = _parseInt(json['reserve_total']);
    rid = _parseInt(json['rid']);
    state = _parseInt(json['state']);
    stype = _parseInt(json['stype']);
    title = _parseString(json['title']);
    upMid = _parseInt(json['up_mid']);
  }
}

class Good {
  Good({this.headIcon, this.headText, this.items, this.jumpUrl});

  String? headIcon;
  String? headText;
  List<GoodItem>? items;
  String? jumpUrl;

  Good.fromJson(Map<String, dynamic> json) {
    headIcon = _parseString(json['head_icon']);
    headText = _parseString(json['head_text']);
    final rawGoods = json['items'];
    if (rawGoods is List) {
      items = rawGoods
          .whereType<Map>()
          .map<GoodItem>((e) => GoodItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      items = <GoodItem>[];
    }
    jumpUrl = _parseString(json['jump_url']);
  }
}

class GoodItem {
  GoodItem({
    this.brief,
    this.cover,
    this.id,
    this.jumpDesc,
    this.jumpUrl,
    this.name,
    this.price,
  });

  String? brief;
  String? cover;
  dynamic id;
  String? jumpDesc;
  String? jumpUrl;
  String? name;
  String? price;

  GoodItem.fromJson(Map<String, dynamic> json) {
    brief = _parseString(json['brief']);
    cover = _parseString(json['cover']);
    id = json['id'];
    jumpDesc = _parseString(json['jump_desc']);
    jumpUrl = _parseString(json['jump_url']);
    name = _parseString(json['name']);
    price = _parseString(json['price']);
  }
}

class DynamicDescModel {
  DynamicDescModel({this.richTextNodes, this.text});

  List<RichTextNodeItem>? richTextNodes;
  String? text;

  DynamicDescModel.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['rich_text_nodes'];
    if (rawNodes is List) {
      richTextNodes = rawNodes
          .whereType<Map>()
          .map<RichTextNodeItem>(
            (e) => RichTextNodeItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } else {
      richTextNodes = [];
    }
    text = _parseString(json['text']);
  }
}

//
class DynamicMajorModel {
  DynamicMajorModel({
    this.archive,
    this.draw,
    this.ugcSeason,
    this.opus,
    this.pgc,
    this.liveRcmd,
    this.live,
    this.none,
    this.type,
    this.courses,
  });

  DynamicArchiveModel? archive;
  DynamicDrawModel? draw;
  DynamicArchiveModel? ugcSeason;
  DynamicOpusModel? opus;
  DynamicArticleModel? article;
  DynamicArchiveModel? pgc;
  DynamicLiveModel? liveRcmd;
  DynamicLive2Model? live;
  DynamicNoneModel? none;
  DynamicCommonModel? common;
  // MAJOR_TYPE_DRAW 图片
  // MAJOR_TYPE_ARCHIVE 视频
  // MAJOR_TYPE_OPUS 图文/文章
  String? type;
  Map? courses;

  DynamicMajorModel.fromJson(Map<String, dynamic> json) {
    final archiveMap = _parseMap(json['archive']);
    archive = archiveMap != null
        ? DynamicArchiveModel.fromJson(archiveMap)
        : null;
    final drawMap = _parseMap(json['draw']);
    draw = drawMap != null ? DynamicDrawModel.fromJson(drawMap) : null;
    final ugcSeasonMap = _parseMap(json['ugc_season']);
    ugcSeason = ugcSeasonMap != null
        ? DynamicArchiveModel.fromJson(ugcSeasonMap)
        : null;
    final opusMap = _parseMap(json['opus']);
    opus = opusMap != null ? DynamicOpusModel.fromJson(opusMap) : null;
    final articleMap = _parseMap(json['article']);
    article = articleMap != null
        ? DynamicArticleModel.fromJson(articleMap)
        : null;
    final pgcMap = _parseMap(json['pgc']);
    pgc = pgcMap != null ? DynamicArchiveModel.fromJson(pgcMap) : null;
    final liveRcmdMap = _parseMap(json['live_rcmd']);
    liveRcmd = liveRcmdMap != null
        ? DynamicLiveModel.fromJson(liveRcmdMap)
        : null;
    final liveMap = _parseMap(json['live']);
    live = liveMap != null ? DynamicLive2Model.fromJson(liveMap) : null;
    final commonMap = _parseMap(json['common']);
    common = commonMap != null ? DynamicCommonModel.fromJson(commonMap) : null;
    final noneMap = _parseMap(json['none']);
    none = noneMap != null ? DynamicNoneModel.fromJson(noneMap) : null;
    type = _parseString(json['type']);
    courses = _parseMap(json['courses']) ?? {};
  }
}

class DynamicTopicModel {
  DynamicTopicModel({this.id, this.jumpUrl, this.name});

  int? id;
  String? jumpUrl;
  String? name;

  DynamicTopicModel.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    jumpUrl = _parseString(json['jump_url']);
    name = _parseString(json['name']);
  }
}

class DynamicArchiveModel {
  DynamicArchiveModel({
    this.aid,
    this.badge,
    this.bvid,
    this.cover,
    this.desc,
    this.disablePreview,
    this.durationText,
    this.jumpUrl,
    this.stat,
    this.title,
    this.type,
    this.epid,
    this.seasonId,
  });

  int? aid;
  Map? badge;
  String? bvid;
  String? cover;
  String? desc;
  int? disablePreview;
  String? durationText;
  String? jumpUrl;
  Stat? stat;
  String? title;
  int? type;
  int? epid;
  int? seasonId;

  static int _fallbackIdCounter = 0;

  DynamicArchiveModel.fromJson(Map<String, dynamic> json) {
    aid = _parseInt(json['aid']);
    badge = _parseMap(json['badge']);
    _fallbackIdCounter++;
    bvid =
        json['bvid'] ??
        json['epid']?.toString() ??
        'fallback_bvid_$_fallbackIdCounter';
    cover = _parseString(json['cover']);
    disablePreview = _parseInt(json['disable_preview']);
    durationText = _parseString(json['duration_text']);
    jumpUrl = _parseString(json['jump_url']);
    final statMap = _parseMap(json['stat']);
    stat = statMap != null ? Stat.fromJson(statMap) : null;
    title = _parseString(json['title']);
    type = _parseInt(json['type']);
    epid = _parseInt(json['epid']);
    seasonId = _parseInt(json['season_id']);
  }
}

class DynamicDrawModel {
  DynamicDrawModel({this.id, this.items});

  int? id;
  List<DynamicDrawItemModel>? items;

  DynamicDrawModel.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    final rawItems = json['items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map<DynamicDrawItemModel>(
            (e) => DynamicDrawItemModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } else {
      items = null;
    }
  }
}

class DynamicOpusModel {
  DynamicOpusModel({this.jumpUrl, this.pics, this.summary, this.title});

  String? jumpUrl;
  List<OpusPicsModel>? pics;
  SummaryModel? summary;
  String? title;
  DynamicOpusModel.fromJson(Map<String, dynamic> json) {
    jumpUrl = _parseString(json['jump_url']);
    final rawPics = json['pics'];
    if (rawPics is List) {
      pics = rawPics
          .whereType<Map>()
          .map<OpusPicsModel>(
            (e) => OpusPicsModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } else {
      pics = [];
    }
    final summaryMap = _parseMap(json['summary']);
    summary = summaryMap != null ? SummaryModel.fromJson(summaryMap) : null;
    title = _parseString(json['title']);
  }
}

class DynamicArticleModel {
  DynamicArticleModel({
    this.covers,
    this.desc,
    this.id,
    this.jumpUrl,
    this.label,
    this.title,
  });

  List<String>? covers;
  String? desc;
  int? id;
  String? jumpUrl;
  String? label;
  String? title;

  DynamicArticleModel.fromJson(Map<String, dynamic> json) {
    final rawCovers = json['covers'];
    if (rawCovers is List) {
      covers = rawCovers
          .map((e) => _parseString(e) ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      covers = [];
    }
    desc = _parseString(json['desc']);
    id = _parseInt(json['id']);
    jumpUrl = _parseString(json['jump_url']);
    label = _parseString(json['label']);
    title = _parseString(json['title']);
  }
}

class DynamicCommonModel {
  DynamicCommonModel({
    this.badge,
    this.jumpUrl,
    this.cover,
    this.label,
    this.desc,
    this.id,
    this.sketchId,
    this.style,
    this.title,
  });

  Map? badge;
  String? jumpUrl;
  String? cover;
  String? label;
  String? desc;
  String? id;
  String? sketchId;
  int? style;
  String? title;

  DynamicCommonModel.fromJson(Map<String, dynamic> json) {
    badge = _parseMap(json['badge']);
    jumpUrl = _parseString(json['jump_url']);
    cover = _parseString(json['cover']);
    label = _parseString(json['label']);
    desc = _parseString(json['desc']);
    id = _parseString(json['id']);
    sketchId = _parseString(json['sketch_id']);
    style = _parseInt(json['style']);
    title = _parseString(json['title']);
  }
}

class SummaryModel {
  SummaryModel({this.richTextNodes, this.text});

  List<RichTextNodeItem>? richTextNodes;
  String? text;

  SummaryModel.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['rich_text_nodes'];
    if (rawNodes is List) {
      richTextNodes = rawNodes
          .whereType<Map>()
          .map<RichTextNodeItem>(
            (e) => RichTextNodeItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } else {
      richTextNodes = [];
    }
    text = _parseString(json['text']);
  }
}

class RichTextNodeItem {
  RichTextNodeItem({this.emoji, this.origText, this.text, this.type, this.rid});
  Emoji? emoji;
  String? origText;
  String? text;
  String? type;
  String? rid;

  RichTextNodeItem.fromJson(Map<String, dynamic> json) {
    final emojiMap = _parseMap(json['emoji']);
    emoji = emojiMap != null ? Emoji.fromJson(emojiMap) : null;
    origText = _parseString(json['orig_text']);
    text = _parseString(json['text']);
    type = _parseString(json['type']);
    rid = _parseString(json['rid']);
  }
}

class Emoji {
  Emoji({this.iconUrl, this.size, this.text, this.type});

  String? iconUrl;
  double? size;
  String? text;
  int? type;
  Emoji.fromJson(Map<String, dynamic> json) {
    iconUrl = _parseString(json['icon_url']);
    size = _parseDouble(json['size']);
    text = _parseString(json['text']);
    type = _parseInt(json['type']);
  }
}

class DynamicNoneModel {
  DynamicNoneModel({this.tips});
  String? tips;
  DynamicNoneModel.fromJson(Map<String, dynamic> json) {
    tips = _parseString(json['tips']);
  }
}

class OpusPicsModel {
  OpusPicsModel({this.width, this.height, this.size, this.src, this.url});

  int? width;
  int? height;
  int? size;
  String? src;
  String? url;

  OpusPicsModel.fromJson(Map<String, dynamic> json) {
    width = _parseInt(json['width']);
    height = _parseInt(json['height']);
    size = _parseInt(json['size']) ?? 0;
    src = _parseString(json['src']);
    url = _parseString(json['url']);
  }
}

class DynamicDrawItemModel {
  DynamicDrawItemModel({
    this.height,
    this.size,
    this.src,
    this.tags,
    this.width,
  });
  int? height;
  int? size;
  String? src;
  List? tags;
  int? width;
  DynamicDrawItemModel.fromJson(Map<String, dynamic> json) {
    height = _parseInt(json['height']);
    size = _parseInt(json['size']);
    src = _parseString(json['src']);
    tags = _parseList(json['tags']);
    width = _parseInt(json['width']);
  }
}

class DynamicLiveModel {
  DynamicLiveModel({this.content});

  String? content;
  int? type;
  Map? livePlayInfo;
  int? uid;
  String? parentAreaName;
  int? roomId;
  String? liveId;
  int? liveStatus;
  String? cover;
  int? online;
  String? areaName;
  String? title;
  int? liveStartTime;
  Map? watchedShow;

  DynamicLiveModel.fromJson(Map<String, dynamic> json) {
    content = _parseString(json['content']);
    if (content != null && content!.isNotEmpty) {
      try {
        final decoded = jsonDecode(content!);
        final data = _parseMap(decoded);
        if (data != null) {
          type = _parseInt(data['type']);
          final livePlayInfo = _parseMap(data['live_play_info']);
          if (livePlayInfo != null) {
            this.livePlayInfo = livePlayInfo;
            uid = _parseInt(livePlayInfo['uid']);
            parentAreaName = _parseString(livePlayInfo['parent_area_name']);
            roomId = _parseInt(livePlayInfo['room_id']);
            liveId = _parseString(livePlayInfo['live_id']);
            liveStatus = _parseInt(livePlayInfo['live_status']);
            cover = _parseString(livePlayInfo['cover']);
            online = _parseInt(livePlayInfo['online']);
            areaName = _parseString(livePlayInfo['area_name']);
            title = _parseString(livePlayInfo['title']);
            liveStartTime = _parseInt(livePlayInfo['live_start_time']);
            watchedShow = _parseMap(livePlayInfo['watched_show']);
          }
        }
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint(
            'DynamicLiveModel: Failed to parse live content: $e\n$stack',
          );
        }
      }
    }
  }
}

class DynamicLive2Model {
  DynamicLive2Model({
    this.badge,
    this.cover,
    this.descFirst,
    this.descSecond,
    this.id,
    this.jumpUrl,
    this.liveState,
    this.reserveType,
    this.title,
  });

  Map? badge;
  String? cover;
  String? descFirst;
  String? descSecond;
  int? id;
  String? jumpUrl;
  int? liveState;
  int? reserveType;
  String? title;

  DynamicLive2Model.fromJson(Map<String, dynamic> json) {
    badge = _parseMap(json['badge']);
    cover = _parseString(json['cover']);
    descFirst = _parseString(json['desc_first']);
    descSecond = _parseString(json['desc_second']);
    id = _parseInt(json['id']);
    jumpUrl = _parseString(json['jump_url']);
    liveState = _parseInt(json['liv_state']);
    reserveType = _parseInt(json['reserve_type']);
    title = _parseString(json['title']);
  }
}

// 动态状态 转发、评论、点赞
class ModuleStatModel {
  ModuleStatModel({this.comment, this.forward, this.like});

  Comment? comment;
  ForWard? forward;
  Like? like;

  ModuleStatModel.fromJson(Map<String, dynamic> json) {
    final commentMap = _parseMap(json['comment']);
    comment = commentMap != null ? Comment.fromJson(commentMap) : null;
    final forwardMap = _parseMap(json['forward']);
    forward = forwardMap != null ? ForWard.fromJson(forwardMap) : null;
    final likeMap = _parseMap(json['like']);
    like = likeMap != null ? Like.fromJson(likeMap) : null;
  }
}

// 动态状态 评论
class Comment {
  Comment({this.count, this.forbidden});

  String? count;
  bool? forbidden;

  Comment.fromJson(Map<String, dynamic> json) {
    count = _parseCount(json['count']);
    forbidden = _parseBool(json['forbidden']);
  }
}

class ForWard {
  ForWard({this.count, this.forbidden});
  String? count;
  bool? forbidden;

  ForWard.fromJson(Map<String, dynamic> json) {
    count = _parseCount(json['count']);
    forbidden = _parseBool(json['forbidden']);
  }
}

// 动态状态 点赞
class Like {
  Like({this.count, this.forbidden, this.status});

  String? count;
  bool? forbidden;
  bool? status;

  Like.fromJson(Map<String, dynamic> json) {
    count = _parseCount(json['count']);
    forbidden = _parseBool(json['forbidden']);
    status = _parseBool(json['status']);
  }
}

class Stat {
  Stat({this.danmu, this.play});

  String? danmu;
  String? play;

  Stat.fromJson(Map<String, dynamic> json) {
    danmu = _parseString(json['danmaku']);
    play = _parseString(json['play']);
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (value is bool) return value ? 1 : 0;
  return null;
}

bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) return value == 'true' || value == '1';
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

Map<String, dynamic>? _parseMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<T>? _parseList<T>(dynamic value) {
  if (value == null) return null;
  if (value is List<T>) return value;
  if (value is List) {
    try {
      return value.cast<T>();
    } catch (_) {
      return null;
    }
  }
  return null;
}

String? _parseCount(dynamic value) {
  final count = _parseInt(value);
  if (count == null || count == 0) return null;
  return count.toString();
}

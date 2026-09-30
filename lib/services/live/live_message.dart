import 'package:flutter/material.dart';

enum LiveMessageType { danmaku, popularity, superChat, interact, unknown }

abstract class LiveMessage {
  final LiveMessageType type;
  final int timestamp;

  const LiveMessage({required this.type, required this.timestamp});
}

class LiveDanmakuItem extends LiveMessage {
  final String text;
  final String uname;
  final int uid;
  final Color color;
  final int mode; // 1,2,3: scroll, 4: bottom, 5: top
  final int fontSize;

  const LiveDanmakuItem({
    required this.text,
    required this.uname,
    required this.uid,
    required this.color,
    this.mode = 1,
    this.fontSize = 25,
    required super.timestamp,
  }) : super(type: LiveMessageType.danmaku);

  factory LiveDanmakuItem.fromInfo(List<dynamic> info) {
    final text = info.length > 1 ? info[1].toString() : '';
    String uname = '';
    int uid = 0;
    if (info.length > 2 && info[2] is List) {
      final userList = info[2] as List;
      if (userList.isNotEmpty) {
        uid = int.tryParse(userList[0].toString()) ?? 0;
      }
      if (userList.length > 1) {
        uname = userList[1].toString();
      }
    }

    Color color = Colors.white;
    int mode = 1;
    int fontSize = 25;
    int timestamp = DateTime.now().millisecondsSinceEpoch;

    if (info.isNotEmpty && info[0] is List) {
      final meta = info[0] as List;
      if (meta.length > 1) {
        mode = int.tryParse(meta[1].toString()) ?? 1;
      }
      if (meta.length > 2) {
        fontSize = int.tryParse(meta[2].toString()) ?? 25;
      }
      if (meta.length > 3) {
        final colorInt = int.tryParse(meta[3].toString()) ?? 16777215;
        color = Color(0xFF000000 | (colorInt & 0xFFFFFF));
      }
      if (meta.length > 4) {
        timestamp = int.tryParse(meta[4].toString()) ?? timestamp;
      }
    }

    return LiveDanmakuItem(
      text: text,
      uname: uname,
      uid: uid,
      color: color,
      mode: mode,
      fontSize: fontSize,
      timestamp: timestamp,
    );
  }
}

class LivePopularityMessage extends LiveMessage {
  final int popularity;

  const LivePopularityMessage(this.popularity)
    : super(type: LiveMessageType.popularity, timestamp: 0);
}

class LiveSuperChatMessage extends LiveMessage {
  final String uname;
  final int uid;
  final double price;
  final String message;
  final String face;

  const LiveSuperChatMessage({
    required this.uname,
    required this.uid,
    required this.price,
    required this.message,
    this.face = '',
    required super.timestamp,
  }) : super(type: LiveMessageType.superChat);
}

class LiveInteractMessage extends LiveMessage {
  final String uname;
  final int uid;
  final int action; // 1: 进入房间, 2: 关注, 3: 分享

  const LiveInteractMessage({
    required this.uname,
    required this.uid,
    required this.action,
    required super.timestamp,
  }) : super(type: LiveMessageType.interact);
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'live_message.dart';

class LiveRawPacket {
  final int op;
  final int protoVer;
  final Uint8List body;

  const LiveRawPacket({
    required this.op,
    required this.protoVer,
    required this.body,
  });
}

class LivePacketCodec {
  static const int rawHeaderLen = 16;
  static const int opHeartbeat = 2;
  static const int opHeartbeatReply = 3;
  static const int opCommand = 5;
  static const int opAuth = 7;
  static const int opAuthReply = 8;

  /// 封装 Op 7 认证鉴权包
  /// 强制 payload 中包含 protover: 2，促使服务端采用 zlib 压缩而非 Brotli
  static Uint8List encodeAuth({
    required int roomId,
    required String token,
    int protover = 2,
    int uid = 0,
    String? buvid,
  }) {
    final payload = jsonEncode({
      'uid': uid,
      'roomid': roomId,
      'protover': protover,
      'platform': 'web',
      'type': 2,
      'key': token,
      if (buvid != null && buvid.isNotEmpty) 'buvid': buvid,
    });
    final bodyBytes = utf8.encode(payload);
    final totalLen = rawHeaderLen + bodyBytes.length;
    final bytes = Uint8List(totalLen);
    final bd = ByteData.view(bytes.buffer);

    bd.setUint32(0, totalLen);
    bd.setUint16(4, rawHeaderLen);
    bd.setUint16(6, 1); // 协议版本（数据包头部写 1）
    bd.setUint32(8, opAuth); // Op 7
    bd.setUint32(12, 1); // 序列号 1

    bytes.setRange(rawHeaderLen, totalLen, bodyBytes);
    return bytes;
  }

  /// 封装 Op 2 心跳包
  static Uint8List encodeHeartbeat() {
    final bytes = Uint8List(rawHeaderLen);
    final bd = ByteData.view(bytes.buffer);
    bd.setUint32(0, rawHeaderLen);
    bd.setUint16(4, rawHeaderLen);
    bd.setUint16(6, 1);
    bd.setUint32(8, opHeartbeat); // Op 2
    bd.setUint32(12, 1);
    return bytes;
  }

  /// 解码二进制流中的所有原始数据包
  /// 严格满足 Condition-1（零步长与越界防御）与 Condition-5（zlib 隔离捕获）
  static List<LiveRawPacket> decodeRawPackets(Uint8List bytes) {
    final packets = <LiveRawPacket>[];
    int offset = 0;
    final totalLen = bytes.length;

    while (offset + rawHeaderLen <= totalLen) {
      final bd = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes + offset,
        rawHeaderLen,
      );
      final packetLen = bd.getUint32(0);
      final headerLen = bd.getUint16(4);
      final protoVer = bd.getUint16(6);
      final op = bd.getUint32(8);

      // Condition-1: 零步长死循环防御与边界溢出截断保护
      if (packetLen < rawHeaderLen ||
          headerLen < rawHeaderLen ||
          headerLen > packetLen ||
          offset + packetLen > totalLen) {
        break;
      }

      final bodyOffset = offset + headerLen;
      final bodyLen = packetLen - headerLen;
      final bodyBytes = Uint8List.view(
        bytes.buffer,
        bytes.offsetInBytes + bodyOffset,
        bodyLen,
      );

      if (protoVer == 2) {
        // Condition-5: zlib 原生解压隔离，坏包安全跳过
        try {
          final decompressed = Uint8List.fromList(zlib.decode(bodyBytes));
          packets.addAll(decodeRawPackets(decompressed));
        } catch (e) {
          debugPrint('LivePacketCodec zlib decode failed: $e');
        }
      } else {
        packets.add(LiveRawPacket(op: op, protoVer: protoVer, body: bodyBytes));
      }

      offset += packetLen;
    }

    return packets;
  }

  /// 解析业务消息对象
  static LiveMessage? parseMessage(LiveRawPacket raw) {
    if (raw.op == opHeartbeatReply && raw.body.length >= 4) {
      final bd = ByteData.view(raw.body.buffer, raw.body.offsetInBytes, 4);
      return LivePopularityMessage(bd.getUint32(0));
    }

    if (raw.op == opCommand) {
      try {
        final jsonStr = utf8.decode(raw.body);
        final obj = jsonDecode(jsonStr);
        if (obj is Map<String, dynamic>) {
          final cmd = obj['cmd']?.toString() ?? '';
          if (cmd.startsWith('DANMU_MSG')) {
            final info = obj['info'];
            if (info is List) {
              return LiveDanmakuItem.fromInfo(info);
            }
          } else if (cmd == 'SUPER_CHAT_MESSAGE') {
            final data = obj['data'];
            if (data is Map<String, dynamic>) {
              return LiveSuperChatMessage(
                uname: data['user_info']?['uname']?.toString() ?? '',
                uid: data['uid'] as int? ?? 0,
                price: (data['price'] as num?)?.toDouble() ?? 0.0,
                message: data['message']?.toString() ?? '',
                timestamp:
                    data['start_time'] as int? ??
                    DateTime.now().millisecondsSinceEpoch,
              );
            }
          } else if (cmd == 'INTERACT_WORD') {
            final data = obj['data'];
            if (data is Map<String, dynamic>) {
              return LiveInteractMessage(
                uname: data['uname']?.toString() ?? '',
                uid: data['uid'] as int? ?? 0,
                action: data['msg_type'] as int? ?? 1,
                timestamp:
                    data['timestamp'] as int? ??
                    DateTime.now().millisecondsSinceEpoch,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('LivePacketCodec JSON parse failed: $e');
      }
    }

    return null;
  }
}

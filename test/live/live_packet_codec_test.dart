import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/live/live_message.dart';
import 'package:pilipalaz/services/live/live_packet_codec.dart';

void main() {
  group('LivePacketCodec Framing & Encoding', () {
    test(
      'encodeAuth creates valid 16-byte header with protover=2 and Op 7',
      () {
        final bytes = LivePacketCodec.encodeAuth(
          roomId: 12345,
          token: 'test_token',
        );

        expect(bytes.length, greaterThan(16));
        final header = ByteData.view(bytes.buffer, bytes.offsetInBytes, 16);
        final totalLen = header.getUint32(0);
        final headerLen = header.getUint16(4);
        final protoVer = header.getUint16(6);
        final op = header.getUint32(8);
        final seq = header.getUint32(12);

        expect(totalLen, equals(bytes.length));
        expect(headerLen, equals(16));
        expect(
          protoVer,
          equals(1),
        ); // Protover field in auth header packet is 1
        expect(op, equals(LivePacketCodec.opAuth)); // 7
        expect(seq, equals(1));

        // Check JSON payload
        final bodyStr = utf8.decode(bytes.sublist(16));
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;
        expect(json['roomid'], equals(12345));
        expect(json['key'], equals('test_token'));
        expect(
          json['protover'],
          equals(2),
        ); // Condition 2: forced protover=2 in payload!
        expect(json['platform'], equals('web'));
        expect(json['type'], equals(2));
      },
    );

    test('encodeHeartbeat creates valid 16-byte Op 2 packet', () {
      final bytes = LivePacketCodec.encodeHeartbeat();

      expect(bytes.length, equals(16));
      final header = ByteData.view(bytes.buffer, bytes.offsetInBytes, 16);
      expect(header.getUint32(0), equals(16)); // total length 16
      expect(header.getUint16(4), equals(16)); // header length 16
      expect(header.getUint16(6), equals(1)); // protover 1
      expect(header.getUint32(8), equals(LivePacketCodec.opHeartbeat)); // 2
      expect(header.getUint32(12), equals(1)); // seq 1
    });
  });

  group('LivePacketCodec Decoding & Safety Guards', () {
    test(
      'Condition-1: zero-step and invalid packetLen guards prevent infinite loop',
      () {
        // Create a corrupted packet where packetLen == 0 or packetLen < 16
        final corrupted = Uint8List(32);
        final bd = ByteData.view(corrupted.buffer);
        bd.setUint32(
          0,
          0,
        ); // packetLen = 0 (would cause infinite loop without guard)
        bd.setUint16(4, 16);
        bd.setUint16(6, 0);
        bd.setUint32(8, 5);
        bd.setUint32(12, 1);

        // Must safely terminate and return empty list rather than hanging/freezing
        final packets = LivePacketCodec.decodeRawPackets(corrupted);
        expect(packets, isEmpty);

        // Case 2: packetLen > bytes.length (truncated buffer)
        bd.setUint32(0, 100); // Claims 100 bytes but only 32 exist
        final packets2 = LivePacketCodec.decodeRawPackets(corrupted);
        expect(packets2, isEmpty);
      },
    );

    test('decodes plain protover=0/1 single packet correctly', () {
      final jsonStr = jsonEncode({
        'cmd': 'DANMU_MSG',
        'info': [
          [0, 1, 25, 16777215, 1700000000],
          '测试弹幕',
          [1001, '张三'],
        ],
      });
      final body = utf8.encode(jsonStr);
      final raw = Uint8List(16 + body.length);
      final bd = ByteData.view(raw.buffer);
      bd.setUint32(0, 16 + body.length);
      bd.setUint16(4, 16);
      bd.setUint16(6, 0); // plain
      bd.setUint32(8, LivePacketCodec.opCommand); // 5
      bd.setUint32(12, 1);
      raw.setRange(16, 16 + body.length, body);

      final packets = LivePacketCodec.decodeRawPackets(raw);
      expect(packets.length, equals(1));
      expect(packets.first.op, equals(LivePacketCodec.opCommand));

      final msg = LivePacketCodec.parseMessage(packets.first);
      expect(msg, isA<LiveDanmakuItem>());
      final dm = msg as LiveDanmakuItem;
      expect(dm.text, equals('测试弹幕'));
      expect(dm.uname, equals('张三'));
      expect(dm.uid, equals(1001));
      expect(dm.color, equals(const Color(0xFFFFFFFF)));
      expect(dm.mode, equals(1));
    });

    test(
      'decodes protover=2 zlib-compressed packet with multiple concatenated messages',
      () {
        // Build two child packets
        Uint8List makeChild(String text, String uname) {
          final payload = utf8.encode(
            jsonEncode({
              'cmd': 'DANMU_MSG',
              'info': [
                [0, 1, 25, 16711680, 1700000000], // red color
                text,
                [2002, uname],
              ],
            }),
          );
          final b = Uint8List(16 + payload.length);
          final d = ByteData.view(b.buffer);
          d.setUint32(0, 16 + payload.length);
          d.setUint16(4, 16);
          d.setUint16(6, 0);
          d.setUint32(8, 5);
          d.setUint32(12, 1);
          b.setRange(16, 16 + payload.length, payload);
          return b;
        }

        final child1 = makeChild('弹幕一', '李四');
        final child2 = makeChild('弹幕二', '王五');
        final concatenated = Uint8List(child1.length + child2.length)
          ..setRange(0, child1.length, child1)
          ..setRange(child1.length, child1.length + child2.length, child2);

        // Compress with zlib
        final compressed = zlib.encode(concatenated);

        // Wrap in parent packet with protover=2
        final parent = Uint8List(16 + compressed.length);
        final pbd = ByteData.view(parent.buffer);
        pbd.setUint32(0, 16 + compressed.length);
        pbd.setUint16(4, 16);
        pbd.setUint16(6, 2); // Zlib compressed
        pbd.setUint32(8, 5);
        pbd.setUint32(12, 1);
        parent.setRange(16, 16 + compressed.length, compressed);

        final packets = LivePacketCodec.decodeRawPackets(parent);
        expect(packets.length, equals(2));

        final dm1 = LivePacketCodec.parseMessage(packets[0]) as LiveDanmakuItem;
        expect(dm1.text, equals('弹幕一'));
        expect(dm1.uname, equals('李四'));
        expect(dm1.color, equals(const Color(0xFFFF0000)));

        final dm2 = LivePacketCodec.parseMessage(packets[1]) as LiveDanmakuItem;
        expect(dm2.text, equals('弹幕二'));
        expect(dm2.uname, equals('王五'));
      },
    );

    test(
      'Condition-5: corrupted zlib bytes are safely handled without throwing exception',
      () {
        final corruptedZlib = Uint8List.fromList([
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
        ]);
        final parent = Uint8List(16 + corruptedZlib.length);
        final pbd = ByteData.view(parent.buffer);
        pbd.setUint32(0, 16 + corruptedZlib.length);
        pbd.setUint16(4, 16);
        pbd.setUint16(6, 2); // Claims to be zlib
        pbd.setUint32(8, 5);
        pbd.setUint32(12, 1);
        parent.setRange(16, 16 + corruptedZlib.length, corruptedZlib);

        expect(() => LivePacketCodec.decodeRawPackets(parent), returnsNormally);
        final packets = LivePacketCodec.decodeRawPackets(parent);
        expect(packets, isEmpty);
      },
    );

    test('decodes heartbeat popularity response Op 3', () {
      final raw = Uint8List(20);
      final bd = ByteData.view(raw.buffer);
      bd.setUint32(0, 20);
      bd.setUint16(4, 16);
      bd.setUint16(6, 1);
      bd.setUint32(8, LivePacketCodec.opHeartbeatReply); // 3
      bd.setUint32(12, 1);
      bd.setUint32(16, 88888); // popularity

      final packets = LivePacketCodec.decodeRawPackets(raw);
      expect(packets.length, equals(1));
      final msg = LivePacketCodec.parseMessage(packets.first);
      expect(msg, isA<LivePopularityMessage>());
      expect((msg as LivePopularityMessage).popularity, equals(88888));
    });

    test('supports DANMU_MSG command prefixes and variant tags', () {
      final raw = LiveRawPacket(
        op: 5,
        protoVer: 0,
        body: utf8.encode(
          jsonEncode({
            'cmd': 'DANMU_MSG:4:0:2:2:2:0',
            'info': [
              [0, 1, 25, 16777215, 1700000000],
              '变体弹幕内容',
              [3003, '赵六'],
            ],
          }),
        ),
      );

      final msg = LivePacketCodec.parseMessage(raw);
      expect(msg, isA<LiveDanmakuItem>());
      final dm = msg as LiveDanmakuItem;
      expect(dm.text, equals('变体弹幕内容'));
      expect(dm.uname, equals('赵六'));
    });
  });
}

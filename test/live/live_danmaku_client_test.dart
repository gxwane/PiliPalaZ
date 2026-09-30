import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/live/danmaku_conf.dart';
import 'package:pilipalaz/services/live/live_danmaku_client.dart';
import 'package:pilipalaz/services/live/live_message.dart';
import 'package:pilipalaz/services/live/live_packet_codec.dart';

class MockWebSocket implements WebSocket {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final List<dynamic> sentMessages = [];
  bool isClosed = false;
  @override
  int? closeCode;
  @override
  String? closeReason;

  void emitFromServer(dynamic data) {
    if (!_incoming.isClosed) {
      _incoming.add(data);
    }
  }

  void emitServerClose([int? code, String? reason]) {
    closeCode = code;
    closeReason = reason;
    isClosed = true;
    _incoming.close();
  }

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  Future close([int? code, String? reason]) async {
    isClosed = true;
    closeCode = code;
    closeReason = reason;
    await _incoming.close();
  }

  @override
  StreamSubscription listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _incoming.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LiveDanmakuClient Connection & Handshake', () {
    late MockWebSocket mockSocket;
    late LiveDanmakuConfModel testConf;

    setUp(() {
      mockSocket = MockWebSocket();
      testConf = LiveDanmakuConfModel(
        host: 'test.chat.bilibili.com',
        wssPort: 443,
        token: 'auth_token_xyz',
      );
    });

    test(
      'connect sends Op 7 auth packet and enters connected state upon Op 8',
      () async {
        final client = LiveDanmakuClient(
          roomId: 99999,
          connector: (uri) async => mockSocket,
        );

        final connectedFuture = client.connect(testConf);
        await pumpEventQueue();

        // Check auth packet was sent
        expect(mockSocket.sentMessages.length, equals(1));
        final authBytes = mockSocket.sentMessages.first as Uint8List;
        final header = ByteData.view(
          authBytes.buffer,
          authBytes.offsetInBytes,
          16,
        );
        expect(header.getUint32(8), equals(LivePacketCodec.opAuth)); // 7

        // Server sends Op 8 (auth reply)
        final op8Bytes = Uint8List(16);
        final op8Bd = ByteData.view(op8Bytes.buffer);
        op8Bd.setUint32(0, 16);
        op8Bd.setUint16(4, 16);
        op8Bd.setUint16(6, 1);
        op8Bd.setUint32(8, LivePacketCodec.opAuthReply); // 8
        op8Bd.setUint32(12, 1);
        mockSocket.emitFromServer(op8Bytes);

        await connectedFuture;
        expect(client.isConnected, isTrue);

        client.dispose();
        expect(client.isDisposed, isTrue);
        expect(mockSocket.isClosed, isTrue);
      },
    );

    test('receives and emits LiveDanmakuItem on onDanmaku stream', () async {
      final client = LiveDanmakuClient(
        roomId: 99999,
        connector: (uri) async => mockSocket,
      );

      final List<LiveDanmakuItem> receivedDanmaku = [];
      client.onDanmaku.listen(receivedDanmaku.add);

      await client.connect(testConf);
      await pumpEventQueue();

      // Server emits DANMU_MSG
      final payload = utf8.encode(
        jsonEncode({
          'cmd': 'DANMU_MSG',
          'info': [
            [0, 1, 25, 16777215, 1700000000],
            '实时测试弹幕',
            [555, '测试员'],
          ],
        }),
      );
      final raw = Uint8List(16 + payload.length);
      final bd = ByteData.view(raw.buffer);
      bd.setUint32(0, 16 + payload.length);
      bd.setUint16(4, 16);
      bd.setUint16(6, 0);
      bd.setUint32(8, 5);
      bd.setUint32(12, 1);
      raw.setRange(16, 16 + payload.length, payload);

      mockSocket.emitFromServer(raw);
      await pumpEventQueue();

      expect(receivedDanmaku.length, equals(1));
      expect(receivedDanmaku.first.text, equals('实时测试弹幕'));
      expect(receivedDanmaku.first.uname, equals('测试员'));

      client.dispose();
    });

    test(
      'Condition-3: In-flight disposed guard aborts connection and closes socket',
      () async {
        final completer = Completer<WebSocket>();
        final client = LiveDanmakuClient(
          roomId: 99999,
          connector: (uri) => completer.future,
        );

        // Start connecting asynchronously
        final connectFuture = client.connect(testConf);

        // User exits immediately before socket completes
        client.dispose();
        expect(client.isDisposed, isTrue);

        // Socket handshake finishes afterwards
        completer.complete(mockSocket);
        await connectFuture;

        // Socket must be immediately closed and client remains disposed
        expect(mockSocket.isClosed, isTrue);
        expect(client.isConnected, isFalse);
      },
    );
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../models/live/danmaku_conf.dart';
import 'live_message.dart';
import 'live_packet_codec.dart';

typedef WebSocketConnector = Future<WebSocket> Function(Uri uri);

class LiveDanmakuClient {
  final int roomId;
  final WebSocketConnector _connector;

  static const int maxReconnectAttempts = 3;

  WebSocket? _socket;
  StreamSubscription? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  LiveDanmakuConfModel? _lastConf;

  int _reconnectAttempts = 0;
  bool _isConnected = false;
  bool _isDisposed = false;

  final _danmakuController = StreamController<LiveDanmakuItem>.broadcast();
  final _popularityController = StreamController<int>.broadcast();
  final _messageController = StreamController<LiveMessage>.broadcast();

  bool get isConnected => _isConnected && !_isDisposed;
  bool get isDisposed => _isDisposed;

  Stream<LiveDanmakuItem> get onDanmaku => _danmakuController.stream;
  Stream<int> get onPopularity => _popularityController.stream;
  Stream<LiveMessage> get onMessage => _messageController.stream;

  final int uid;
  final String? buvid;

  LiveDanmakuClient({
    required this.roomId,
    this.uid = 0,
    this.buvid,
    WebSocketConnector? connector,
  }) : _connector = connector ?? _defaultConnector;

  static Future<WebSocket> _defaultConnector(Uri uri) {
    return WebSocket.connect(uri.toString());
  }

  /// 建立长连并发送认证包
  Future<void> connect(LiveDanmakuConfModel conf) async {
    if (_isDisposed) return;
    _lastConf = conf;

    String host = conf.host;
    int port = conf.wssPort;
    if (conf.hostServerList.isNotEmpty) {
      final server =
          conf.hostServerList[_reconnectAttempts % conf.hostServerList.length];
      if (server.host.isNotEmpty) {
        host = server.host;
        port = server.wssPort;
      }
    }
    final uri = Uri.parse('wss://$host:$port/sub');
    debugPrint('[LiveDanmakuClient] Connecting to $uri for roomId $roomId...');

    try {
      final socket = await _connector(uri);
      debugPrint('[LiveDanmakuClient] WebSocket connected to $uri!');
      // Condition-3: 异步握手期间退出竞争拦截
      if (_isDisposed) {
        debugPrint(
          '[LiveDanmakuClient] Disposed while connecting, closing socket.',
        );
        unawaited(socket.close());
        return;
      }

      _cleanupSocket();
      _socket = socket;

      // 先挂载监听器再发送认证包，避免时序竞态
      _socketSub = socket.listen(
        _handleIncomingData,
        onError: (err) {
          debugPrint('[LiveDanmakuClient] Live WebSocket error: $err');
          _handleDisconnect(unexpected: true);
        },
        onDone: () {
          debugPrint(
            '[LiveDanmakuClient] onDone: closeCode=${socket.closeCode}, closeReason=${socket.closeReason}',
          );
          _handleDisconnect(unexpected: true);
        },
        cancelOnError: true,
      );

      // 发送 Op 7 认证鉴权包（固定 protover: 2）
      final authBytes = LivePacketCodec.encodeAuth(
        roomId: roomId,
        token: conf.token,
        protover: 2,
        uid: uid,
        buvid: buvid,
      );
      socket.add(authBytes);
      debugPrint('[LiveDanmakuClient] Sent Op 7 Auth packet (uid=$uid).');
    } catch (e) {
      debugPrint('[LiveDanmakuClient] connect failed: $e');
      _handleDisconnect(unexpected: true);
    }
  }

  void _handleIncomingData(dynamic raw) {
    if (_isDisposed) return;
    if (raw is! List<int>) return;

    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
    final packets = LivePacketCodec.decodeRawPackets(bytes);

    for (final packet in packets) {
      if (packet.op == LivePacketCodec.opAuthReply) {
        debugPrint('[LiveDanmakuClient] Received Op 8 Auth Reply!');
        _isConnected = true;
        _reconnectAttempts = 0;
        _startHeartbeat();
      } else if (packet.op == LivePacketCodec.opHeartbeatReply) {
        final msg = LivePacketCodec.parseMessage(packet);
        if (msg is LivePopularityMessage && !_popularityController.isClosed) {
          _popularityController.add(msg.popularity);
          if (!_messageController.isClosed) {
            _messageController.add(msg);
          }
        }
      } else if (packet.op == LivePacketCodec.opCommand) {
        final msg = LivePacketCodec.parseMessage(packet);
        if (msg != null && !_messageController.isClosed) {
          _messageController.add(msg);
          if (msg is LiveDanmakuItem && !_danmakuController.isClosed) {
            debugPrint(
              '[LiveDanmakuClient] Emitting LiveDanmakuItem: ${msg.text}',
            );
            _danmakuController.add(msg);
          }
        }
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _socket != null && !_isDisposed) {
        try {
          _socket!.add(LivePacketCodec.encodeHeartbeat());
        } catch (_) {}
      }
    });
  }

  void _handleDisconnect({required bool unexpected}) {
    _isConnected = false;
    _heartbeatTimer?.cancel();

    if (_isDisposed || !unexpected) return;

    // 指数退避自动重连
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      final delaySeconds = 1 << (_reconnectAttempts - 1);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (!_isDisposed && _lastConf != null) {
          connect(_lastConf!);
        }
      });
    }
  }

  void _cleanupSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    if (_socket != null) {
      try {
        _socket!.close(1000, 'Normal closure');
      } catch (_) {}
      _socket = null;
    }
  }

  /// 释放所有资源，销毁长连
  void dispose() {
    _isDisposed = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _cleanupSocket();

    if (!_danmakuController.isClosed) {
      _danmakuController.close();
    }
    if (!_popularityController.isClosed) {
      _popularityController.close();
    }
    if (!_messageController.isClosed) {
      _messageController.close();
    }
  }
}

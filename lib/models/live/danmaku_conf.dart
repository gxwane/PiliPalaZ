class LiveDanmakuConfModel {
  final String host;
  final int port;
  final int wssPort;
  final int wsPort;
  final String token;
  final List<LiveDanmakuHostServer> hostServerList;

  LiveDanmakuConfModel({
    this.host = 'broadcastlv.chat.bilibili.com',
    this.port = 2243,
    this.wssPort = 443,
    this.wsPort = 2244,
    this.token = '',
    this.hostServerList = const [],
  });

  factory LiveDanmakuConfModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return LiveDanmakuConfModel();
    final list = <LiveDanmakuHostServer>[];
    final serverListRaw = json['host_server_list'];
    if (serverListRaw is List) {
      for (final item in serverListRaw) {
        if (item is Map<String, dynamic>) {
          list.add(LiveDanmakuHostServer.fromJson(item));
        }
      }
    }
    return LiveDanmakuConfModel(
      host: json['host'] as String? ?? 'broadcastlv.chat.bilibili.com',
      port: json['port'] as int? ?? 2243,
      wssPort: json['wss_port'] as int? ?? 443,
      wsPort: json['ws_port'] as int? ?? 2244,
      token: json['token'] as String? ?? '',
      hostServerList: list,
    );
  }
}

class LiveDanmakuHostServer {
  final String host;
  final int port;
  final int wssPort;
  final int wsPort;

  LiveDanmakuHostServer({
    required this.host,
    this.port = 2243,
    this.wssPort = 443,
    this.wsPort = 2244,
  });

  factory LiveDanmakuHostServer.fromJson(Map<String, dynamic> json) {
    return LiveDanmakuHostServer(
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 2243,
      wssPort: json['wss_port'] as int? ?? 443,
      wsPort: json['ws_port'] as int? ?? 2244,
    );
  }
}

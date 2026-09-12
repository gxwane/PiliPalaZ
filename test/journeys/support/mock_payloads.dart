import 'dart:convert';
import 'package:dio/dio.dart';

Map<String, dynamic> buildNavGuestPayload() => <String, dynamic>{
  'code': 0,
  'message': '0',
  'ttl': 1,
  'data': {
    'isLogin': false,
    'email_verified': 0,
    'face': 'https://i0.hdslb.com/bfs/face/member/noface.jpg',
    'level_info': {'current_level': 0},
    'mid': 0,
    'mobile_verified': 0,
    'money': 0,
    'moral': 0,
    'scores': 0,
    'uname': '游客',
    'vipDueDate': 0,
    'vipStatus': 0,
    'vipType': 0,
    'vip_pay_type': 0,
    'vip_theme_type': 0,
    'wallet': {
      'mid': 0,
      'bcoin_balance': 0,
      'coupon_balance': 0,
      'bcoin_coupon': 0,
    },
    'wbi_img': {
      'img_url':
          'https://i0.hdslb.com/bfs/wbi/7cd084481368485c8eab3be0d7f4e6e4.png',
      'sub_url':
          'https://i0.hdslb.com/bfs/wbi/529e2574d1114b1ab69446e07f86a25d.png',
    },
  },
};

Map<String, dynamic> buildSearchDefaultPayload() => <String, dynamic>{
  'code': 0,
  'message': '0',
  'ttl': 1,
  'data': {'show_name': '搜索测试视频', 'name': '搜索测试视频', 'goto': 0, 'url': ''},
};

Map<String, dynamic> buildRcmdFeedPayload({String prefix = 'BV1TestJourney'}) {
  final items = [
    {
      'id': 10001,
      'bvid': '${prefix}01',
      'cid': 100001,
      'goto': 'av',
      'uri': 'https://www.bilibili.com/video/${prefix}01',
      'pic': 'https://i0.hdslb.com/bfs/archive/test01.jpg',
      'title': '端到端测试视频：首页推荐第一条',
      'duration': 360,
      'pubdate': 1700000000,
      'owner': {
        'mid': 12345,
        'name': '测试UP主A',
        'face': 'https://i0.hdslb.com/bfs/face/test_a.jpg',
      },
      'stat': {'view': 50000, 'like': 3000, 'danmaku': 500},
    },
    {
      'id': 10002,
      'bvid': '${prefix}02',
      'cid': 100002,
      'goto': 'av',
      'uri': 'https://www.bilibili.com/video/${prefix}02',
      'pic': 'https://i0.hdslb.com/bfs/archive/test02.jpg',
      'title': '端到端测试视频：首页推荐第二条',
      'duration': 480,
      'pubdate': 1700001000,
      'owner': {
        'mid': 12346,
        'name': '测试UP主B',
        'face': 'https://i0.hdslb.com/bfs/face/test_b.jpg',
      },
      'stat': {'view': 120000, 'like': 8000, 'danmaku': 1200},
    },
    for (var i = 3; i <= 8; i++)
      {
        'id': 10000 + i,
        'bvid': '$prefix${i.toString().padLeft(2, '0')}',
        'cid': 100000 + i,
        'goto': 'av',
        'uri':
            'https://www.bilibili.com/video/$prefix${i.toString().padLeft(2, '0')}',
        'pic':
            'https://i0.hdslb.com/bfs/archive/test${i.toString().padLeft(2, '0')}.jpg',
        'title': '端到端测试视频：首页推荐第$i条',
        'duration': 300 + i * 30,
        'pubdate': 1700000000 + i * 1000,
        'owner': {
          'mid': 12340 + i,
          'name': '测试UP主$i',
          'face': 'https://i0.hdslb.com/bfs/face/test_$i.jpg',
        },
        'stat': {
          'view': 50000 + i * 5000,
          'like': 3000 + i * 200,
          'danmaku': 500 + i * 50,
        },
      },
  ];
  return <String, dynamic>{
    'code': 0,
    'message': '0',
    'ttl': 1,
    'data': {'item': items},
  };
}

Map<String, dynamic> buildVideoViewDetailPayload({
  String bvid = 'BV1TestJourney01',
  int cid = 100001,
  String title = '端到端测试视频：首页推荐第一条',
}) => <String, dynamic>{
  'code': 0,
  'message': '0',
  'ttl': 1,
  'data': {
    'View': {
      'bvid': bvid,
      'aid': 12345678,
      'videos': 1,
      'tid': 17,
      'tname': '单机游戏',
      'copyright': 1,
      'pic': 'https://i0.hdslb.com/bfs/archive/test01.jpg',
      'title': title,
      'pubdate': 1700000000,
      'ctime': 1700000000,
      'desc': '这是一个用于核心旅程端到端自动化测试的模拟视频描述内容。',
      'state': 0,
      'duration': 360,
      'cid': cid,
      'rights': {
        'bp': 0,
        'elec': 0,
        'download': 1,
        'movie': 0,
        'pay': 0,
        'hd5': 0,
        'no_reprint': 1,
        'autoplay': 1,
        'ugc_pay': 0,
        'is_cooperation': 0,
        'ugc_pay_preview': 0,
        'no_background': 0,
        'clean_mode': 0,
        'is_stein_gate': 0,
        'is_360': 0,
        'no_share': 0,
        'arc_pay': 0,
        'free_watch': 0,
      },
      'owner': {
        'mid': 12345,
        'name': '测试UP主A',
        'face': 'https://i0.hdslb.com/bfs/face/test_a.jpg',
      },
      'stat': {
        'view': 50000,
        'danmaku': 500,
        'reply': 200,
        'favorite': 3000,
        'coin': 1500,
        'share': 600,
        'like': 5000,
      },
      'pages': [
        {
          'cid': cid,
          'page': 1,
          'from': 'vupload',
          'part': '第1节：旅程启动演示',
          'duration': 360,
          'vid': '',
          'weblink': '',
        },
        {
          'cid': cid + 1,
          'page': 2,
          'from': 'vupload',
          'part': '第2节：高级交互测试',
          'duration': 420,
          'vid': '',
          'weblink': '',
        },
      ],
    },
    'Card': {
      'card': {
        'mid': '12345',
        'name': '测试UP主A',
        'face': 'https://i0.hdslb.com/bfs/face/test_a.jpg',
        'sign': '自动化测试官方 UP',
        'fans': 100000,
        'attention': 50,
        'vip': {'vipStatus': 0, 'vipType': 0},
      },
      'following': false,
      'follower': 100000,
    },
    'Tags': [
      {'tag_id': 1, 'tag_name': 'Flutter'},
      {'tag_id': 2, 'tag_name': '测试自动化'},
    ],
    'Related': [
      {
        'id': 20001,
        'bvid': 'BV1Related01',
        'cid': 200001,
        'title': '相关推荐视频1',
        'pic': 'https://i0.hdslb.com/bfs/archive/rel01.jpg',
        'duration': 300,
        'owner': {'mid': 12345, 'name': '测试UP主A'},
        'stat': {'view': 10000, 'like': 500, 'danmaku': 80},
      },
    ],
    'Reply': {
      'page': {'count': 0},
      'replies': [],
    },
  },
};

Map<String, dynamic> buildPlayUrlPayload({
  int quality = 80,
  String? videoUrl,
  String? audioUrl,
  bool includeDash = true,
}) {
  final resolvedVideoUrl =
      videoUrl ?? 'https://test.bilibili.com/video_stream_dash.mp4';
  final resolvedAudioUrl =
      audioUrl ?? videoUrl ?? 'https://test.bilibili.com/audio_stream_dash.mp4';
  final content = <String, dynamic>{
    'from': 'local',
    'result': 'suee',
    'message': '',
    'quality': quality,
    'format': 'mp4',
    'timelength': 360000,
    'accept_format': 'mp4',
    'accept_description': ['1080P 高清', '720P 高清', '360P 流畅'],
    'accept_quality': [80, 64, 16],
    'video_codecid': 7,
    'seek_param': 'start',
    'seek_type': 'offset',
    'support_formats': [
      {
        'quality': 80,
        'format': 'mp4',
        'new_description': '1080P 高清',
        'display_desc': '1080P',
        'superscript': '',
      },
      {
        'quality': 64,
        'format': 'mp4',
        'new_description': '720P 高清',
        'display_desc': '720P',
        'superscript': '',
      },
      {
        'quality': 16,
        'format': 'mp4',
        'new_description': '360P 流畅',
        'display_desc': '360P',
        'superscript': '',
      },
    ],
    'durl': [
      {'order': 1, 'length': 360000, 'size': 5242880, 'url': resolvedVideoUrl},
    ],
    'dash': {
      'duration': 360,
      'minBufferTime': 1.5,
      'video': [
        {
          'id': quality,
          'baseUrl': resolvedVideoUrl,
          'base_url': resolvedVideoUrl,
          'backupUrl': [],
          'backup_url': [],
          'bandwidth': 1500000,
          'mimeType': 'video/mp4',
          'mime_type': 'video/mp4',
          'codecs': 'avc1.64001F',
          'width': 1920,
          'height': 1080,
          'frameRate': '30',
          'frame_rate': '30',
          'sar': '1:1',
          'startWithSap': 1,
          'start_with_sap': 1,
          'SegmentBase': {
            'Initialization': '0-1000',
            'indexRange': '1001-2000',
          },
          'codecid': 7,
        },
      ],
      'audio': [
        {
          'id': 30280,
          'baseUrl': resolvedAudioUrl,
          'base_url': resolvedAudioUrl,
          'backupUrl': [],
          'backup_url': [],
          'bandwidth': 130000,
          'mimeType': 'audio/mp4',
          'mime_type': 'audio/mp4',
          'codecs': 'mp4a.40.2',
          'width': 0,
          'height': 0,
          'frameRate': '',
          'frame_rate': '',
          'sar': '',
          'startWithSap': 0,
          'start_with_sap': 0,
          'SegmentBase': {'Initialization': '0-500', 'indexRange': '501-1000'},
          'codecid': 0,
        },
      ],
    },
  };
  if (!includeDash) {
    content.remove('dash');
  }
  return <String, dynamic>{
    'code': 0,
    'message': '0',
    'ttl': 1,
    'data': content,
    'result': content,
  };
}

Map<String, dynamic> buildBangumiSeasonPayload({
  int seasonId = 40001,
  bool isRestricted = false,
}) => <String, dynamic>{
  'code': 0,
  'message': 'success',
  'result': {
    'season_id': seasonId,
    'season_title': '端到端测试番剧：第一季',
    'title': '端到端测试番剧：第一季',
    'cover': 'https://i0.hdslb.com/bfs/bangumi/season_test.jpg',
    'evaluate': '这是一部用于端到端旅程验证的测试番剧。',
    'total': 2,
    'type': 1,
    'rights': {
      'allow_download': 0,
      'area_limit': isRestricted ? 1 : 0,
      'is_preview': 0,
    },
    'user_status': {'follow': 0, 'pay': 0},
    'stat': {
      'coins': 10000,
      'danmakus': 80000,
      'favorites': 50000,
      'likes': 90000,
      'reply': 4000,
      'share': 2000,
      'views': 1000000,
    },
    'seasons': [
      {'season_id': seasonId, 'season_title': '第一季'},
      {'season_id': seasonId + 1, 'season_title': '第二季'},
    ],
    'episodes': [
      {
        'id': 50001,
        'ep_id': 50001,
        'aid': 1234501,
        'cid': 600001,
        'bvid': 'BV1BangumiEp01',
        'title': '1',
        'long_title': '启程：旅程的第一步',
        'cover': 'https://i0.hdslb.com/bfs/bangumi/ep01.jpg',
        'badge': isRestricted ? '限时免费' : '',
        'status': 2,
        'duration': 1440000,
      },
      {
        'id': 50002,
        'ep_id': 50002,
        'aid': 1234502,
        'cid': 600002,
        'bvid': 'BV1BangumiEp02',
        'title': '2',
        'long_title': '切换：无缝切集与重试',
        'cover': 'https://i0.hdslb.com/bfs/bangumi/ep02.jpg',
        'badge': isRestricted ? '大会员' : '',
        'status': 2,
        'duration': 1440000,
      },
    ],
  },
};

ResponseBody journeyMockDispatcher(
  RequestOptions options, {
  Map<String, dynamic> Function(RequestOptions)? customHandler,
  bool simulateOffline = false,
  bool simulateTimeout = false,
}) {
  if (simulateOffline) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'Network offline: Connection refused',
    );
  }

  if (simulateTimeout) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionTimeout,
      message: 'Connection timeout',
    );
  }

  if (customHandler != null) {
    final custom = customHandler(options);
    if (custom.isNotEmpty) {
      return ResponseBody.fromString(
        jsonEncode(custom),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
  }

  final path = options.path;
  print('DISPATCHER: path = $path');

  // 1. 导航与登录信息
  if (path.contains('/x/web-interface/nav')) {
    return _jsonRes(buildNavGuestPayload());
  }

  // 2. 搜索框默认词
  if (path.contains('/x/web-interface/search/default')) {
    return _jsonRes(buildSearchDefaultPayload());
  }

  // 3. 首页推荐流
  if (path.contains('/x/web-interface/index/top/feed/rcmd')) {
    return _jsonRes(buildRcmdFeedPayload());
  }

  // 4. 视频详情 (detail & view)
  if (path.contains('/x/web-interface/view/detail') ||
      path.contains('/x/web-interface/wbi/view/detail')) {
    final bvid =
        options.queryParameters['bvid']?.toString() ?? 'BV1TestJourney01';
    return _jsonRes(buildVideoViewDetailPayload(bvid: bvid));
  }
  if (path.contains('/x/web-interface/view') ||
      path.contains('/x/web-interface/wbi/view')) {
    final bvid =
        options.queryParameters['bvid']?.toString() ?? 'BV1TestJourney01';
    return _jsonRes({
      'code': 0,
      'message': '0',
      'ttl': 1,
      'data': buildVideoViewDetailPayload(bvid: bvid)['data']['View'],
    });
  }

  // 5. 视频播放流 PlayURL (video & pgc)
  if (path.contains('/x/player/wbi/v2') ||
      path.contains('/pgc/player/web/v2') ||
      path.contains('/pgc/player/web/playurl') ||
      path.contains('/x/player/wbi/playurl') ||
      path.contains('/x/player/playurl')) {
    return _jsonRes(buildPlayUrlPayload());
  }

  // 6. 番剧季与选集详情
  if (path.contains('/pgc/view/web/season')) {
    return _jsonRes(buildBangumiSeasonPayload());
  }

  // 7. 评论区
  if (path.contains('/x/v2/reply/wbi/main') || path.contains('/x/v2/reply')) {
    return _jsonRes({
      'code': 0,
      'message': '0',
      'ttl': 1,
      'data': {
        'page': {'count': 0, 'num': 1, 'size': 20},
        'replies': [],
      },
    });
  }

  // 8. 默认兜底成功响应
  return _jsonRes({
    'code': 0,
    'message': '0',
    'ttl': 1,
    'data': <String, dynamic>{},
  });
}

ResponseBody _jsonRes(Object? body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

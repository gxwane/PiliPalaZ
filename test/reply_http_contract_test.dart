import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/reply.dart';
import 'package:pilipalaz/models/video/reply/data.dart';
import 'package:pilipalaz/models/video/reply/emote.dart';
import 'package:pilipalaz/utils/storage.dart';

import 'support/http_test_harness.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz_reply_http_test_',
    );
    Hive.init(hiveDirectory.path);
    GStorage.userInfo = await Hive.openBox<dynamic>('userInfo');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test(
    'decodes primary replies and sends an escaped pagination cursor anonymously',
    () async {
      final harness = HttpTestHarness(
        (_) => jsonResponse(<String, Object?>{
          'code': 0,
          'data': _primaryReplyData(),
        }),
      );

      final result = await harness.run(
        () => ReplyHttp.replyList(
          oid: 100,
          nextOffset: 'cursor"quoted',
          type: 1,
          sort: 1,
        ),
      );

      expect(result, isA<ApiSuccess<ReplyData>>());
      expect(
        (result as ApiSuccess<ReplyData>)
            .data
            .cursor!
            .paginationReply!
            .nextOffset,
        'next',
      );
      final request = harness.requests.single;
      expect(request.path, Api.replyList);
      expect(request.queryParameters['oid'], 100);
      expect(request.queryParameters['type'], 1);
      expect(request.queryParameters['mode'], 3);
      expect(
        request.queryParameters['pagination_str'],
        '{"offset":"cursor\\"quoted"}',
      );
      expect(request.headers['cookie'], 'buvid3= ; b_nut= ; sid= ');
    },
  );

  test('decodes nested replies and sends page parameters', () async {
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{
          'page': <String, Object?>{'num': 2, 'count': 1},
          'config': <String, Object?>{},
          'replies': <Object?>[],
          'top_replies': <Object?>[],
          'upper': <String, Object?>{'mid': 42},
          'root': _replyItem(rpid: 7),
        },
      }),
    );

    final result = await harness.run(
      () => ReplyHttp.replyReplyList(
        oid: 100,
        root: '7',
        pageNum: 2,
        type: 1,
        sort: 0,
      ),
    );

    expect(result, isA<ApiSuccess<ReplyReplyData>>());
    expect((result as ApiSuccess<ReplyReplyData>).data.root!.rpid, 7);
    final request = harness.requests.single;
    expect(request.path, Api.replyReplyList);
    expect(request.queryParameters['root'], '7');
    expect(request.queryParameters['pn'], 2);
    expect(request.queryParameters['sort'], 0);
  });

  test('sends reply likes with CSRF and decodes emote packages', () async {
    final harness = HttpTestHarness((request) {
      if (request.path == Api.myEmote) {
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'setting': <String, Object?>{'recent_limit': 10},
            'packages': <Object?>[],
          },
        });
      }
      return jsonResponse(<String, Object?>{'code': 0});
    });
    await harness.seedCsrf();

    final liked = await harness.run(
      () => ReplyHttp.likeReply(type: 1, oid: 100, rpid: 7, action: 1),
    );
    final emotes = await harness.run(
      () => ReplyHttp.getEmoteList(business: 'reply'),
    );

    expect(liked, isA<ApiSuccess<void>>());
    expect(emotes, isA<ApiSuccess<EmoteModelData>>());
    expect(
      (emotes as ApiSuccess<EmoteModelData>).data.setting!.recentLimit,
      10,
    );
    expect(harness.requests[0].method, 'POST');
    expect(harness.requests[0].queryParameters['rpid'], 7);
    expect(harness.requests[0].queryParameters['action'], 1);
    expect(harness.requests[0].queryParameters['csrf'], 'test-csrf');
    expect(harness.requests[1].queryParameters['business'], 'reply');
  });

  test('rejects a malformed primary reply payload', () async {
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{'code': 0, 'data': <Object?>[]}),
    );

    final result = await harness.run(
      () => ReplyHttp.replyList(oid: 100, nextOffset: '', type: 1),
    );

    expect(result, isA<ApiFailure<ReplyData>>());
    expect(
      (result as ApiFailure<ReplyData>).kind,
      ApiFailureKind.malformedResponse,
    );
  });
}

Map<String, Object?> _primaryReplyData() {
  return <String, Object?>{
    'cursor': <String, Object?>{
      'support_mode': <int>[],
      'pagination_reply': <String, Object?>{'next_offset': 'next'},
    },
    'config': <String, Object?>{},
    'replies': <Object?>[],
    'top_replies': <Object?>[],
    'upper': <String, Object?>{'mid': 42},
  };
}

Map<String, Object?> _replyItem({required int rpid}) {
  return <String, Object?>{
    'rpid': rpid,
    'member': <String, Object?>{
      'mid': '42',
      'level_info': <String, Object?>{'current_level': 6},
      'pendant': <String, Object?>{},
    },
    'content': <String, Object?>{'message': '测试评论'},
    'up_action': <String, Object?>{},
  };
}

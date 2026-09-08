import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/live.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/models/live/room_info_h5.dart';

import 'support/http_test_harness.dart';

void main() {
  test('decodes both supported live-list response shapes', () async {
    var requestCount = 0;
    final harness = HttpTestHarness((_) {
      requestCount += 1;
      final key = requestCount == 1 ? 'recommend_room_list' : 'list';
      final roomId = requestCount;
      return jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{
          key: <Object?>[
            <String, Object?>{'roomid': roomId, 'title': '直播 $roomId'},
          ],
        },
      });
    });

    final recommended = await harness.run(
      () => LiveHttp.liveList(pn: 2, ps: 20),
    );
    final fallback = await harness.run(() => LiveHttp.liveList(pn: 3));

    expect(recommended, isA<ApiSuccess<List<LiveItemModel>>>());
    expect(
      (recommended as ApiSuccess<List<LiveItemModel>>).data.single.roomId,
      1,
    );
    expect(fallback, isA<ApiSuccess<List<LiveItemModel>>>());
    expect((fallback as ApiSuccess<List<LiveItemModel>>).data.single.roomId, 2);
    expect(harness.requests[0].path, Api.liveList);
    expect(harness.requests[0].queryParameters['page'], 2);
    expect(harness.requests[0].queryParameters['page_size'], 20);
    expect(harness.requests[0].queryParameters['platform'], 'web');
    expect(harness.requests[1].queryParameters['page_size'], 30);
  });

  test(
    'decodes room play info and H5 room details with endpoint parameters',
    () async {
      final harness = HttpTestHarness((request) {
        if (request.path == Api.liveRoomInfo) {
          return jsonResponse(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{
              'room_id': 123,
              'live_status': 1,
              'live_time': 456,
              'playurl_info': <String, Object?>{
                'playurl': <String, Object?>{
                  'cid': 789,
                  'g_qn_desc': <Object?>[],
                  'stream': <Object?>[],
                },
              },
            },
          });
        }
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'room_info': <String, Object?>{'room_id': 123, 'title': '测试直播间'},
            'anchor_info': <String, Object?>{
              'base_info': <String, Object?>{'uname': '主播'},
              'relation_info': <String, Object?>{'attention': 7},
            },
            'like_info_v3': <String, Object?>{'total_likes': 8},
          },
        });
      });

      final playInfo = await harness.run(
        () => LiveHttp.liveRoomInfo(roomId: 123, qn: 10000),
      );
      final roomInfo = await harness.run(
        () => LiveHttp.liveRoomInfoH5(roomId: 123),
      );

      expect(playInfo, isA<ApiSuccess<RoomInfoModel>>());
      final decodedPlayInfo = (playInfo as ApiSuccess<RoomInfoModel>).data;
      expect(decodedPlayInfo.roomId, 123);
      expect(decodedPlayInfo.playurlInfo!.playurl!.cid, 789);
      expect(roomInfo, isA<ApiSuccess<RoomInfoH5Model>>());
      final decodedRoomInfo = (roomInfo as ApiSuccess<RoomInfoH5Model>).data;
      expect(decodedRoomInfo.roomInfo!.title, '测试直播间');
      expect(decodedRoomInfo.anchorInfo!.baseInfo!.uname, '主播');

      final playRequest = harness.requests[0];
      expect(playRequest.path, Api.liveRoomInfo);
      expect(playRequest.queryParameters['room_id'], 123);
      expect(playRequest.queryParameters['protocol'], '0, 1');
      expect(playRequest.queryParameters['format'], '0, 1, 2');
      expect(playRequest.queryParameters['codec'], '0, 1');
      expect(playRequest.queryParameters['qn'], 10000);
      expect(playRequest.queryParameters['platform'], 'web');
      expect(harness.requests[1].path, Api.liveRoomInfoH5);
      expect(harness.requests[1].queryParameters['room_id'], 123);
    },
  );

  test(
    'reports a malformed live list instead of silently returning data',
    () async {
      final harness = HttpTestHarness(
        (_) => jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{'list': <String, Object?>{}},
        }),
      );

      final result = await harness.run(() => LiveHttp.liveList());

      expect(result, isA<ApiFailure<List<LiveItemModel>>>());
      expect(
        (result as ApiFailure<List<LiveItemModel>>).kind,
        ApiFailureKind.malformedResponse,
      );
    },
  );
}

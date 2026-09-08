import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/dynamics.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/models/dynamics/up.dart';
import 'package:pilipalaz/utils/storage.dart';

import 'support/http_test_harness.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz_dynamics_http_test_',
    );
    Hive.init(hiveDirectory.path);
    GStorage.localCache = await Hive.openBox<dynamic>('localCache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  setUp(() => GStorage.localCache.clear());

  test(
    'signs regular dynamic feed requests and leaves PGC requests unsigned',
    () async {
      final harness = HttpTestHarness((request) {
        if (request.uri.path == '/x/web-interface/nav') {
          return jsonResponse(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{
              'wbi_img': <String, Object?>{
                'img_url':
                    'https://i0.hdslb.com/bfs/wbi/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png',
                'sub_url':
                    'https://i0.hdslb.com/bfs/wbi/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.png',
              },
            },
          });
        }
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'has_more': false,
            'items': <Object?>[],
            'offset': '',
          },
        });
      });

      final regular = await harness.run(
        () =>
            DynamicsHttp.followDynamic(type: 'all', offset: 'cursor', mid: -1),
      );
      final pgc = await harness.run(
        () =>
            DynamicsHttp.followDynamic(type: 'pgc', offset: 'ignored', mid: -1),
      );

      expect(regular, isA<ApiSuccess<DynamicsDataModel>>());
      expect(pgc, isA<ApiSuccess<DynamicsDataModel>>());
      expect(harness.requests, hasLength(3));
      final signedRequest = harness.requests[1];
      expect(signedRequest.path, Api.followDynamic);
      expect(signedRequest.queryParameters['offset'], 'cursor');
      expect(signedRequest.queryParameters['timezone_offset'], '-480');
      expect(signedRequest.queryParameters['wts'], isA<String>());
      expect(
        signedRequest.queryParameters['w_rid'],
        matches(RegExp(r'^[0-9a-f]{32}$')),
      );
      final pgcRequest = harness.requests[2];
      expect(pgcRequest.queryParameters.containsKey('offset'), isFalse);
      expect(pgcRequest.queryParameters.containsKey('wts'), isFalse);
      expect(pgcRequest.queryParameters.containsKey('w_rid'), isFalse);
    },
  );

  test(
    'decodes followed users and a dynamic detail, then sends a like',
    () async {
      final harness = HttpTestHarness((request) {
        if (request.path == Api.followUp) {
          return jsonResponse(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{
              'up_list': <Object?>[
                <String, Object?>{'mid': 42, 'uname': '测试用户'},
              ],
            },
          });
        }
        if (request.path == Api.dynamicDetail) {
          return jsonResponse(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{
              'item': <String, Object?>{
                'id_str': '1000',
                'type': 'DYNAMIC_TYPE_WORD',
                'modules': <String, Object?>{},
              },
            },
          });
        }
        return jsonResponse(<String, Object?>{'code': 0});
      });
      await harness.seedCsrf();

      final followed = await harness.run(DynamicsHttp.followUp);
      final detail = await harness.run(
        () => DynamicsHttp.dynamicDetail(id: '1000'),
      );
      final liked = await harness.run(
        () => DynamicsHttp.likeDynamic(dynamicId: '1000', up: 1),
      );

      expect(followed, isA<ApiSuccess<FollowUpModel>>());
      expect(
        (followed as ApiSuccess<FollowUpModel>).data.upList!.single.mid,
        42,
      );
      expect(detail, isA<ApiSuccess<DynamicItemModel>>());
      expect((detail as ApiSuccess<DynamicItemModel>).data.idStr, '1000');
      expect(liked, isA<ApiSuccess<void>>());
      expect(harness.requests[2].method, 'POST');
      expect(harness.requests[2].queryParameters['dynamic_id'], '1000');
      expect(harness.requests[2].queryParameters['up'], 1);
      expect(harness.requests[2].queryParameters['csrf'], 'test-csrf');
    },
  );

  test('maps the restricted PGC dynamic response to a clear failure', () async {
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{
        'code': 4101132,
        'message': 'server message',
      }),
    );

    final result = await harness.run(
      () => DynamicsHttp.followDynamic(type: 'pgc', mid: -1),
    );

    expect(result, isA<ApiFailure<DynamicsDataModel>>());
    final failure = result as ApiFailure<DynamicsDataModel>;
    expect(failure.apiCode, 4101132);
    expect(failure.message, '当前账号无法访问番剧动态，可能被平台限制');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/black.dart';
import 'package:pilipalaz/http/fan.dart';
import 'package:pilipalaz/http/follow.dart';
import 'package:pilipalaz/models/fans/result.dart';
import 'package:pilipalaz/models/follow/result.dart';
import 'package:pilipalaz/models/user/black.dart';

import 'support/http_test_harness.dart';

void main() {
  test(
    'decodes follow and fan lists and omits optional null parameters',
    () async {
      final harness = HttpTestHarness((request) {
        final item = <String, Object?>{
          'mid': 42,
          'uname': '测试用户',
          'sign': '',
          'tag': <Object?>[],
          'official_verify': <String, Object?>{},
        };
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'total': 1,
            'list': <Object?>[item],
          },
        });
      });

      final follows = await harness.run(
        () => FollowHttp.followings(vmid: 100, pn: 2, ps: 20),
      );
      final fans = await harness.run(
        () => FanHttp.fans(vmid: 100, pn: 3, ps: 30, orderType: 'attention'),
      );

      expect(follows, isA<ApiSuccess<FollowDataModel>>());
      expect(
        (follows as ApiSuccess<FollowDataModel>).data.list!.single.mid,
        42,
      );
      expect(fans, isA<ApiSuccess<FansDataModel>>());
      expect((fans as ApiSuccess<FansDataModel>).data.list!.single.mid, 42);
      expect(harness.requests[0].path, Api.followings);
      expect(
        harness.requests[0].queryParameters.containsKey('order_type'),
        isFalse,
      );
      expect(harness.requests[0].queryParameters.values, isNot(contains(null)));
      expect(harness.requests[1].path, Api.fans);
      expect(harness.requests[1].queryParameters['order_type'], 'attention');
    },
  );

  test('decodes blacklist and sends remove action with CSRF', () async {
    final harness = HttpTestHarness((request) {
      if (request.path == Api.blackLst) {
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'total': 1,
            'list': <Object?>[
              <String, Object?>{'mid': 42, 'uname': '已屏蔽用户'},
            ],
          },
        });
      }
      return jsonResponse(<String, Object?>{'code': 0});
    });
    await harness.seedCsrf();

    final list = await harness.run(() => BlackHttp.blackList(pn: 2, ps: 10));
    final removed = await harness.run(() => BlackHttp.removeBlack(fid: 42));

    expect(list, isA<ApiSuccess<BlackListDataModel>>());
    expect((list as ApiSuccess<BlackListDataModel>).data.list!.single.mid, 42);
    expect(harness.requests[0].queryParameters['pn'], 2);
    expect(harness.requests[0].queryParameters['ps'], 10);
    expect(removed, isA<ApiSuccess<void>>());
    expect(harness.requests[1].method, 'POST');
    expect(harness.requests[1].queryParameters['fid'], 42);
    expect(harness.requests[1].queryParameters['act'], 6);
    expect(harness.requests[1].queryParameters['csrf'], 'test-csrf');
  });

  test('propagates a social API rejection as a typed failure', () async {
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{'code': -400, 'message': '请求错误'}),
    );

    final result = await harness.run(
      () => FollowHttp.followings(vmid: 100, pn: 1, ps: 20),
    );

    expect(result, isA<ApiFailure<FollowDataModel>>());
    final failure = result as ApiFailure<FollowDataModel>;
    expect(failure.kind, ApiFailureKind.apiRejected);
    expect(failure.apiCode, -400);
    expect(failure.message, '请求错误');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/danmaku_block.dart';
import 'package:pilipalaz/models/user/danmaku_block.dart';

import 'support/http_test_harness.dart';

void main() {
  test('decodes, adds, and deletes danmaku filter rules', () async {
    final harness = HttpTestHarness((request) {
      if (request.path == Api.danmakuFilter) {
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'rule': <Object?>[
              <String, Object?>{'id': 7, 'type': 0, 'filter': '剧透'},
            ],
            'valid': 1,
          },
        });
      }
      if (request.path == Api.danmakuFilterAdd) {
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{'id': 8, 'type': 1, 'filter': '测试'},
        });
      }
      return jsonResponse(<String, Object?>{'code': 0});
    });
    await harness.seedCsrf();

    final list = await harness.run(DanmakuFilterHttp.danmakuFilter);
    final added = await harness.run(
      () => DanmakuFilterHttp.danmakuFilterAdd(filter: '测试', type: 1),
    );
    final deleted = await harness.run(
      () => DanmakuFilterHttp.danmakuFilterDel(ids: 8),
    );

    expect(list, isA<ApiSuccess<DanmakuBlockDataModel>>());
    expect((list as ApiSuccess<DanmakuBlockDataModel>).data.rule!.single.id, 7);
    expect(added, isA<ApiSuccess<Rule>>());
    expect((added as ApiSuccess<Rule>).data.id, 8);
    expect(deleted, isA<ApiSuccess<void>>());
    expect(harness.requests[1].method, 'POST');
    expect(harness.requests[1].queryParameters['filter'], '测试');
    expect(harness.requests[1].queryParameters['type'], 1);
    expect(harness.requests[1].queryParameters['csrf'], 'test-csrf');
    expect(harness.requests[2].queryParameters['ids'], 8);
    expect(harness.requests[2].queryParameters['csrf'], 'test-csrf');
  });

  test('rejects malformed filter payloads', () async {
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{'code': 0, 'data': <Object?>[]}),
    );

    final result = await harness.run(DanmakuFilterHttp.danmakuFilter);

    expect(result, isA<ApiFailure<DanmakuBlockDataModel>>());
    expect(
      (result as ApiFailure<DanmakuBlockDataModel>).kind,
      ApiFailureKind.malformedResponse,
    );
  });
}

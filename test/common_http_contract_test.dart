import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_client.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/common.dart';

import 'support/http_test_harness.dart';

void main() {
  test('decodes unread dynamics and sends all cursor parameters', () async {
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{
          'dyn_basic_infos': <Object?>[
            <String, Object?>{'dyn_id_str': '1000'},
          ],
        },
      }),
    );

    final result = await harness.run(CommonHttp.unReadDynamic);

    expect(result, isA<ApiSuccess<List<JsonObject>>>());
    expect(
      (result as ApiSuccess<List<JsonObject>>).data.single['dyn_id_str'],
      '1000',
    );
    final request = harness.requests.single;
    expect(request.path, Api.getUnreadDynamic);
    expect(request.queryParameters, <String, Object?>{
      'alltype_offset': 0,
      'video_offset': '',
      'article_offset': 0,
    });
  });

  test('rejects a non-list unread-dynamics payload', () async {
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{'dyn_basic_infos': <String, Object?>{}},
      }),
    );

    final result = await harness.run(CommonHttp.unReadDynamic);

    expect(result, isA<ApiFailure<List<JsonObject>>>());
    expect(
      (result as ApiFailure<List<JsonObject>>).kind,
      ApiFailureKind.malformedResponse,
    );
  });
}

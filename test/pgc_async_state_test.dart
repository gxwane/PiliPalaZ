import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PGC views handle typed async states without indexing dynamic data', () {
    final intro = File(
      'lib/pages/video/introduction/bangumi/view.dart',
    ).readAsStringSync();
    final catalog = File('lib/pages/bangumi/view.dart').readAsStringSync();

    expect(intro, contains('FutureBuilder<ApiResult<PgcInfoBundle>>'));
    expect(intro, contains('ApiFailure<PgcInfoBundle>'));
    expect(intro, isNot(contains("snapshot.data['status']")));
    expect(catalog, contains('FutureBuilder<ApiResult<BangumiListDataModel>>'));
    expect(catalog, isNot(contains('snapshot.data is Map')));
  });
}

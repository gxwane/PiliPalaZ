import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/search.dart';
import 'package:pilipalaz/models/search/result.dart';

void main() {
  test('video search keeps unblocked results and filters blocked mids', () {
    final originalItems = <Map<String, dynamic>>[
      _videoResult(mid: 42, aid: 1001),
      _videoResult(mid: 7, aid: 1002),
    ];

    final preparedItems = SearchHttp.prepareVideoResults(originalItems, <int>[
      7,
    ]);

    final model = SearchVideoModel.fromJson(<String, dynamic>{
      'result': preparedItems,
    });

    expect(model.list, hasLength(1));
    expect(model.list!.single.mid, 42);
    expect(preparedItems[0]['available'], isTrue);
    expect(preparedItems[1]['available'], isFalse);
    expect(originalItems[0], isNot(contains('available')));
    expect(originalItems[1], isNot(contains('available')));
  });
}

Map<String, dynamic> _videoResult({required int mid, required int aid}) {
  return <String, dynamic>{
    'mid': mid,
    'aid': aid,
    'bvid': 'BV1test$aid',
    'title': '测试视频',
    'duration': '01:00',
    'pic': '',
    'author': '作者',
  };
}

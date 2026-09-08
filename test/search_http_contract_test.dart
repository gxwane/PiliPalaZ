import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/search.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/models/search/hot.dart';
import 'package:pilipalaz/models/search/result.dart';
import 'package:pilipalaz/models/search/suggest.dart';
import 'package:pilipalaz/utils/storage.dart';

import 'support/http_test_harness.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz_search_http_test_',
    );
    Hive.init(hiveDirectory.path);
    GStorage.localCache = await Hive.openBox<dynamic>('localCache');
    GStorage.onlineCache = await Hive.openBox<dynamic>('onlineCache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  setUp(() async {
    await GStorage.localCache.clear();
    await GStorage.onlineCache.clear();
  });

  test('decodes default keyword, hot words, and video page list', () async {
    final harness = HttpTestHarness((request) {
      if (request.path == Api.searchDefault) {
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{'name': '默认关键词'},
        });
      }
      if (request.path == Api.hotSearchList) {
        return jsonResponse(<String, Object?>{
          'code': 0,
          'list': <Object?>[
            <String, Object?>{'keyword': '热词', 'show_name': '热词'},
          ],
        });
      }
      return jsonResponse(<String, Object?>{
        'code': 0,
        'data': <Object?>[
          <String, Object?>{'cid': 987},
        ],
      });
    });

    final keyword = await harness.run(SearchHttp.defaultKeyword);
    final hotWords = await harness.run(SearchHttp.hotSearchList);
    final cid = await harness.run(() => SearchHttp.ab2c(bvid: 'BV1test'));

    expect(keyword, isA<ApiSuccess<String>>());
    expect((keyword as ApiSuccess<String>).data, '默认关键词');
    expect(hotWords, isA<ApiSuccess<HotSearchModel>>());
    expect(
      (hotWords as ApiSuccess<HotSearchModel>).data.list!.single.keyword,
      '热词',
    );
    expect(cid, isA<ApiSuccess<int>>());
    expect((cid as ApiSuccess<int>).data, 987);
    expect(harness.requests[0].path, Api.searchDefault);
    expect(harness.requests[1].path, Api.hotSearchList);
    expect(harness.requests[2].path, Api.ab2c);
    expect(harness.requests[2].queryParameters['bvid'], 'BV1test');
    expect(harness.requests[2].queryParameters.containsKey('aid'), isFalse);
  });

  testWidgets('decodes suggestions and sends highlighting parameters', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{
        'code': 0,
        'result': <String, Object?>{
          'tag': <Object?>[
            <String, Object?>{
              'value': 'flutter',
              'term': 'flutter',
              'name': '<em class="suggest_high_light">Flutter</em> 教程',
            },
          ],
        },
      }),
    );

    final result = await tester.runAsync(
      () => harness.run(() => SearchHttp.searchSuggest(term: 'Flutter')),
    );

    expect(result, isA<ApiSuccess<SearchSuggestModel>>());
    final suggestion =
        (result as ApiSuccess<SearchSuggestModel>).data.tag!.single;
    expect(suggestion.value, 'flutter');
    expect(suggestion.textRich, isA<Text>());
    final request = harness.requests.single;
    expect(request.path, Api.searchSuggest);
    expect(request.queryParameters['term'], 'Flutter');
    expect(request.queryParameters['main_ver'], 'v1');
    expect(request.queryParameters['highlight'], 'Flutter');
  });

  test(
    'signs and decodes every search type, preserving usable videos',
    () async {
      final harness = HttpTestHarness((request) {
        if (request.uri.path == '/x/web-interface/nav') {
          return _wbiKeyResponse();
        }
        final type = request.queryParameters['search_type'];
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'numPages': 1,
            'result': _searchItems(type),
          },
        });
      });
      await GStorage.onlineCache.put(OnlineCacheKey.blackMidsList, <int>[99]);

      final results = <SearchType, ApiResult<SearchPageData>>{};
      for (final type in SearchType.values) {
        results[type] = await harness.run(
          () => SearchHttp.searchByType(
            searchType: type,
            keyword: '测试关键词',
            page: 2,
            order: 'pubdate',
            duration: 3,
          ),
        );
      }

      expect(harness.requests, hasLength(SearchType.values.length + 1));
      expect(results[SearchType.video], isA<ApiSuccess<SearchPageData>>());
      final videos =
          (results[SearchType.video] as ApiSuccess<SearchPageData>).data.items;
      expect(videos, hasLength(1));
      expect(videos.single, isA<SearchVideoItemModel>());
      expect((videos.single as SearchVideoItemModel).mid, 42);
      expect(
        _singleItem(results, SearchType.live_room),
        isA<SearchLiveItemModel>(),
      );
      expect(
        _singleItem(results, SearchType.bili_user),
        isA<SearchUserItemModel>(),
      );
      expect(
        _singleItem(results, SearchType.media_bangumi),
        isA<SearchMBangumiItemModel>(),
      );
      expect(
        _singleItem(results, SearchType.media_ft),
        isA<SearchMBangumiItemModel>(),
      );
      expect(
        _singleItem(results, SearchType.article),
        isA<SearchArticleItemModel>(),
      );

      for (final request in harness.requests.skip(1)) {
        expect(request.path, Api.searchByType);
        expect(request.queryParameters['keyword'], '测试关键词');
        expect(request.queryParameters['page'], 2);
        expect(request.queryParameters['order'], 'pubdate');
        expect(request.queryParameters['duration'], 3);
        expect(request.queryParameters['wts'], isA<String>());
        expect(
          request.queryParameters['w_rid'],
          matches(RegExp(r'^[0-9a-f]{32}$')),
        );
      }
    },
  );

  test(
    'maps empty search pages and malformed page counts to failures',
    () async {
      var callCount = 0;
      final harness = HttpTestHarness((request) {
        if (request.uri.path == '/x/web-interface/nav') {
          return _wbiKeyResponse();
        }
        callCount += 1;
        return jsonResponse(<String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'numPages': callCount == 1 ? 0 : 'invalid',
            'result': <Object?>[],
          },
        });
      });

      final empty = await harness.run(
        () => SearchHttp.searchByType(
          searchType: SearchType.video,
          keyword: '没有结果',
          page: 1,
        ),
      );
      final malformed = await harness.run(
        () => SearchHttp.searchByType(
          searchType: SearchType.article,
          keyword: '异常结果',
          page: 1,
        ),
      );

      expect(empty, isA<ApiFailure<SearchPageData>>());
      expect(
        (empty as ApiFailure<SearchPageData>).kind,
        ApiFailureKind.apiRejected,
      );
      expect(empty.apiCode, -404);
      expect(malformed, isA<ApiFailure<SearchPageData>>());
      expect(
        (malformed as ApiFailure<SearchPageData>).kind,
        ApiFailureKind.malformedResponse,
      );
    },
  );
}

Object _singleItem(
  Map<SearchType, ApiResult<SearchPageData>> results,
  SearchType type,
) {
  final result = results[type];
  expect(result, isA<ApiSuccess<SearchPageData>>());
  return (result as ApiSuccess<SearchPageData>).data.items.single;
}

ResponseBody _wbiKeyResponse() {
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

List<Object?> _searchItems(Object? type) {
  return switch (type) {
    'video' => <Object?>[
      _videoItem(mid: 42, title: '可用视频'),
      _videoItem(mid: 99, title: '被屏蔽视频'),
    ],
    'live_room' => <Object?>[
      <String, Object?>{
        'uid': 1,
        'title': '测试直播',
        'cate_name': '游戏',
        'roomid': 2,
      },
    ],
    'bili_user' => <Object?>[
      <String, Object?>{'mid': 3, 'uname': '测试用户', 'upic': '//face.jpg'},
    ],
    'media_bangumi' || 'media_ft' => <Object?>[
      <String, Object?>{'media_id': 4, 'title': '测试影视'},
    ],
    'article' => <Object?>[
      <String, Object?>{'id': 5, 'title': '测试专栏'},
    ],
    _ => <Object?>[],
  };
}

Map<String, Object?> _videoItem({required int mid, required String title}) {
  return <String, Object?>{
    'mid': mid,
    'title': title,
    'duration': '01:02',
    'pic': '//cover.jpg',
    'author': '测试用户',
  };
}

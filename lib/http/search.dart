import 'package:hive/hive.dart';

import '../models/common/search_type.dart';
import '../models/search/hot.dart';
import '../models/search/result.dart';
import '../models/search/suggest.dart';
import '../utils/storage.dart';
import '../utils/wbi_sign.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

final class SearchPageData {
  const SearchPageData(this.items);

  final List<Object> items;
}

class SearchHttp {
  static Box<dynamic> get _onlineCache => GStorage.onlineCache;

  static Future<ApiResult<HotSearchModel>> hotSearchList() {
    return HttpRuntime.instance.client.getJson<HotSearchModel>(
      Api.hotSearchList,
      endpoint: 'search.hot',
      decode: (json) {
        BiliApiDecoder.success(json);
        return HotSearchModel.fromJson(json);
      },
    );
  }

  static Future<ApiResult<SearchSuggestModel>> searchSuggest({
    required String term,
  }) {
    return HttpRuntime.instance.client.getJson<SearchSuggestModel>(
      Api.searchSuggest,
      endpoint: 'search.suggest',
      queryParameters: <String, dynamic>{
        'term': term,
        'main_ver': 'v1',
        'highlight': term,
      },
      decode: (json) => BiliApiDecoder.result<SearchSuggestModel>(
        json,
        decode: (value) {
          final result = BiliApiDecoder.object(value, field: 'result');
          return SearchSuggestModel.fromJson(<String, dynamic>{
            ...result,
            'term': term,
          });
        },
      ),
    );
  }

  static Future<ApiResult<SearchPageData>> searchByType({
    required SearchType searchType,
    required String keyword,
    required int page,
    String? order,
    int? duration,
  }) async {
    final unsigned = <String, dynamic>{
      'search_type': searchType.type,
      'keyword': keyword,
      'page': page,
      if (order != null) 'order': order,
      if (duration != null) 'duration': duration,
    };
    final signed = await WbiSign().sign(unsigned);
    if (signed case ApiFailure<Map<String, dynamic>> failure) {
      return failure.cast<SearchPageData>();
    }

    return HttpRuntime.instance.client.getJson<SearchPageData>(
      Api.searchByType,
      endpoint: 'search.byType',
      queryParameters: (signed as ApiSuccess<Map<String, dynamic>>).data,
      decode: (json) => BiliApiDecoder.data<SearchPageData>(
        json,
        decode: (value) {
          final data = BiliApiDecoder.object(value, field: 'data');
          final pages = BiliApiDecoder.integer(
            data['numPages'],
            field: 'data.numPages',
          );
          if (pages == 0) {
            throw const ApiRejectedException(code: -404, message: '没有相关数据');
          }
          if (searchType == SearchType.video) {
            final blockedMids = _onlineCache
                .get(OnlineCacheKey.blackMidsList, defaultValue: <int>[-1])
                .map<int>((item) => item as int)
                .toList();
            for (final item in BiliApiDecoder.list(
              data['result'],
              field: 'data.result',
            )) {
              final video = BiliApiDecoder.object(item, field: 'data.result[]');
              video['available'] = !blockedMids.contains(video['mid']);
            }
          }
          return SearchPageData(_decodeItems(searchType, data));
        },
      ),
    );
  }

  static List<Object> _decodeItems(
    SearchType searchType,
    Map<String, dynamic> data,
  ) {
    return switch (searchType) {
      SearchType.video => <Object>[...?SearchVideoModel.fromJson(data).list],
      SearchType.live_room => <Object>[...?SearchLiveModel.fromJson(data).list],
      SearchType.bili_user => <Object>[...?SearchUserModel.fromJson(data).list],
      SearchType.media_bangumi || SearchType.media_ft => <Object>[
        ...?SearchMBangumiModel.fromJson(data).list,
      ],
      SearchType.article => <Object>[
        ...?SearchArticleModel.fromJson(data).list,
      ],
    };
  }

  static Future<ApiResult<int>> ab2c({int? aid, String? bvid}) {
    return HttpRuntime.instance.client.getJson<int>(
      Api.ab2c,
      endpoint: 'video.cid',
      queryParameters: <String, dynamic>{
        if (aid != null) 'aid': aid,
        if (aid == null && bvid != null) 'bvid': bvid,
      },
      decode: (json) => BiliApiDecoder.data<int>(
        json,
        decode: (value) {
          final pages = BiliApiDecoder.list(value, field: 'data');
          if (pages.isEmpty) {
            throw const MalformedApiResponseException('视频分P列表为空');
          }
          final first = BiliApiDecoder.object(pages.first, field: 'data[0]');
          return BiliApiDecoder.integer(first['cid'], field: 'data[0].cid');
        },
      ),
    );
  }
}

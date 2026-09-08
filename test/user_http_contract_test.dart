import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/user.dart';
import 'package:pilipalaz/models/user/fav_detail.dart';
import 'package:pilipalaz/models/user/fav_folder.dart';
import 'package:pilipalaz/models/user/history.dart';
import 'package:pilipalaz/models/user/info.dart';
import 'package:pilipalaz/models/user/stat.dart';
import 'package:pilipalaz/models/user/sub_detail.dart';
import 'package:pilipalaz/models/user/sub_folder.dart';

import 'support/http_test_harness.dart';

void main() {
  group('UserHttp read contracts', () {
    test(
      'decodes account profile, account stats, and history search',
      () async {
        final harness = HttpTestHarness((request) {
          if (request.path == Api.userInfo) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'isLogin': true,
                'mid': 100,
                'uname': '测试用户',
              },
            });
          }
          if (request.path == Api.userStatOwner) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'following': 1,
                'follower': 2,
                'dynamic_count': 3,
              },
            });
          }
          return jsonResponse(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{
              'has_more': false,
              'list': <Object?>[
                <String, Object?>{
                  'title': '搜索到的历史视频',
                  'history': <String, Object?>{'oid': 7, 'business': 'archive'},
                },
              ],
            },
          });
        });

        final profile = await harness.run(UserHttp.userInfo);
        final stats = await harness.run(UserHttp.userStatOwner);
        final history = await harness.run(
          () => UserHttp.searchHistory(pn: 2, keyword: 'Flutter'),
        );

        expect(profile, isA<ApiSuccess<UserInfoData>>());
        expect((profile as ApiSuccess<UserInfoData>).data.mid, 100);
        expect(stats, isA<ApiSuccess<UserStat>>());
        expect((stats as ApiSuccess<UserStat>).data.follower, 2);
        expect(history, isA<ApiSuccess<HistoryData>>());
        expect(
          (history as ApiSuccess<HistoryData>).data.list!.single.title,
          '搜索到的历史视频',
        );
        expect(harness.requests[2].path, Api.searchHistory);
        expect(harness.requests[2].queryParameters, <String, Object?>{
          'pn': 2,
          'keyword': 'Flutter',
          'business': 'all',
        });
      },
    );

    test(
      'decodes favorite folders and details with their query parameters',
      () async {
        final harness = HttpTestHarness((request) {
          if (request.path == Api.userFavFolder) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'count': 1,
                'has_more': false,
                'list': <Object?>[
                  <String, Object?>{'id': 9, 'title': '收藏夹'},
                ],
              },
            });
          }
          return jsonResponse(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{
              'info': <String, Object?>{'id': 9},
              'has_more': false,
              'medias': <Object?>[
                <String, Object?>{
                  'id': 42,
                  'title': '视频',
                  'upper': <String, Object?>{},
                  'cnt_info': <String, Object?>{},
                },
              ],
            },
          });
        });

        final folders = await harness.run(
          () => UserHttp.userfavFolder(pn: 2, ps: 20, mid: 100),
        );
        final details = await harness.run(
          () => UserHttp.userFavFolderDetail(
            mediaId: 9,
            pn: 3,
            ps: 30,
            keyword: 'flutter',
            order: 'pubtime',
            type: 2,
          ),
        );

        expect(folders, isA<ApiSuccess<FavFolderData>>());
        expect((folders as ApiSuccess<FavFolderData>).data.list!.single.id, 9);
        expect(details, isA<ApiSuccess<FavDetailData>>());
        expect(
          (details as ApiSuccess<FavDetailData>).data.medias!.single.id,
          42,
        );
        expect(harness.requests[0].queryParameters, <String, Object?>{
          'pn': 2,
          'ps': 20,
          'up_mid': 100,
        });
        expect(
          harness.requests[1].queryParameters,
          containsPair('media_id', 9),
        );
        expect(
          harness.requests[1].queryParameters,
          containsPair('keyword', 'flutter'),
        );
        expect(
          harness.requests[1].queryParameters,
          containsPair('order', 'pubtime'),
        );
        expect(harness.requests[1].queryParameters, containsPair('type', 2));
      },
    );

    test(
      'decodes watch-later, history, and history status responses',
      () async {
        final harness = HttpTestHarness((request) {
          if (request.path == Api.seeYouLater) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'count': 1,
                'list': <Object?>[
                  <String, Object?>{
                    'aid': 7,
                    'bvid': 'BV1test',
                    'owner': <String, Object?>{},
                    'stat': <String, Object?>{},
                    'dimension': <String, Object?>{},
                  },
                ],
              },
            });
          }
          if (request.path == Api.historyList) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'has_more': false,
                'list': <Object?>[
                  <String, Object?>{
                    'title': '历史视频',
                    'history': <String, Object?>{
                      'oid': 7,
                      'business': 'archive',
                    },
                  },
                ],
              },
            });
          }
          return jsonResponse(<String, Object?>{'code': 0, 'data': true});
        });

        final later = await harness.run(UserHttp.seeYouLater);
        final history = await harness.run(() => UserHttp.historyList(7, 99));
        final status = await harness.run(UserHttp.historyStatus);

        expect(later, isA<ApiSuccess<WatchLaterData>>());
        expect((later as ApiSuccess<WatchLaterData>).data.items.single.aid, 7);
        expect(history, isA<ApiSuccess<HistoryData>>());
        expect(
          (history as ApiSuccess<HistoryData>).data.list!.single.title,
          '历史视频',
        );
        expect(status, isA<ApiSuccess<bool>>());
        expect((status as ApiSuccess<bool>).data, isTrue);
        expect(harness.requests[1].queryParameters, <String, Object?>{
          'type': 'all',
          'ps': 20,
          'max': 7,
          'view_at': 99,
        });
      },
    );

    test(
      'turns API rejection and malformed history status into failures',
      () async {
        var responseIndex = 0;
        final harness = HttpTestHarness((_) {
          responseIndex += 1;
          return responseIndex == 1
              ? jsonResponse(<String, Object?>{
                  'code': -101,
                  'message': '账号未登录',
                })
              : jsonResponse(<String, Object?>{'code': 0, 'data': 'yes'});
        });

        final rejected = await harness.run(
          () => UserHttp.userfavFolder(pn: 1, ps: 20, mid: 100),
        );
        final malformed = await harness.run(UserHttp.historyStatus);

        expect(rejected, isA<ApiFailure<FavFolderData>>());
        expect((rejected as ApiFailure<FavFolderData>).apiCode, -101);
        expect(malformed, isA<ApiFailure<bool>>());
        expect(
          (malformed as ApiFailure<bool>).kind,
          ApiFailureKind.malformedResponse,
        );
      },
    );
  });

  group('UserHttp mutation contracts', () {
    test('sends watch-later and history mutations with CSRF', () async {
      final harness = HttpTestHarness(
        (_) => jsonResponse(<String, Object?>{'code': 0, 'data': null}),
      );
      await harness.seedCsrf();

      await harness.run(() => UserHttp.pauseHistory(true));
      await harness.run(UserHttp.clearHistory);
      await harness.run(() => UserHttp.toViewLater(bvid: 'BV1test'));
      await harness.run(() => UserHttp.toViewDel(aid: 7));
      await harness.run(() => UserHttp.toViewDel());
      await harness.run(UserHttp.toViewClear);
      await harness.run(() => UserHttp.delHistory('archive_7'));

      expect(harness.requests, hasLength(7));
      for (final request in harness.requests) {
        expect(request.method, 'POST');
        expect(request.queryParameters['csrf'], 'test-csrf');
      }
      expect(harness.requests[0].queryParameters['switch'], isTrue);
      expect(harness.requests[2].queryParameters['bvid'], 'BV1test');
      expect(harness.requests[3].queryParameters['aid'], 7);
      expect(harness.requests[4].queryParameters['viewed'], isTrue);
      expect(harness.requests[6].queryParameters['kid'], 'archive_7');
    });
  });

  group('UserHttp subscription contracts', () {
    test(
      'decodes subscription lists and routes cancellation by type',
      () async {
        final harness = HttpTestHarness((request) {
          if (request.path == Api.userSubFolder) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'count': 1,
                'list': <Object?>[
                  <String, Object?>{'id': 11, 'title': '订阅'},
                ],
              },
            });
          }
          if (request.path == Api.favSeasonList ||
              request.path == Api.favResourceList) {
            return jsonResponse(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'info': <String, Object?>{'id': 11, 'title': '订阅详情'},
                'medias': <Object?>[],
              },
            });
          }
          return jsonResponse(<String, Object?>{'code': 0});
        });
        await harness.seedCsrf();

        final folders = await harness.run(
          () => UserHttp.userSubFolder(mid: 100, pn: 1, ps: 20),
        );
        final season = await harness.run(
          () => UserHttp.favSeasonList(id: 11, pn: 2, ps: 30),
        );
        final resource = await harness.run(
          () => UserHttp.favResourceList(id: 12, pn: 3, ps: 40),
        );
        await harness.run(() => UserHttp.cancelSub(id: 11, type: 12));
        await harness.run(() => UserHttp.cancelSub(id: 12, type: 11));

        expect(folders, isA<ApiSuccess<SubFolderModelData>>());
        expect(
          (folders as ApiSuccess<SubFolderModelData>).data.list!.single.id,
          11,
        );
        expect(season, isA<ApiSuccess<SubDetailModelData>>());
        expect((season as ApiSuccess<SubDetailModelData>).data.info!.id, 11);
        expect(resource, isA<ApiSuccess<SubDetailModelData>>());
        expect(harness.requests[3].path, Api.unfavSeason);
        expect(harness.requests[3].queryParameters['season_id'], 11);
        expect(harness.requests[3].queryParameters['platform'], 'web');
        expect(harness.requests[4].path, Api.unfavFolder);
        expect(harness.requests[4].queryParameters['media_id'], 12);
      },
    );
  });
}

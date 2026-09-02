import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/services/pgc_vip_entitlement_resolver.dart';

void main() {
  group('PgcVipEntitlementResolver', () {
    test('classifies seasons from episode-level access fields', () {
      expect(
        PgcVipEntitlementResolver.fromInfo(
          BangumiInfoModel(
            episodes: <EpisodeItem>[
              EpisodeItem(status: 2),
              EpisodeItem(status: 2),
            ],
          ),
        ),
        PgcVipEntitlement.unrestricted,
      );
      expect(
        PgcVipEntitlementResolver.fromInfo(
          BangumiInfoModel(
            episodes: <EpisodeItem>[
              EpisodeItem(status: 2),
              EpisodeItem(status: 13, badge: '会员'),
            ],
          ),
        ),
        PgcVipEntitlement.restricted,
      );
      expect(
        PgcVipEntitlementResolver.fromInfo(
          BangumiInfoModel(
            episodes: <EpisodeItem>[
              EpisodeItem(status: 2),
              EpisodeItem(status: 2, badge: '大会员'),
            ],
          ),
        ),
        PgcVipEntitlement.restricted,
      );
      expect(
        PgcVipEntitlementResolver.fromInfo(BangumiInfoModel(episodes: [])),
        isNull,
      );
    });

    test('shares in-flight work and caches successful results', () async {
      int calls = 0;
      final PgcVipEntitlementResolver resolver = PgcVipEntitlementResolver(
        loader: ({int? seasonId, int? epId}) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return ApiSuccess<BangumiInfoModel>(
            BangumiInfoModel(episodes: <EpisodeItem>[EpisodeItem(status: 2)]),
          );
        },
      );

      final List<PgcVipEntitlement?> first = await Future.wait(
        <Future<PgcVipEntitlement?>>[resolver.resolve(1), resolver.resolve(1)],
      );
      final PgcVipEntitlement? cached = await resolver.resolve(1);

      expect(first, <PgcVipEntitlement?>[
        PgcVipEntitlement.unrestricted,
        PgcVipEntitlement.unrestricted,
      ]);
      expect(cached, PgcVipEntitlement.unrestricted);
      expect(calls, 1);
    });

    test('limits concurrent detail requests', () async {
      int active = 0;
      int peak = 0;
      final PgcVipEntitlementResolver resolver = PgcVipEntitlementResolver(
        maxConcurrent: 2,
        loader: ({int? seasonId, int? epId}) async {
          active += 1;
          if (active > peak) peak = active;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          active -= 1;
          return ApiSuccess<BangumiInfoModel>(
            BangumiInfoModel(episodes: <EpisodeItem>[EpisodeItem(status: 2)]),
          );
        },
      );

      await Future.wait(<Future<PgcVipEntitlement?>>[
        resolver.resolve(1),
        resolver.resolve(2),
        resolver.resolve(3),
        resolver.resolve(4),
      ]);

      expect(peak, 2);
    });

    test('does not cache failed or incomplete lookups', () async {
      int calls = 0;
      final PgcVipEntitlementResolver resolver = PgcVipEntitlementResolver(
        loader: ({int? seasonId, int? epId}) async {
          calls += 1;
          return const ApiFailure<BangumiInfoModel>(
            kind: ApiFailureKind.network,
            message: 'offline',
          );
        },
      );

      expect(await resolver.resolve(1), isNull);
      expect(await resolver.resolve(1), isNull);
      expect(calls, 2);
    });
  });
}

import 'dart:async';
import 'dart:collection';

import '../http/pgc.dart';
import '../http/api_result.dart';
import '../models/bangumi/info.dart';

enum PgcVipEntitlement { unrestricted, restricted }

typedef PgcSeasonInfoLoader =
    Future<ApiResult<BangumiInfoModel>> Function({int? seasonId, int? epId});

class PgcVipEntitlementResolver {
  PgcVipEntitlementResolver({
    PgcSeasonInfoLoader? loader,
    this.maxConcurrent = 4,
  }) : assert(maxConcurrent > 0),
       _loader = loader ?? PgcApi.instance.info;

  final PgcSeasonInfoLoader _loader;
  final int maxConcurrent;
  final Map<int, PgcVipEntitlement> _cache = <int, PgcVipEntitlement>{};
  final Map<int, Completer<PgcVipEntitlement?>> _pending =
      <int, Completer<PgcVipEntitlement?>>{};
  final Queue<int> _queue = Queue<int>();
  int _active = 0;

  Future<PgcVipEntitlement?> resolve(int seasonId) {
    final PgcVipEntitlement? cached = _cache[seasonId];
    if (cached != null) return Future<PgcVipEntitlement?>.value(cached);

    final Completer<PgcVipEntitlement?>? pending = _pending[seasonId];
    if (pending != null) return pending.future;

    final Completer<PgcVipEntitlement?> completer =
        Completer<PgcVipEntitlement?>();
    _pending[seasonId] = completer;
    _queue.addLast(seasonId);
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final int seasonId = _queue.removeFirst();
      final Completer<PgcVipEntitlement?>? completer = _pending[seasonId];
      if (completer == null) continue;
      _active += 1;
      unawaited(_run(seasonId, completer));
    }
  }

  Future<void> _run(
    int seasonId,
    Completer<PgcVipEntitlement?> completer,
  ) async {
    PgcVipEntitlement? entitlement;
    try {
      final result = await _loader(seasonId: seasonId);
      if (result case ApiSuccess<BangumiInfoModel>(:final data)) {
        entitlement = fromInfo(data);
        if (entitlement != null) _cache[seasonId] = entitlement;
      }
    } catch (_) {
      entitlement = null;
    } finally {
      if (!completer.isCompleted) completer.complete(entitlement);
      _pending.remove(seasonId);
      _active -= 1;
      _drain();
    }
  }

  static PgcVipEntitlement? fromInfo(BangumiInfoModel info) {
    final List<EpisodeItem> episodes = info.episodes ?? const <EpisodeItem>[];
    if (episodes.isEmpty) return null;
    final bool restricted = episodes.any((EpisodeItem episode) {
      final String badge = episode.badge?.trim() ?? '';
      return episode.status == 13 || badge.contains('会员');
    });
    return restricted
        ? PgcVipEntitlement.restricted
        : PgcVipEntitlement.unrestricted;
  }
}

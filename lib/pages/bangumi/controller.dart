import 'dart:async';

import 'package:pilipalaz/utils/extension.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/pgc.dart';
import 'package:pilipalaz/models/bangumi/list.dart';
import 'package:pilipalaz/models/common/pgc_type.dart';
import 'package:pilipalaz/models/user/info.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/services/pgc_vip_entitlement_resolver.dart';

class BangumiController extends GetxController {
  final ScrollController scrollController = ScrollController();
  RxList<BangumiListItemModel> bangumiList = <BangumiListItemModel>[].obs;
  RxList<BangumiListItemModel> bangumiFollowList = <BangumiListItemModel>[].obs;
  Rx<PgcCatalogType> catalogType = PgcCatalogType.bangumi.obs;
  Rx<PgcCatalogOrder> catalogOrder = PgcCatalogOrder.mostFollowed.obs;
  int _currentPage = 1;
  bool isLoadingMore = false;
  bool _hasNext = true;
  Box<dynamic> userInfoCache = GStorage.userInfo;
  RxBool userLogin = false.obs;
  UserInfoData? userInfo;
  final PgcVipEntitlementResolver _vipEntitlementResolver =
      PgcVipEntitlementResolver();
  final RxMap<int, PgcVipEntitlement> vipEntitlements =
      <int, PgcVipEntitlement>{}.obs;

  @override
  void onInit() {
    super.onInit();
    catalogType.value = PgcCatalogTypeCode.fromApiValue(
      GStorage.setting.get(PgcSettingKey.catalogType),
    );
    catalogOrder.value = PgcCatalogOrderCode.fromApiValue(
      GStorage.setting.get(PgcSettingKey.catalogOrder),
    );
    userInfo = userInfoCache.get('userInfoCache') as UserInfoData?;
    userLogin.value = userInfo != null;
  }

  Future<Map<String, dynamic>> queryBangumiListFeed({
    String type = 'init',
  }) async {
    if (type == 'init') {
      _currentPage = 1;
      _hasNext = true;
    }
    if (type != 'init' && (isLoadingMore || !_hasNext)) {
      return <String, dynamic>{'status': true};
    }
    if (type != 'init') isLoadingMore = true;
    final PgcCatalogType requestedType = catalogType.value;
    final PgcCatalogOrder requestedOrder = catalogOrder.value;
    final int requestedPage = _currentPage;
    final Map<String, dynamic> result = await PgcHttp.catalog(
      type: requestedType,
      order: requestedOrder,
      page: requestedPage,
    );
    if (requestedType != catalogType.value ||
        requestedOrder != catalogOrder.value) {
      if (type != 'init') isLoadingMore = false;
      return <String, dynamic>{'status': true};
    }
    if (result['status']) {
      final BangumiListDataModel data = result['data'];
      final List<BangumiListItemModel> list = List<BangumiListItemModel>.from(
        data.list ?? const [],
      );
      if (type == 'init') {
        bangumiList.value = list;
      } else {
        bangumiList.addAll(list);
      }
      _resolveVipEntitlements(list);
      _currentPage += 1;
      _hasNext = data.hasNext == 1 && list.isNotEmpty;
    }
    if (type != 'init') isLoadingMore = false;
    return result;
  }

  // 上拉加载
  Future<Map<String, dynamic>> onLoad() async {
    return queryBangumiListFeed(type: 'onLoad');
  }

  // 我的订阅
  Future<Map<String, dynamic>?> queryBangumiFollow() async {
    userInfo ??= userInfoCache.get('userInfoCache') as UserInfoData?;
    if (userInfo == null) {
      return null;
    }
    final PgcFollowGroup requestedGroup = catalogType.value.followGroup;
    final Map<String, dynamic> result = await PgcHttp.follow(
      mid: userInfo!.mid!,
      group: requestedGroup,
    );
    if (requestedGroup != catalogType.value.followGroup) {
      return <String, dynamic>{'status': true};
    }
    if (result['status']) {
      bangumiFollowList.value = List<BangumiListItemModel>.from(
        result['data'].list ?? const [],
      );
    }
    return result;
  }

  Future<void> selectCatalog(PgcCatalogType value) async {
    if (catalogType.value == value) return;
    final PgcFollowGroup previousGroup = catalogType.value.followGroup;
    catalogType.value = value;
    isLoadingMore = false;
    if (previousGroup != value.followGroup) {
      bangumiFollowList.clear();
    }
    await GStorage.setting.put(PgcSettingKey.catalogType, value.apiValue);
  }

  Future<void> selectOrder(PgcCatalogOrder value) async {
    if (catalogOrder.value == value) return;
    catalogOrder.value = value;
    isLoadingMore = false;
    await GStorage.setting.put(PgcSettingKey.catalogOrder, value.apiValue);
  }

  PgcVipEntitlement? vipEntitlementFor(BangumiListItemModel item) {
    final int? seasonId = item.seasonId;
    return seasonId == null ? null : vipEntitlements[seasonId];
  }

  void _resolveVipEntitlements(List<BangumiListItemModel> items) {
    for (final BangumiListItemModel item in items) {
      final int? seasonId = item.seasonId;
      final String badge = item.badge?.trim() ?? '';
      final bool needsVerification =
          seasonId != null && item.badgeType == 0 && badge.contains('会员');
      if (!needsVerification || vipEntitlements.containsKey(seasonId)) {
        continue;
      }
      unawaited(
        _vipEntitlementResolver.resolve(seasonId).then((entitlement) {
          if (entitlement != null && !isClosed) {
            vipEntitlements[seasonId] = entitlement;
          }
        }),
      );
    }
  }

  // 返回顶部并刷新
  void animateToTop() {
    scrollController.animToTop();
  }
}

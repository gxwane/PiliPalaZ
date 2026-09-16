import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/search.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/utils/app_scheme.dart';

void _openUrl(String? rawUrl, {String? title}) {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    SmartDialog.showToast('未获取到有效链接');
    return;
  }
  String url = rawUrl.trim();
  if (url.startsWith('//')) {
    url = 'https:$url';
  } else if (!url.startsWith('http://') &&
      !url.startsWith('https://') &&
      !url.startsWith('bilibili://')) {
    url = 'https://$url';
  }

  if (url.startsWith('bilibili://')) {
    PiliScheme.routePush(Uri.parse(url));
    return;
  }

  Get.toNamed(
    '/webview',
    parameters: {'url': url, 'type': 'url', 'pageTitle': title ?? ''},
  );
}

Widget addWidget(
  dynamic item,
  BuildContext context,
  String? type, {
  int floor = 1,
}) {
  final dynamic modules = item?.modules;
  final ModuleDynamicModel? moduleDynamic = modules?.moduleDynamic;
  final DynamicAddModel? additional = moduleDynamic?.additional;

  if (additional == null || type == null) {
    return const SizedBox.shrink();
  }

  final Color bgColor = floor == 1
      ? Theme.of(context).dividerColor.withOpacity(0.08)
      : Theme.of(context).colorScheme.surface;
  final EdgeInsets margin = floor == 1
      ? const EdgeInsets.only(left: 12, right: 12, top: 8)
      : const EdgeInsets.only(top: 8);
  const BorderRadius borderRadius = BorderRadius.all(Radius.circular(6));

  switch (type) {
    case 'ADDITIONAL_TYPE_UGC':
      final Ugc? ugc = additional.ugc;
      if (ugc == null) return const SizedBox.shrink();
      return Container(
        margin: margin,
        child: Material(
          color: bgColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final text = ugc.jumpUrl ?? '';
              final RegExp bvRegex = RegExp(
                r'BV[0-9A-Za-z]{10}',
                caseSensitive: false,
              );
              final Iterable<Match> matches = bvRegex.allMatches(text);
              if (matches.isNotEmpty) {
                final bvid = matches.first.group(0)!;
                final cover = ugc.cover ?? '';
                try {
                  final cidResult = await SearchHttp.ab2c(bvid: bvid);
                  if (cidResult case ApiFailure<int>(:final message)) {
                    SmartDialog.showToast(message);
                    return;
                  }
                  final cid = (cidResult as ApiSuccess<int>).data;
                  Get.toNamed(
                    '/video?bvid=$bvid&cid=$cid',
                    arguments: {'pic': cover, 'heroTag': bvid},
                  );
                } catch (err) {
                  SmartDialog.showToast(err.toString());
                }
              } else if (text.isNotEmpty) {
                _openUrl(text, title: ugc.title);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  NetworkImgLayer(width: 120, height: 75, src: ugc.cover ?? ''),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ugc.title ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ugc.descSecond != null &&
                            ugc.descSecond!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            ugc.descSecond!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: Theme.of(
                                context,
                              ).textTheme.labelMedium?.fontSize,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

    case 'ADDITIONAL_TYPE_RESERVE':
      final Reserve? reserve = additional.reserve;
      if (reserve == null || reserve.state == -1 || reserve.title == null) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: margin,
        child: Material(
          color: bgColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (reserve.jumpUrl != null && reserve.jumpUrl!.isNotEmpty) {
                _openUrl(reserve.jumpUrl, title: reserve.title);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reserve.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: Theme.of(
                          context,
                        ).textTheme.labelMedium?.fontSize,
                      ),
                      children: [
                        if (reserve.desc1 != null &&
                            reserve.desc1?['text'] != null)
                          TextSpan(text: reserve.desc1!['text']),
                        if (reserve.desc2 != null &&
                            reserve.desc2?['text'] != null) ...[
                          const TextSpan(text: '  '),
                          TextSpan(text: reserve.desc2!['text']),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

    case 'ADDITIONAL_TYPE_GOODS':
      final Good? goods = additional.goods;
      if (goods == null || goods.items == null || goods.items!.isEmpty) {
        return const SizedBox.shrink();
      }
      final GoodItem goodItem = goods.items!.first;
      return Container(
        margin: margin,
        child: Material(
          color: bgColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _openUrl(
                goodItem.jumpUrl ?? goods.jumpUrl,
                title: goodItem.name ?? '商品详情',
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  NetworkImgLayer(
                    width: 75,
                    height: 75,
                    src: goodItem.cover ?? '',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goodItem.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (goodItem.brief != null &&
                            goodItem.brief!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            goodItem.brief!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: Theme.of(
                                context,
                              ).textTheme.labelMedium?.fontSize,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              goodItem.price != null &&
                                      goodItem.price!.isNotEmpty
                                  ? (goodItem.price!.startsWith('¥') ||
                                            goodItem.price!.startsWith('￥')
                                        ? goodItem.price!
                                        : '¥${goodItem.price}')
                                  : '查看商品',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                goodItem.jumpDesc != null &&
                                        goodItem.jumpDesc!.isNotEmpty
                                    ? goodItem.jumpDesc!
                                    : '去看看',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

    case 'ADDITIONAL_TYPE_COMMON':
      final DynamicAddCommonModel? common = additional.common;
      if (common == null) return const SizedBox.shrink();
      return Container(
        margin: margin,
        child: Material(
          color: bgColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _openUrl(common.jumpUrl, title: common.title ?? '活动详情');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  NetworkImgLayer(
                    width: 50,
                    height: 50,
                    src: common.cover ?? '',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          common.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (common.desc1 != null &&
                            common.desc1!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            common.desc1!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: Theme.of(
                                context,
                              ).textTheme.labelMedium?.fontSize,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      common.buttonText != null && common.buttonText!.isNotEmpty
                          ? common.buttonText!
                          : '进入',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

    case 'ADDITIONAL_TYPE_MATCH':
      final DynamicAddMatchModel? match = additional.match;
      if (match == null) return const SizedBox.shrink();
      return Container(
        margin: margin,
        child: Material(
          color: bgColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _openUrl(match.jumpUrl, title: match.title ?? '赛事详情');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sports_esports_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          match.title ?? '比赛信息',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (match.statusName != null &&
                          match.statusName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: match.status == 2
                                ? Colors.green.withOpacity(0.15)
                                : Theme.of(
                                    context,
                                  ).dividerColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            match.statusName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: match.status == 2
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                match.leftTeam?.name ?? '',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            NetworkImgLayer(
                              width: 28,
                              height: 28,
                              src: match.leftTeam?.cover ?? '',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          match.leftTeam?.score != null &&
                                  match.rightTeam?.score != null
                              ? '${match.leftTeam!.score} : ${match.rightTeam!.score}'
                              : 'VS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            NetworkImgLayer(
                              width: 28,
                              height: 28,
                              src: match.rightTeam?.cover ?? '',
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                match.rightTeam?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

    case 'ADDITIONAL_TYPE_VOTE':
      final Vote? vote = additional.vote;
      if (vote == null) return const SizedBox.shrink();
      final dynamicId = item?.basic?['comment_id_str'] ?? item?.idStr ?? '';
      final bool isEnded = vote.status == 2;
      return Container(
        margin: margin,
        child: Material(
          color: bgColor,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (vote.voteId == null) {
                SmartDialog.showToast('未获取到投票信息');
                return;
              }
              Get.toNamed(
                '/webview',
                parameters: {
                  'url':
                      'https://t.bilibili.com/vote/h5/index/#/result?vote_id=${vote.voteId}&dynamic_id=$dynamicId&isWeb=1',
                  'type': 'vote',
                  'pageTitle': vote.title ?? '投票',
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vote.title ?? '参与投票',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vote.joinNum ?? 0} 人参与${isEnded ? ' · 已结束' : ' · 进行中'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: Theme.of(
                              context,
                            ).textTheme.labelMedium?.fontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isEnded
                          ? Theme.of(context).dividerColor.withOpacity(0.12)
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      isEnded ? '查看结果' : '去投票',
                      style: TextStyle(
                        color: isEnded
                            ? Theme.of(context).colorScheme.outline
                            : Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

    default:
      return const SizedBox.shrink();
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/models/member/info.dart';
import 'package:pilipalaz/utils/utils.dart';

class ProfilePanel extends StatelessWidget {
  final dynamic ctr;
  final bool loadingStatus;
  const ProfilePanel({
    super.key,
    required this.ctr,
    this.loadingStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final MemberInfoModel memberInfo = ctr.memberInfo.value;
    final card = memberInfo.card;
    final liveRoom = memberInfo.liveRoom;
    final bool isLive =
        !loadingStatus &&
        liveRoom != null &&
        liveRoom.liveStatus == 1 &&
        (liveRoom.roomId ?? 0) > 0;

    void goToLiveRoom() {
      if (!isLive) return;
      final liveItem = LiveItemModel.fromJson({
        'title': liveRoom.title,
        'uname': card?.name ?? '',
        'face': card?.face ?? ctr.face.value,
        'roomid': liveRoom.roomId,
        'cover': liveRoom.cover,
        'live_status': liveRoom.liveStatus,
      });
      Get.toNamed(
        '/liveRoom?roomid=${liveRoom.roomId}',
        arguments: {'liveItem': liveItem, 'heroTag': ctr.heroTag},
      );
    }

    return Builder(
      builder: ((context) {
        return Row(
          children: [
            Hero(
              tag: ctr.heroTag ?? '',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isLive ? goToLiveRoom : null,
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: isLive
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2.5,
                                ),
                              )
                            : null,
                        padding: isLive
                            ? const EdgeInsets.all(2.5)
                            : EdgeInsets.zero,
                        child: ClipOval(
                          child: NetworkImgLayer(
                            width: isLive ? 80 : 90,
                            height: isLive ? 80 : 90,
                            type: 'avatar',
                            src: !loadingStatus
                                ? (card?.face ?? ctr.face.value)
                                : ctr.face.value,
                          ),
                        ),
                      ),
                      if (isLive)
                        Positioned(
                          bottom: -2,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/live.gif',
                                    height: 10,
                                  ),
                                  Text(
                                    ' 直播中',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize:
                                          Theme.of(
                                            context,
                                          ).textTheme.labelSmall?.fontSize ??
                                          10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 10,
                      left: 10,
                      right: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InkWell(
                          onTap: () {
                            if (card?.mid != null) {
                              Get.toNamed(
                                '/follow?mid=${card!.mid}&name=${card.name ?? ''}',
                              );
                            }
                          },
                          child: Column(
                            children: [
                              Text(
                                !loadingStatus
                                    ? (card?.attention?.toString() ?? '-')
                                    : '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '关注',
                                style: TextStyle(
                                  fontSize: Theme.of(
                                    context,
                                  ).textTheme.labelMedium!.fontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (card?.mid != null) {
                              Get.toNamed(
                                '/fan?mid=${card!.mid}&name=${card.name ?? ''}',
                              );
                            }
                          },
                          child: Column(
                            children: [
                              Text(
                                !loadingStatus
                                    ? card?.fans != null
                                          ? Utils.numFormat(card!.fans)
                                          : '-'
                                    : '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '粉丝',
                                style: TextStyle(
                                  fontSize: Theme.of(
                                    context,
                                  ).textTheme.labelMedium!.fontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: null,
                          child: Column(
                            children: [
                              Text(
                                !loadingStatus
                                    ? card?.likes != null
                                          ? Utils.numFormat(card!.likes)
                                          : '-'
                                    : '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '获赞',
                                style: TextStyle(
                                  fontSize: Theme.of(
                                    context,
                                  ).textTheme.labelMedium!.fontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ctr.ownerMid != ctr.mid && ctr.ownerMid != -1) ...[
                    Row(
                      children: [
                        Obx(
                          () => Expanded(
                            child: TextButton(
                              onPressed: () => ctr.actionRelationMod(context),
                              style: TextButton.styleFrom(
                                foregroundColor: ctr.attribute.value == -1
                                    ? Colors.transparent
                                    : ctr.attribute.value != 0
                                    ? Theme.of(context).colorScheme.outline
                                    : Theme.of(context).colorScheme.onPrimary,
                                backgroundColor: ctr.attribute.value != 0
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onInverseSurface
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primary, // 设置按钮背景色
                              ),
                              child: Obx(() => Text(ctr.attributeText.value)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Get.toNamed(
                                '/whisperDetail',
                                parameters: {
                                  'talkerId': ctr.mid.toString(),
                                  'name': card?.name ?? '',
                                  'face': card?.face ?? ctr.face.value,
                                  'mid': ctr.mid.toString(),
                                },
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
                            ),
                            child: const Text('发消息'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (ctr.ownerMid == ctr.mid && ctr.ownerMid != -1) ...[
                    TextButton(
                      onPressed: () {
                        Get.toNamed(
                          '/webview',
                          parameters: {
                            'url': 'https://account.bilibili.com/account/home',
                            'pageTitle': '个人中心（建议浏览器打开）',
                            'type': 'url',
                          },
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text(' 个人中心(web) '),
                    ),
                  ],
                  if (ctr.ownerMid == -1) ...[
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.outline,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onInverseSurface,
                      ),
                      child: const Text(' 未登录 '),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

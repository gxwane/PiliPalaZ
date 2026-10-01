import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/utils/utils.dart';

import '../controller.dart';

/// 关注主播正在开播横向滑屏吸顶卡片栏
class LiveFollowBar extends StatelessWidget {
  final LiveController liveController;

  const LiveFollowBar({super.key, required this.liveController});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = liveController.followingList;
      if (list.isEmpty) {
        return const SizedBox.shrink();
      }

      return RepaintBoundary(
        child: Container(
          height: 104,
          margin: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '我的关注正在直播 (${list.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _buildFollowItem(context, item, index, list);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildFollowItem(
    BuildContext context,
    LiveItemModel item,
    int index,
    List<LiveItemModel> list,
  ) {
    final heroTag = Utils.makeHeroTag(item.roomId);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Get.toNamed(
          '/liveRoom?roomid=${item.roomId}',
          arguments: {
            'liveItem': item,
            'heroTag': heroTag,
            'liveList': list,
            'initialIndex': index,
          },
        );
      },
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.8,
                    ),
                  ),
                  child: ClipOval(
                    child: NetworkImgLayer(
                      width: 44,
                      height: 44,
                      type: 'avatar',
                      src: item.face ?? '',
                    ),
                  ),
                ),
                Positioned(
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.uname ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

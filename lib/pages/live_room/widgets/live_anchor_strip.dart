import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/pages/live_room/controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_nav_helper.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_notice_sheet.dart';
import 'package:pilipalaz/utils/utils.dart';

class LiveAnchorStrip extends StatelessWidget {
  final LiveRoomController liveRoomCtr;

  const LiveAnchorStrip({super.key, required this.liveRoomCtr});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final h5 = liveRoomCtr.roomInfoH5.value;
      final anchor = h5.anchorInfo?.baseInfo;
      final room = h5.roomInfo;
      final relation = h5.anchorInfo?.relationInfo;

      final uname = anchor?.uname ?? '主播';
      final face = anchor?.face ?? '';
      final mid = room?.uid ?? 0;
      final attention = relation?.attention ?? 0;
      final title = room?.title ?? '';
      final desc = room?.description ?? '';
      final areaName = room?.areaName ?? '';
      final parentArea = room?.parentAreaName ?? '';
      final watchedText = h5.watchedShow?['text_large']?.toString() ?? '';

      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildAvatarAndName(
              context,
              uname,
              face,
              mid,
              attention,
              parentArea,
              areaName,
            ),
            const SizedBox(width: 8),
            _buildActionButtons(
              context,
              mid,
              title,
              desc,
              parentArea,
              areaName,
              watchedText,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAvatarAndName(
    BuildContext context,
    String uname,
    String face,
    int mid,
    int attention,
    String parentArea,
    String areaName,
  ) {
    final subText = parentArea.isNotEmpty && areaName.isNotEmpty
        ? '$parentArea · $areaName'
        : (attention > 0 ? '${Utils.numFormat(attention)} 粉丝' : '哔哩哔哩主播');

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => LiveNavHelper.navigateToAnchorMember(context, mid, face),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              ClipOval(
                child: NetworkImgLayer(
                  width: 36,
                  height: 36,
                  type: 'avatar',
                  src: face,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    int mid,
    String title,
    String desc,
    String parentArea,
    String areaName,
    String watchedText,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (desc.trim().isNotEmpty || title.isNotEmpty) ...[
          _buildNoticeButton(context, title, desc, parentArea, areaName),
          const SizedBox(width: 8),
        ],
        _buildFollowButton(mid),
      ],
    );
  }

  Widget _buildNoticeButton(
    BuildContext context,
    String title,
    String desc,
    String parentArea,
    String areaName,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showLiveNoticeSheet(
        context,
        title: title,
        desc: desc,
        areaName: areaName,
        parentArea: parentArea,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, color: Colors.orangeAccent, size: 14),
            SizedBox(width: 3),
            Text('公告', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(int mid) {
    return Obx(() {
      final isFollowed = liveRoomCtr.isFollowed.value;
      final isUpdating = liveRoomCtr.isFollowUpdating.value;

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isUpdating ? null : () => liveRoomCtr.toggleFollow(mid),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isFollowed
                ? Colors.white.withOpacity(0.12)
                : const Color(0xFFFF6699),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            isFollowed ? '已关注' : '+ 关注',
            style: TextStyle(
              color: isFollowed ? Colors.white70 : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    });
  }
}

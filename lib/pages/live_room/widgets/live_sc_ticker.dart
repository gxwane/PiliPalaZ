import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_chat_controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_sc_sheet.dart';
import 'package:pilipalaz/services/live/live_message.dart';

class LiveScTicker extends StatelessWidget {
  final LiveChatController chatController;

  const LiveScTicker({super.key, required this.chatController});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = chatController.activeSuperChats;
      if (list.isEmpty) {
        return const SizedBox.shrink();
      }
      final latestSc = list.first;

      return Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showLiveScSheet(context, chatController),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildAvatar(latestSc),
                const SizedBox(width: 6),
                _buildPriceBadge(latestSc),
                const SizedBox(width: 8),
                Expanded(child: _buildMessage(latestSc)),
                const SizedBox(width: 6),
                _buildCountChip(list.length),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAvatar(LiveSuperChatMessage sc) {
    return ClipOval(
      child: NetworkImgLayer(
        width: 24,
        height: 24,
        type: 'avatar',
        src: sc.face,
      ),
    );
  }

  Widget _buildPriceBadge(LiveSuperChatMessage sc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '¥${sc.price}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessage(LiveSuperChatMessage sc) {
    return Text(
      '${sc.uname}: ${sc.message}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }

  Widget _buildCountChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, color: Colors.white, size: 14),
        ],
      ),
    );
  }
}

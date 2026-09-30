import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/services/live/live_message.dart';

import 'live_chat_controller.dart';

import 'live_nav_helper.dart';

class LiveChatPanel extends StatelessWidget {
  final LiveChatController chatController;
  final bool isScOnly;
  final int anchorUid;

  const LiveChatPanel({
    super.key,
    required this.chatController,
    this.isScOnly = false,
    this.anchorUid = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final List<LiveMessage> messages = isScOnly
              ? chatController.chatMessages
                    .whereType<LiveSuperChatMessage>()
                    .toList()
              : chatController.chatMessages;

          if (messages.isEmpty) {
            return Center(
              child: Text(
                isScOnly ? '暂无醒目留言 (SC)' : '欢迎来到直播间~',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            );
          }

          return ListView.builder(
            controller: isScOnly ? null : chatController.scrollController,
            reverse: true,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return _buildMessageItem(context, message);
            },
          );
        }),
        _buildUnreadFloatingPill(),
      ],
    );
  }

  Widget _buildUnreadFloatingPill() {
    if (isScOnly) return const SizedBox();
    return Obx(() {
      if (!chatController.isScrolledUp.value ||
          chatController.unreadCount.value <= 0) {
        return const SizedBox();
      }
      return Positioned(
        bottom: 12,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: chatController.scrollToBottom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_downward,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${chatController.unreadCount.value} 条新消息',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMessageItem(BuildContext context, LiveMessage message) {
    if (message is LiveSuperChatMessage) {
      return _buildSuperChatItem(context, message);
    }
    if (message is LiveDanmakuItem) {
      return _buildDanmakuItem(context, message);
    }
    if (message is LiveInteractMessage) {
      return _buildInteractItem(message);
    }
    return const SizedBox();
  }

  Widget _buildDanmakuItem(BuildContext context, LiveDanmakuItem item) {
    final bool isAnchor = anchorUid > 0 && item.uid == anchorUid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAnchor
              ? const Color(0xFFFF6699).withOpacity(0.12)
              : Colors.white.withOpacity(0.06),
          border: isAnchor
              ? Border.all(
                  color: const Color(0xFFFF6699).withOpacity(0.4),
                  width: 0.8,
                )
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              if (isAnchor)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6699),
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                    child: const Text(
                      'UP主播',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              TextSpan(
                text: '${item.uname}: ',
                style: TextStyle(
                  color: isAnchor
                      ? const Color(0xFFFF85AD)
                      : const Color(0xFF64B5F6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: item.text,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuperChatItem(BuildContext context, LiveSuperChatMessage sc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: sc.uid > 0
            ? () =>
                  LiveNavHelper.navigateToAnchorMember(context, sc.uid, sc.face)
            : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE57373).withOpacity(0.2),
            border: Border.all(color: const Color(0xFFE57373).withOpacity(0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    sc.uname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '¥ ${sc.price.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                sc.message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractItem(LiveInteractMessage item) {
    final action = item.action == 1 ? '进入直播间' : '关注了主播';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '${item.uname} $action',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }
}

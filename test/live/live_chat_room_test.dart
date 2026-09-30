import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_chat_controller.dart';
import 'package:pilipalaz/services/live/live_danmaku_client.dart';
import 'package:pilipalaz/services/live/live_message.dart';

void main() {
  group('LiveChatController Tests', () {
    late LiveChatController chatController;

    setUp(() {
      chatController = LiveChatController(maxMessages: 10);
    });

    tearDown(() {
      chatController.onClose();
    });

    test('enqueues messages and batch flushes in reverse order', () {
      final msg1 = LiveDanmakuItem(
        text: '第一条消息',
        uname: 'UserA',
        uid: 1001,
        color: const Color(0xFFFFFFFF),
        timestamp: 1000,
      );
      final msg2 = LiveDanmakuItem(
        text: '第二条消息',
        uname: 'UserB',
        uid: 1002,
        color: const Color(0xFFFFFFFF),
        timestamp: 2000,
      );

      chatController.enqueueMessage(msg1);
      chatController.enqueueMessage(msg2);

      // Before flush, chatMessages is empty
      expect(chatController.chatMessages.isEmpty, isTrue);

      // Flush batch
      chatController.flushPendingMessages();

      // Reverse order: index 0 is newest (msg2), index 1 is older (msg1)
      expect(chatController.chatMessages.length, 2);
      expect((chatController.chatMessages[0] as LiveDanmakuItem).text, '第二条消息');
      expect((chatController.chatMessages[1] as LiveDanmakuItem).text, '第一条消息');
    });

    test('enforces FIFO capacity and trims oldest messages', () {
      for (int i = 0; i < 15; i++) {
        chatController.enqueueMessage(
          LiveDanmakuItem(
            text: '消息 #$i',
            uname: 'User$i',
            uid: 1000 + i,
            color: const Color(0xFFFFFFFF),
            timestamp: 1000 + i,
          ),
        );
      }

      chatController.flushPendingMessages();

      // Maximum capacity is 10
      expect(chatController.chatMessages.length, 10);
      // Index 0 should be newest: '消息 #14'
      expect(
        (chatController.chatMessages[0] as LiveDanmakuItem).text,
        '消息 #14',
      );
      // Index 9 should be '消息 #5' (oldest retained)
      expect((chatController.chatMessages[9] as LiveDanmakuItem).text, '消息 #5');
    });

    test('scroll-up state machine tracks unread messages correctly', () {
      chatController.isScrolledUp.value = true;
      expect(chatController.unreadCount.value, 0);

      chatController.enqueueMessage(
        const LiveInteractMessage(
          uname: '粉丝小王',
          uid: 2001,
          action: 1,
          timestamp: 2500,
        ),
      );
      chatController.enqueueMessage(
        const LiveSuperChatMessage(
          uname: '土豪小李',
          uid: 2002,
          price: 50.0,
          message: '老板牛逼！',
          timestamp: 3000,
        ),
      );

      chatController.flushPendingMessages();

      // Unread count should increment by batch size
      expect(chatController.unreadCount.value, 2);
      expect(chatController.chatMessages.length, 2);

      // Scroll to bottom resets unread and scroll-up state
      chatController.scrollToBottom();
      expect(chatController.isScrolledUp.value, isFalse);
      expect(chatController.unreadCount.value, 0);
    });

    test('supports different LiveMessage sub-types', () {
      chatController.enqueueMessage(
        LiveDanmakuItem(
          text: '弹幕内容',
          uname: '弹幕用户',
          uid: 3001,
          color: const Color(0xFFFFFFFF),
          timestamp: 1000,
        ),
      );
      chatController.enqueueMessage(
        const LiveSuperChatMessage(
          uname: 'SC用户',
          uid: 3002,
          price: 100.0,
          message: 'SC大留言',
          timestamp: 2000,
        ),
      );
      chatController.enqueueMessage(
        const LiveInteractMessage(
          uname: '进房用户',
          uid: 3003,
          action: 1,
          timestamp: 3000,
        ),
      );

      chatController.flushPendingMessages();
      expect(chatController.chatMessages.length, 3);
      expect(chatController.chatMessages[0].type, LiveMessageType.interact);
      expect(chatController.chatMessages[1].type, LiveMessageType.superChat);
      expect(chatController.chatMessages[2].type, LiveMessageType.danmaku);
    });

    test('disposal safety ignores new enqueued messages', () {
      chatController.onClose();
      chatController.enqueueMessage(
        LiveDanmakuItem(
          text: '销毁后的消息',
          uname: 'DisposedUser',
          uid: 9999,
          color: const Color(0xFFFFFFFF),
          timestamp: 9999,
        ),
      );
      chatController.flushPendingMessages();
      expect(chatController.chatMessages.isEmpty, isTrue);
    });

    test('activeSuperChats tracks SuperChats and clears on close', () {
      expect(chatController.activeSuperChats.isEmpty, isTrue);

      chatController.enqueueMessage(
        const LiveDanmakuItem(
          text: '普通弹幕',
          uname: 'UserA',
          uid: 101,
          color: Color(0xFFFFFFFF),
          timestamp: 100,
        ),
      );
      expect(chatController.activeSuperChats.isEmpty, isTrue);

      const sc = LiveSuperChatMessage(
        uname: 'SC土豪',
        uid: 102,
        price: 100.0,
        message: '老板发财！',
        timestamp: 200,
      );
      chatController.enqueueMessage(sc);
      expect(chatController.activeSuperChats.length, 1);
      expect(chatController.activeSuperChats.first.uname, 'SC土豪');

      chatController.onClose();
      expect(chatController.activeSuperChats.isEmpty, isTrue);
    });

    test(
      'bindDanmakuClient dynamically binds without error and handles disposal safely',
      () {
        final client = LiveDanmakuClient(roomId: 12345, uid: 0, buvid: '');
        chatController.bindDanmakuClient(client);

        // After closing controller, further bind calls are safely ignored
        chatController.onClose();
        chatController.bindDanmakuClient(client);
        client.dispose();
      },
    );
  });
}

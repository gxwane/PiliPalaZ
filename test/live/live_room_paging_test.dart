import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/pages/live_room/controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_chat_controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_room_paging_controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_room_preview_card.dart';
import 'package:pilipalaz/services/live/live_message.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('live_room_paging_test_');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LiveRoomPlaylistManager Tests', () {
    test('initDualEntry initializes with full list and valid index', () {
      final manager = LiveRoomPlaylistManager();
      final items = [
        LiveItemModel(roomId: 101, uname: 'Anchor A'),
        LiveItemModel(roomId: 102, uname: 'Anchor B'),
        LiveItemModel(roomId: 103, uname: 'Anchor C'),
      ];

      manager.initDualEntry(initialList: items, initialIndex: 1);

      expect(manager.playlist.length, 3);
      expect(manager.currentIndex.value, 1);
      expect(manager.playlist[1].roomId, 102);
      manager.dispose();
    });

    test('initDualEntry clamps out-of-bounds initialIndex', () {
      final manager = LiveRoomPlaylistManager();
      final items = [
        LiveItemModel(roomId: 101, uname: 'Anchor A'),
        LiveItemModel(roomId: 102, uname: 'Anchor B'),
      ];

      manager.initDualEntry(initialList: items, initialIndex: 99);

      expect(manager.currentIndex.value, 1);
      manager.dispose();
    });

    test(
      'initDualEntry falls back to seed item when list is null or empty',
      () {
        final manager = LiveRoomPlaylistManager();

        manager.initDualEntry(
          initialList: null,
          initialRoomId: 999,
          initialItem: LiveItemModel(roomId: 999, uname: 'Solo Anchor'),
        );

        expect(manager.playlist.length, 1);
        expect(manager.playlist.first.roomId, 999);
        expect(manager.currentIndex.value, 0);
        manager.dispose();
      },
    );

    test(
      'Boundary check does not trigger preload when far from edge',
      () async {
        final manager = LiveRoomPlaylistManager();
        final items = List.generate(
          10,
          (i) => LiveItemModel(roomId: 100 + i, uname: 'Anchor $i'),
        );
        manager.initDualEntry(initialList: items, initialIndex: 0);

        await manager.checkAndPreloadMore(2);
        expect(manager.playlist.length, 10);
        manager.dispose();
      },
    );

    test('dispose clears playlist and marks disposed', () {
      final manager = LiveRoomPlaylistManager();
      manager.initDualEntry(
        initialList: [LiveItemModel(roomId: 1, uname: 'A')],
      );

      manager.dispose();
      expect(manager.playlist.isEmpty, isTrue);
    });
  });

  group('LiveChatController.reset() Tests', () {
    test(
      'reset clears messages, pending messages, active SC, and unreadCount',
      () {
        final controller = LiveChatController();

        controller.enqueueMessage(
          LiveDanmakuItem(
            uid: 123,
            uname: 'User1',
            text: 'Hello',
            color: Colors.white,
            mode: 1,
            timestamp: 1000,
          ),
        );
        controller.enqueueMessage(
          const LiveSuperChatMessage(
            uid: 456,
            uname: 'Sponsor',
            price: 50.0,
            message: 'Super chat message',
            timestamp: 2000,
          ),
        );
        controller.flushPendingMessages();

        expect(controller.chatMessages.isNotEmpty, isTrue);
        expect(controller.activeSuperChats.isNotEmpty, isTrue);

        controller.reset();

        expect(controller.chatMessages.isEmpty, isTrue);
        expect(controller.activeSuperChats.isEmpty, isTrue);
        expect(controller.unreadCount.value, 0);
        expect(controller.isScrolledUp.value, isFalse);

        controller.onClose();
      },
    );
  });

  group('LiveRoomController switchRoom atomic state machine tests', () {
    test('switchRoom ignores non-positive room id safely', () async {
      final controller = LiveRoomController();
      controller.roomId = 12345;

      final res = await controller.switchRoom(0);
      expect(res.isSuccess, isFalse);
      expect(controller.roomId, 12345);

      controller.onClose();
    });

    test('switchRoom resets connections and chat state before loading', () async {
      final controller = LiveRoomController();
      controller.roomId = 1000;
      controller.chatController.enqueueMessage(
        LiveDanmakuItem(
          uid: 1,
          uname: 'U',
          text: 'msg',
          color: Colors.white,
          mode: 1,
          timestamp: 1000,
        ),
      );
      controller.chatController.flushPendingMessages();
      expect(controller.chatController.chatMessages.isNotEmpty, isTrue);

      final nextItem = LiveItemModel(roomId: 2000, uname: 'New Anchor');
      // switchRoom triggers queries which gracefully fail offline without throwing
      await controller.switchRoom(2000, item: nextItem);

      expect(controller.roomId, 2000);
      expect(controller.chatController.chatMessages.isEmpty, isTrue);
      expect(controller.hasStream.value, isFalse);

      controller.onClose();
    });
  });

  group('LiveRoomPreviewCard Widget Tests', () {
    testWidgets(
      'renders anchor name, area, LIVE badge and skeleton without crash',
      (WidgetTester tester) async {
        final item = LiveItemModel(
          roomId: 8888,
          uname: '测试大主播',
          areaName: '虚拟主播',
          cover: 'https://i0.hdslb.com/bfs/live/test.jpg',
          face: 'https://i0.hdslb.com/bfs/face/test.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(home: LiveRoomPreviewCard(item: item)),
        );

        expect(find.text('测试大主播'), findsWidgets);
        expect(find.text('虚拟主播'), findsOneWidget);
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      },
    );
  });
}

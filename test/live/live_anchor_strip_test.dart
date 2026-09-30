import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/live/room_info_h5.dart';
import 'package:pilipalaz/pages/live_room/controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_anchor_strip.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_chat_controller.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_chat_panel.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_notice_sheet.dart';
import 'package:pilipalaz/pages/live_room/widgets/live_sc_ticker.dart';
import 'package:pilipalaz/services/live/live_message.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-live-anchor-test-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(
      StorageBoxName.userInfo,
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('Live Room Option A UX Components Tests', () {
    late LiveRoomController liveRoomCtr;

    setUp(() {
      Get.testMode = true;
      liveRoomCtr = LiveRoomController();
      liveRoomCtr.roomInfoH5.value = RoomInfoH5Model(
        roomInfo: RoomInfo(
          uid: 666888,
          title: '测试直播间标题',
          description: '今晚通关艾尔登法环DLC！',
          areaName: '艾尔登法环',
          parentAreaName: '单机游戏',
        ),
        anchorInfo: AnchorInfo(
          baseInfo: BaseInfo(
            uname: '技术主播阿伟',
            face: 'https://example.com/face.jpg',
          ),
          relationInfo: RelationInfo(attention: 125000),
        ),
      );
    });

    tearDown(() {
      liveRoomCtr.onClose();
    });

    testWidgets(
      'LiveAnchorStrip renders avatar, name, area and action buttons',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LiveAnchorStrip(liveRoomCtr: liveRoomCtr)),
          ),
        );

        expect(find.text('技术主播阿伟'), findsOneWidget);
        expect(find.text('单机游戏 · 艾尔登法环'), findsOneWidget);
        expect(find.text('公告'), findsOneWidget);
        expect(find.text('+ 关注'), findsOneWidget);
      },
    );

    testWidgets('LiveNoticeSheet renders title, area and clean description', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveNoticeSheet(
              title: '重要开播预告',
              desc: '每周二四六晚上八点直播',
              areaName: '艾尔登法环',
              parentArea: '单机游戏',
            ),
          ),
        ),
      );

      expect(find.text('主播公告与简介'), findsOneWidget);
      expect(find.text('重要开播预告'), findsOneWidget);
      expect(find.text('每周二四六晚上八点直播'), findsOneWidget);
      expect(find.text('单机游戏 · 艾尔登法环'), findsOneWidget);
    });

    testWidgets(
      'LiveScTicker is shrink when empty and visible when SC exists',
      (tester) async {
        final chatCtr = LiveChatController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LiveScTicker(chatController: chatCtr)),
          ),
        );

        // Initially empty -> SizedBox.shrink()
        expect(find.byType(InkWell), findsNothing);

        // Add SC
        chatCtr.enqueueMessage(
          const LiveSuperChatMessage(
            uname: '神豪大哥',
            uid: 9999,
            price: 50.0,
            message: '通关给你刷火箭！',
            timestamp: 1000,
          ),
        );
        await tester.pump();

        // Now ticker is visible with price and uname
        expect(find.text('¥50.0'), findsOneWidget);
        expect(find.text('神豪大哥: 通关给你刷火箭！'), findsOneWidget);

        chatCtr.onClose();
      },
    );

    testWidgets('LiveChatPanel highlights anchor danmaku with UP badge', (
      tester,
    ) async {
      final chatCtr = LiveChatController();
      chatCtr.enqueueMessage(
        const LiveDanmakuItem(
          text: '主播发的一句话',
          uname: '技术主播阿伟',
          uid: 666888, // Matches anchorUid
          color: Color(0xFFFFFFFF),
          timestamp: 1000,
        ),
      );
      chatCtr.flushPendingMessages();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveChatPanel(chatController: chatCtr, anchorUid: 666888),
          ),
        ),
      );

      // Finds the UP主播 badge
      expect(find.text('UP主播'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('技术主播阿伟: 主播发的一句话'),
        ),
        findsOneWidget,
      );

      chatCtr.onClose();
    });
  });
}

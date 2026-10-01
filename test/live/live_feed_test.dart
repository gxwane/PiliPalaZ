import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/live/area.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/pages/live/controller.dart';
import 'package:pilipalaz/pages/live/widgets/live_area_header.dart';
import 'package:pilipalaz/pages/live/widgets/live_follow_bar.dart';
import 'package:pilipalaz/pages/live/widgets/live_item.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('live_feed_test_');
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

  group('Live Area & Item Model Unit Tests', () {
    test(
      'LiveItemModel.fromJson handles aliases and missing fields safely',
      () {
        final json = {
          'room_id': 999888,
          'mid': 123456,
          'title': '测试直播间标题',
          'nickname': '测试主播昵称',
          'keyframe': 'https://example.com/cover.jpg',
          'avatar': 'https://example.com/face.jpg',
          'parent_area_id': 2,
          'parent_area_name': '网游',
          'area_v2_name': '英雄联盟',
          'watched_show': {'text_small': '1.2万'},
        };

        final item = LiveItemModel.fromJson(json);
        expect(item.roomId, 999888);
        expect(item.uid, 123456);
        expect(item.title, '测试直播间标题');
        expect(item.uname, '测试主播昵称');
        expect(item.cover, 'https://example.com/cover.jpg');
        expect(item.face, 'https://example.com/face.jpg');
        expect(item.parentId, 2);
        expect(item.parentName, '网游');
        expect(item.areaName, '英雄联盟');
        expect(item.watchedShow?['text_small'], '1.2万');
      },
    );

    test('LiveItemModel handles live_status aliases and type variations', () {
      // 1: 直播中 (int)
      final liveInt = LiveItemModel.fromJson({'roomid': 100, 'live_status': 1});
      expect(liveInt.liveStatus, 1);
      expect(liveInt.isLive, isTrue);
      expect(liveInt.isRoundRobin, isFalse);
      expect(liveInt.isOffline, isFalse);

      // 0: 未开播 (int)
      final offline = LiveItemModel.fromJson({'roomid': 101, 'live_status': 0});
      expect(offline.liveStatus, 0);
      expect(offline.isLive, isFalse);
      expect(offline.isRoundRobin, isFalse);
      expect(offline.isOffline, isTrue);

      // 2: 轮播中 (int)
      final roundRobin = LiveItemModel.fromJson({
        'roomid': 102,
        'live_status': 2,
      });
      expect(roundRobin.liveStatus, 2);
      expect(roundRobin.isLive, isFalse);
      expect(roundRobin.isRoundRobin, isTrue);
      expect(roundRobin.isOffline, isFalse);

      // string '1'
      final liveStr = LiveItemModel.fromJson({
        'roomid': 103,
        'live_status': '1',
      });
      expect(liveStr.liveStatus, 1);
      expect(liveStr.isLive, isTrue);

      // bool is_live: true
      final boolLive = LiveItemModel.fromJson({'roomid': 104, 'is_live': true});
      expect(boolLive.liveStatus, 1);
      expect(boolLive.isLive, isTrue);

      // camelCase liveStatus
      final camelLive = LiveItemModel.fromJson({
        'roomid': 105,
        'liveStatus': 1,
      });
      expect(camelLive.liveStatus, 1);
      expect(camelLive.isLive, isTrue);
    });

    test(
      'Live follow stream filtering strictly retains only live_status == 1',
      () {
        final rawList = [
          LiveItemModel.fromJson({'roomid': 101, 'live_status': 1}), // 在播
          LiveItemModel.fromJson({
            'roomid': 102,
            'live_status': 0,
          }), // 关播 (但有永久 roomId)
          LiveItemModel.fromJson({'roomid': 103, 'live_status': 2}), // 轮播
          LiveItemModel.fromJson({'roomid': 0, 'live_status': 1}), // 无效 roomid
          LiveItemModel.fromJson({'roomid': 104, 'live_status': 1}), // 在播
        ];

        final filtered = rawList
            .where((item) => (item.roomId ?? 0) > 0 && item.isLive)
            .toList();

        expect(filtered.length, 2);
        expect(filtered[0].roomId, 101);
        expect(filtered[1].roomId, 104);
        expect(filtered.every((item) => item.isLive), isTrue);
      },
    );

    test('LiveItemModel.fromJson gracefully handles totally empty JSON', () {
      final item = LiveItemModel.fromJson({});
      expect(item.roomId, isNull);
      expect(item.uid, isNull);
      expect(item.title, isNull);
      expect(item.cover, isNull);
      expect(item.face, isNull);
      expect(item.liveStatus, isNull);
      expect(item.isLive, isFalse);
      expect(item.isOffline, isTrue);
    });

    test('LiveAreaItemModel.defaultAreas provides built-in fallback areas', () {
      final areas = LiveAreaItemModel.defaultAreas;
      expect(areas.isNotEmpty, isTrue);
      expect(areas.first.id, 0);
      expect(areas.first.name, '推荐');
      expect(areas.any((a) => a.id == 2 && a.name == '网游'), isTrue);
      expect(areas.any((a) => a.id == 9 && a.name == '虚拟主播'), isTrue);
    });
  });

  group('LiveController State Machine Tests', () {
    late LiveController controller;

    setUp(() {
      Get.testMode = true;
      controller = LiveController();
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    test('Initial state contains default areas and unselected area 0', () {
      controller.onInit();
      expect(controller.areaList.isNotEmpty, isTrue);
      expect(controller.selectedAreaId.value, 0);
      expect(controller.isAreaSwitching.value, isFalse);
    });

    test(
      'fetchFollowingList clears followingList when user is not logged in',
      () async {
        await controller.fetchFollowingList();
        expect(controller.followingList.isEmpty, isTrue);
        expect(controller.isFollowingLoading.value, isFalse);
      },
    );

    test('switchArea updates selectedAreaId and resets currentPage', () async {
      controller.onInit();
      expect(controller.selectedAreaId.value, 0);

      await controller.switchArea(2);
      expect(controller.selectedAreaId.value, 2);
      expect(controller.currentPage, 1);
    });
  });

  group('Live Plaza Widget Safety Tests (Zero-Crash Standard)', () {
    testWidgets(
      'LiveCardV renders safely without crash even if all fields are null',
      (tester) async {
        final emptyItem = LiveItemModel.fromJson({});

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 250,
                child: LiveCardV(liveItem: emptyItem),
              ),
            ),
          ),
        );

        expect(find.byType(LiveCardV), findsOneWidget);
        expect(find.byType(VideoStat), findsOneWidget);
        expect(find.byType(LiveContent), findsOneWidget);
      },
    );

    testWidgets('LiveAreaHeader renders area chips and handles taps', (
      tester,
    ) async {
      final controller = LiveController();
      controller.areaList.assignAll(LiveAreaItemModel.defaultAreas);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveAreaHeader(liveController: controller)),
        ),
      );

      expect(find.text('推荐'), findsOneWidget);
      expect(find.text('网游'), findsOneWidget);

      await tester.tap(find.text('网游'));
      expect(controller.selectedAreaId.value, 2);
      controller.onClose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
      'LiveFollowBar collapses to SizedBox.shrink when followingList is empty',
      (tester) async {
        final controller = LiveController();
        controller.followingList.clear();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LiveFollowBar(liveController: controller)),
          ),
        );

        expect(find.text('我的关注正在直播'), findsNothing);
        controller.onClose();
      },
    );

    testWidgets(
      'LiveFollowBar renders horizontal streamer items when followingList is present',
      (tester) async {
        final controller = LiveController();
        controller.followingList.assignAll([
          LiveItemModel.fromJson({
            'roomid': 1001,
            'uname': '小主播A',
            'face': 'https://example.com/a.jpg',
            'live_status': 1,
          }),
          LiveItemModel.fromJson({
            'roomid': 1002,
            'uname': '大主播B',
            'face': 'https://example.com/b.jpg',
            'live_status': 1,
          }),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LiveFollowBar(liveController: controller)),
          ),
        );

        expect(find.text('我的关注正在直播 (2)'), findsOneWidget);
        expect(find.text('小主播A'), findsOneWidget);
        expect(find.text('大主播B'), findsOneWidget);
        expect(find.text('LIVE'), findsNWidgets(2));

        controller.onClose();
      },
    );

    testWidgets(
      'LiveFollowBar does not render LIVE badge when item is not live',
      (tester) async {
        final controller = LiveController();
        controller.followingList.assignAll([
          LiveItemModel.fromJson({
            'roomid': 1003,
            'uname': '离线主播C',
            'face': 'https://example.com/c.jpg',
            'live_status': 0,
          }),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: LiveFollowBar(liveController: controller)),
          ),
        );

        expect(find.text('离线主播C'), findsOneWidget);
        expect(find.text('LIVE'), findsNothing);

        controller.onClose();
      },
    );
  });
}

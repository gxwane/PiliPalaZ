import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/controllers/playback_queue_controller.dart';
import 'package:pilipalaz/models/download/download_task.dart';
import 'package:pilipalaz/pages/video/introduction/detail/controller.dart';
import 'package:pilipalaz/utils/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('intro_offline_test_');
    Hive.init(tmpDir.path);
    try {
      GStorage.userInfo = await Hive.openBox<dynamic>('userInfo');
    } catch (_) {}
    try {
      GStorage.setting = await Hive.openBox<dynamic>('setting');
    } catch (_) {}
  });

  tearDownAll(() async {
    Get.reset();
    await Hive.close();
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test(
    'VideoIntroController 在 isOffline 时直接消费 offlineTask 元数据，跳过网络请求',
    () async {
      final task = DownloadTask.create(
        bvid: 'BVtestOffline123',
        cid: 998877,
        title: '离线测试视频',
        cover: 'http://example.com/cover.jpg',
        ownerName: '测试UP主',
        duration: 360,
        videoQuality: 80,
        videoQualityDesc: '1080P',
        videoCodec: 'avc1',
        audioQuality: 30280,
      );

      Get.parameters = {'bvid': 'BVtestOffline123', 'cid': '998877'};
      Get.routing.args = {
        'heroTag': 'testHeroTag',
        'isOffline': true,
        'offlineTask': task,
      };

      final queueCtr = Get.put(
        PlaybackQueueController(heroTag: 'testHeroTag'),
        tag: 'testHeroTag',
      );
      final introCtr = Get.put(VideoIntroController(), tag: 'testHeroTag');

      expect(introCtr.videoDetail.value.title, equals('离线测试视频'));
      expect(introCtr.videoDetail.value.owner?.name, equals('测试UP主'));
      expect(introCtr.lastPlayCid.value, equals(998877));
      expect(introCtr.videoIntroFailure.value, isNull);
      expect(introCtr.videoDetail.value.descV2, isNotNull);
      expect(introCtr.videoDetail.value.descV2, isEmpty);
      expect(introCtr.videoDetail.value.stat, isNotNull);
      expect(introCtr.videoDetail.value.stat?.like, equals(0));
      expect(introCtr.videoDetail.value.stat?.coin, equals(0));
      expect(introCtr.videoDetail.value.stat?.favorite, equals(0));
      expect(introCtr.videoDetail.value.stat?.reply, equals(0));
      expect(queueCtr.queue.length, equals(1));
      expect(queueCtr.queue.first.bvid, equals('BVtestOffline123'));
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/plugin/pl_player/models/bottom_control_type.dart';
import 'package:pilipalaz/plugin/pl_player/models/data_source.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'package:pilipalaz/plugin/pl_player/playback_resource_ownership.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/bottom_control.dart';
import 'package:pilipalaz/services/audio_handler.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

final class _NoOpPlaybackAudioSession implements PlaybackAudioSession {
  @override
  Future<bool> setActive(bool active) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory hiveDirectory;
  late PlPlayerController playerController;

  setUpAll(() async {
    audioSessionHandler = _NoOpPlaybackAudioSession();
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-offline-subtitle-test-hive-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
    videoPlayerServiceHandler = VideoPlayerServiceHandler(
      settingBox: GStorage.setting,
    );

    PlPlayerController.isHeadlessTestMode = true;
    playerController = PlPlayerController.getInstance();
  });

  tearDownAll(() async {
    await PlPlayerController.disposeIfExists();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'pilipalaz-offline-subtitle-test-files-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Offline Subtitle Playback & Session Guard Tests', () {
    test(
      'setDataSource with offlineSubtitleFile loads subtitles and honors user preference',
      () async {
        final subtitleFile = File('${tempDir.path}/subtitles.json');
        final dummyVideoFile = File('${tempDir.path}/video.m4s');
        await dummyVideoFile.writeAsBytes([0, 1, 2, 3]);

        final mockTracks = [
          {
            'language': 'ai-zh',
            'title': '中文（AI生成）',
            'text': 'WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\nAI测试\n\n',
          },
          {
            'language': 'zh-Hans',
            'title': '中文（人工）',
            'text': 'WEBVTT\n\n1\n00:00:01.000 --> 00:00:02.000\n人工测试\n\n',
          },
        ];
        await subtitleFile.writeAsString(jsonEncode(mockTracks));

        // Set user preference to "withoutAi"
        await GStorage.setting.put(
          SettingBoxKey.subtitlePreference,
          'withoutAi',
        );

        await playerController.setDataSource(
          DataSource(
            type: DataSourceType.file,
            file: dummyVideoFile,
            offlineSubtitleFile: subtitleFile,
          ),
          owner: PlayerResourceOwner(),
          duration: const Duration(seconds: 10),
        );

        // Allow async file read and chooseSubtitle to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(playerController.vttSubtitles, isNotEmpty);
        expect(playerController.vttSubtitles.length, 3); // 1 (关闭字幕) + 2 (内容)
        expect(playerController.vttSubtitles[0]['title'], '关闭字幕');
        expect(playerController.vttSubtitles[1]['language'], 'ai-zh');
        expect(playerController.vttSubtitles[2]['language'], 'zh-Hans');

        // Verify that "withoutAi" preference selected index 2 (人工字幕)
        expect(playerController.vttSubtitlesIndex.value, 2);

        // Control bar should include subtitle button when subtitles exist
        final controls = buildDefaultBottomControlTypes(
          hasEpisodes: false,
          isEquivalentFullScreen: false,
          hasSubtitles: playerController.vttSubtitles.isNotEmpty,
        );
        expect(controls, contains(BottomControlType.subtitle));
      },
    );

    test(
      'setDataSource with null or missing offlineSubtitleFile clears subtitles gracefully',
      () async {
        final dummyVideoFile = File('${tempDir.path}/video.m4s');
        await dummyVideoFile.writeAsBytes([0, 1, 2, 3]);

        final nonExistentFile = File('${tempDir.path}/does_not_exist.json');

        await playerController.setDataSource(
          DataSource(
            type: DataSourceType.file,
            file: dummyVideoFile,
            offlineSubtitleFile: nonExistentFile,
          ),
          owner: PlayerResourceOwner(),
          duration: const Duration(seconds: 10),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(playerController.vttSubtitles, isEmpty);
        expect(playerController.vttSubtitlesIndex.value, 0);

        final controls = buildDefaultBottomControlTypes(
          hasEpisodes: false,
          isEquivalentFullScreen: false,
          hasSubtitles: playerController.vttSubtitles.isNotEmpty,
        );
        expect(controls, isNot(contains(BottomControlType.subtitle)));
      },
    );
  });
}

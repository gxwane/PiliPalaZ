import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-storage-migration-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
  });

  setUp(() async {
    await GStorage.setting.clear();
    await GStorage.video.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  group('GStorage.migrateVideoSyncV2', () {
    test(
      'clean install: does not set videoSync, marks migrated, default resolves to audio',
      () async {
        expect(GStorage.setting.get(SettingBoxKey.videoSync), isNull);
        expect(GStorage.setting.get(SettingBoxKey.videoSyncV2Migrated), isNull);

        await GStorage.migrateVideoSyncV2();

        expect(GStorage.setting.get(SettingBoxKey.videoSync), isNull);
        expect(
          GStorage.setting.get(SettingBoxKey.videoSync, defaultValue: 'audio'),
          'audio',
        );
        expect(GStorage.setting.get(SettingBoxKey.videoSyncV2Migrated), isTrue);
      },
    );

    test(
      'upgrade from legacy: migrates display-resample to audio and sets migrated flag',
      () async {
        await GStorage.setting.put(SettingBoxKey.videoSync, 'display-resample');

        await GStorage.migrateVideoSyncV2();

        expect(GStorage.setting.get(SettingBoxKey.videoSync), 'audio');
        expect(GStorage.setting.get(SettingBoxKey.videoSyncV2Migrated), isTrue);
      },
    );

    test(
      'custom configuration preserved: retains user choice and sets migrated flag',
      () async {
        await GStorage.setting.put(SettingBoxKey.videoSync, 'display-vdrop');

        await GStorage.migrateVideoSyncV2();

        expect(GStorage.setting.get(SettingBoxKey.videoSync), 'display-vdrop');
        expect(GStorage.setting.get(SettingBoxKey.videoSyncV2Migrated), isTrue);
      },
    );

    test(
      'idempotency: does not overwrite if videoSyncV2Migrated is already true',
      () async {
        await GStorage.setting.put(SettingBoxKey.videoSync, 'display-resample');
        await GStorage.setting.put(SettingBoxKey.videoSyncV2Migrated, true);

        await GStorage.migrateVideoSyncV2();

        expect(
          GStorage.setting.get(SettingBoxKey.videoSync),
          'display-resample',
        );
        expect(GStorage.setting.get(SettingBoxKey.videoSyncV2Migrated), isTrue);
      },
    );
  });

  group('GStorage.importAllSettings migration', () {
    test(
      'import legacy backup: migrates legacy display-resample to audio and sets migrated flag',
      () async {
        final legacyBackup = jsonEncode({
          StorageBoxName.setting: {
            SettingBoxKey.videoSync: 'display-resample',
            SettingBoxKey.feedBackEnable: true,
          },
          StorageBoxName.video: {},
        });

        await GStorage.importAllSettings(legacyBackup);

        expect(GStorage.setting.get(SettingBoxKey.videoSync), 'audio');
        expect(GStorage.setting.get(SettingBoxKey.videoSyncV2Migrated), isTrue);
        expect(GStorage.setting.get(SettingBoxKey.feedBackEnable), isTrue);
      },
    );

    test(
      'import modern backup: preserves explicit display-resample when already migrated',
      () async {
        final modernBackup = jsonEncode({
          StorageBoxName.setting: {
            SettingBoxKey.videoSync: 'display-resample',
            SettingBoxKey.videoSyncV2Migrated: true,
          },
          StorageBoxName.video: {},
        });

        await GStorage.importAllSettings(modernBackup);

        expect(
          GStorage.setting.get(SettingBoxKey.videoSync),
          'display-resample',
        );
        expect(GStorage.setting.get(SettingBoxKey.videoSyncV2Migrated), isTrue);
      },
    );
  });
}

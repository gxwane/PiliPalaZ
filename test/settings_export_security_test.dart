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
      'pilipalaz-settings-security-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
    GStorage.userInfo = await Hive.openBox<dynamic>(StorageBoxName.userInfo);
  });

  setUp(() async {
    await GStorage.setting.clear();
    await GStorage.video.clear();
    await GStorage.localCache.clear();
    await GStorage.userInfo.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('export contains only the explicit setting and video roots', () async {
    await GStorage.setting.put('theme', 'dark');
    await GStorage.video.put('speed', 1.5);
    await GStorage.localCache.put(LocalCacheKey.accessKey, <String, String>{
      'value': 'fake-access-token',
    });
    await GStorage.userInfo.put('userInfoCache', <String, Object?>{'mid': 42});

    final decoded =
        jsonDecode(await GStorage.exportAllSettings()) as Map<String, dynamic>;

    expect(decoded.keys.toSet(), GStorage.exportableBoxNames);
    expect(jsonEncode(decoded), isNot(contains('fake-access-token')));
    expect(decoded, isNot(contains(StorageBoxName.localCache)));
    expect(decoded, isNot(contains(StorageBoxName.userInfo)));
  });

  test('import ignores secret and non-settings roots', () async {
    await GStorage.localCache.put(LocalCacheKey.accessKey, <String, String>{
      'value': 'existing-local-sentinel',
    });
    await GStorage.userInfo.put('userInfoCache', 'existing-profile-sentinel');

    await GStorage.importAllSettings(
      jsonEncode(<String, Object?>{
        StorageBoxName.setting: <String, Object?>{'theme': 'light'},
        StorageBoxName.video: <String, Object?>{'speed': 2},
        StorageBoxName.localCache: <String, Object?>{
          LocalCacheKey.accessKey: <String, String>{
            'value': 'imported-access-token',
          },
        },
        StorageBoxName.userInfo: <String, Object?>{
          'userInfoCache': 'imported-profile',
        },
        'access_token': 'imported-access-token',
        'refresh_token': 'imported-refresh-token',
        'cookie': 'SESSDATA=imported-cookie',
      }),
    );

    expect(GStorage.setting.get('theme'), 'light');
    expect(GStorage.video.get('speed'), 2);
    expect(
      GStorage.localCache.get(LocalCacheKey.accessKey)['value'],
      'existing-local-sentinel',
    );
    expect(GStorage.userInfo.get('userInfoCache'), 'existing-profile-sentinel');
  });

  test(
    'malformed allowed roots are rejected before settings are cleared',
    () async {
      await GStorage.setting.put('theme', 'existing');
      await GStorage.video.put('speed', 1);

      await expectLater(
        GStorage.importAllSettings(
          jsonEncode(<String, Object?>{
            StorageBoxName.setting: 'not-an-object',
            StorageBoxName.video: <String, Object?>{},
          }),
        ),
        throwsFormatException,
      );

      expect(GStorage.setting.get('theme'), 'existing');
      expect(GStorage.video.get('speed'), 1);
    },
  );
}

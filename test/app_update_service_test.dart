import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/github/latest.dart';
import 'package:pilipalaz/services/app_update_service.dart';

const _hash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

LatestDataModel _release({bool prerelease = false}) {
  return LatestDataModel(
    tagName: prerelease ? 'v1.3.0-beta.1' : 'v1.2.1',
    htmlUrl: 'https://github.com/gxwane/PiliPalaZ/releases/tag/test',
    prerelease: prerelease,
    assets: const <AssetItem>[
      AssetItem(
        name: 'PiliPalaZ-android-arm64-v8a-v1.2.1.apk',
        downloadUrl: 'https://github.com/example/app.apk',
      ),
      AssetItem(
        name: 'SHA256SUMS',
        downloadUrl: 'https://github.com/example/SHA256SUMS',
      ),
    ],
  );
}

class FakeReleaseRepository implements AppUpdateReleaseRepository {
  FakeReleaseRepository({this.manifest = _hash});

  String manifest;
  List<LatestDataModel> releases = <LatestDataModel>[];
  LatestDataModel? stable;

  @override
  Future<List<LatestDataModel>> fetchReleases() async => releases;

  @override
  Future<LatestDataModel?> fetchLatestStable() async => stable;

  @override
  Future<String> fetchText(String url) async {
    return '$manifest  PiliPalaZ-android-arm64-v8a-v1.2.1.apk';
  }
}

class MemoryUpdateTaskStore implements AppUpdateTaskStore {
  AppUpdateTask? task;

  @override
  Future<void> clear() async => task = null;

  @override
  AppUpdateTask? read() => task;

  @override
  Future<void> write(AppUpdateTask value) async => task = value;
}

class FakeUpdatePlatform implements AppUpdatePlatform {
  int enqueueCount = 0;
  int cancelCount = 0;
  int installCount = 0;
  int settingsCount = 0;
  bool installAllowed = true;
  String digest = _hash;
  UpdateDownloadSnapshot snapshot = const UpdateDownloadSnapshot(
    status: UpdateDownloadStatus.successful,
    downloadedBytes: 100,
    totalBytes: 100,
  );

  @override
  bool get supportsInAppInstall => true;

  @override
  Future<void> cancel(int downloadId) async => cancelCount++;

  @override
  Future<bool> canInstallPackages() async => installAllowed;

  @override
  Future<int> enqueue({
    required String url,
    required String fileName,
    required String title,
  }) async {
    enqueueCount++;
    return enqueueCount;
  }

  @override
  Future<void> install({
    required int downloadId,
    required String fileName,
  }) async {
    installCount++;
  }

  @override
  Future<void> openInstallPermissionSettings() async => settingsCount++;

  @override
  Future<UpdateDownloadSnapshot> query(int downloadId) async => snapshot;

  @override
  Future<String> sha256(int downloadId) async => digest;
}

void main() {
  late FakeReleaseRepository repository;
  late MemoryUpdateTaskStore store;
  late FakeUpdatePlatform platform;
  late AppUpdateService service;

  setUp(() {
    repository = FakeReleaseRepository();
    store = MemoryUpdateTaskStore();
    platform = FakeUpdatePlatform();
    service = AppUpdateService(
      repository: repository,
      platform: platform,
      taskStore: store,
    );
  });

  test(
    'manual checks return independent stable and prerelease candidates',
    () async {
      repository.releases = <LatestDataModel>[
        _release(),
        LatestDataModel(tagName: 'v1.3.0-beta.1', prerelease: true),
      ];

      final candidates = await service.findCandidates('1.2.0+1');

      expect(candidates.stable?.tagName, 'v1.2.1');
      expect(candidates.prerelease?.tagName, 'v1.3.0-beta.1');
    },
  );

  test(
    'starts one verified download definition and reuses duplicate taps',
    () async {
      final first = await service.startDownload(_release(), 'arm64-v8a');
      final second = await service.startDownload(_release(), 'arm64-v8a');

      expect(first.downloadId, 1);
      expect(first.expectedSha256, _hash);
      expect(second.downloadId, first.downloadId);
      expect(platform.enqueueCount, 1);
      expect(store.task, second);
    },
  );

  test('checksum mismatch removes the unsafe download', () async {
    await service.startDownload(_release(), 'arm64-v8a');
    platform.digest =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    expect(
      () => service.refreshActiveTask(),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.code,
          'code',
          AppUpdateErrorCode.checksumMismatch,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(platform.cancelCount, 1);
    expect(store.task, isNull);
  });

  test(
    'install permission is requested once and install resumes afterwards',
    () async {
      await service.startDownload(_release(), 'arm64-v8a');
      await service.refreshActiveTask();
      platform.installAllowed = false;

      expect(await service.installActiveTask(), isFalse);
      expect(platform.settingsCount, 1);
      expect(store.task?.awaitingInstallPermission, isTrue);

      platform.installAllowed = true;
      expect(await service.resumePendingInstall(), isTrue);
      expect(platform.installCount, 1);
      expect(store.task?.awaitingInstallPermission, isFalse);
    },
  );
}

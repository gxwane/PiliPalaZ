import 'package:pilipalaz/models/github/latest.dart';
import 'package:pilipalaz/utils/app_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';

LatestDataModel release(
  String tag, {
  bool prerelease = false,
  bool draft = false,
  List<AssetItem> assets = const <AssetItem>[],
}) {
  return LatestDataModel(
    tagName: tag,
    htmlUrl: 'https://github.com/gxwane/PiliPalaZ/releases/tag/$tag',
    prerelease: prerelease,
    draft: draft,
    assets: assets,
  );
}

void main() {
  group('AppUpdatePolicy.parseVersion', () {
    test('accepts release tags and ignores build metadata for precedence', () {
      expect(AppUpdatePolicy.parseVersion('v1.2.0'), Version(1, 2, 0));
      expect(AppUpdatePolicy.parseVersion('1.2.0+114520'), Version(1, 2, 0));
      expect(
        AppUpdatePolicy.parseVersion(
          '1.2.0+1',
        )!.compareTo(AppUpdatePolicy.parseVersion('1.2.0+999')!),
        0,
      );
      expect(AppUpdatePolicy.parseVersion('not-a-version'), isNull);
    });

    test('orders alpha, beta, rc, and stable versions semantically', () {
      final versions = <Version>[
        AppUpdatePolicy.parseVersion('v1.3.0')!,
        AppUpdatePolicy.parseVersion('v1.3.0-rc.1')!,
        AppUpdatePolicy.parseVersion('v1.3.0-alpha.1')!,
        AppUpdatePolicy.parseVersion('v1.3.0-beta.1')!,
      ]..sort();

      expect(versions.map((version) => version.toString()), <String>[
        '1.3.0-alpha.1',
        '1.3.0-beta.1',
        '1.3.0-rc.1',
        '1.3.0',
      ]);
    });
  });

  group('AppUpdatePolicy.selectCandidates', () {
    test('selects stable and prerelease candidates independently', () {
      final selected = AppUpdatePolicy.selectCandidates(
        localVersion: '1.2.0+114520',
        releases: <LatestDataModel>[
          release('v1.3.0-beta.1', prerelease: true),
          release('v1.2.2', draft: true),
          release('v1.2.1'),
        ],
      );

      expect(selected.stable?.tagName, 'v1.2.1');
      expect(selected.prerelease?.tagName, 'v1.3.0-beta.1');
    });

    test(
      'never selects a candidate that would downgrade the installed app',
      () {
        final selected = AppUpdatePolicy.selectCandidates(
          localVersion: '1.3.0-beta.1+114521',
          releases: <LatestDataModel>[
            release('invalid', prerelease: true),
            release('v1.3.0-rc.1', prerelease: true),
            release('v1.2.9'),
            release('v1.3.0'),
          ],
        );

        expect(selected.stable?.tagName, 'v1.3.0');
        expect(selected.prerelease?.tagName, 'v1.3.0-rc.1');
      },
    );

    test('returns empty candidates when no valid newer release exists', () {
      final selected = AppUpdatePolicy.selectCandidates(
        localVersion: 'v1.2.0',
        releases: <LatestDataModel>[
          release('broken'),
          release('v1.2.0'),
          release('v1.1.5'),
        ],
      );

      expect(selected.stable, isNull);
      expect(selected.prerelease, isNull);
    });
  });

  group('AppUpdatePolicy.selectAndroidAsset', () {
    final assets = <AssetItem>[
      AssetItem(
        name: 'PiliPalaZ-android-universal-v1.3.0.apk',
        downloadUrl: 'https://example.invalid/universal.apk',
      ),
      AssetItem(
        name: 'PiliPalaZ-android-arm64-v8a-v1.3.0.apk',
        downloadUrl: 'https://example.invalid/arm64.apk',
      ),
    ];

    test('prefers an exact ABI asset', () {
      expect(
        AppUpdatePolicy.selectAndroidAsset(assets, 'arm64-v8a')?.name,
        contains('arm64-v8a'),
      );
    });

    test('falls back to the universal APK', () {
      expect(
        AppUpdatePolicy.selectAndroidAsset(assets, 'x86_64')?.name,
        contains('universal'),
      );
    });

    test('recognizes the legacy universal APK name', () {
      expect(
        AppUpdatePolicy.selectAndroidAsset(<AssetItem>[
          AssetItem(
            name: 'Pili-v1.2.0.apk',
            downloadUrl: 'https://example.invalid/legacy-universal.apk',
          ),
        ], 'x86_64')?.name,
        'Pili-v1.2.0.apk',
      );
    });

    test('returns null when no usable APK exists', () {
      expect(
        AppUpdatePolicy.selectAndroidAsset(<AssetItem>[
          AssetItem(name: 'PiliPalaZ-ios-unsigned-v1.3.0.ipa'),
        ], 'arm64-v8a'),
        isNull,
      );
    });

    test('rejects insecure URLs and unsafe filenames', () {
      expect(
        AppUpdatePolicy.selectAndroidAsset(<AssetItem>[
          AssetItem(
            name: '../PiliPalaZ-android-arm64-v8a.apk',
            downloadUrl: 'https://example.invalid/unsafe.apk',
          ),
          AssetItem(
            name: 'PiliPalaZ-android-arm64-v8a.apk',
            downloadUrl: 'http://example.invalid/insecure.apk',
          ),
        ], 'arm64-v8a'),
        isNull,
      );
    });
  });

  group('AppUpdatePolicy.selectChecksum', () {
    const checksum =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('matches an exact APK filename', () {
      expect(
        AppUpdatePolicy.selectChecksum(
          '$checksum  PiliPalaZ-android-arm64-v8a-v1.3.0.apk\n',
          'PiliPalaZ-android-arm64-v8a-v1.3.0.apk',
        ),
        checksum,
      );
    });

    test('supports the sha256sum binary marker and uppercase hashes', () {
      expect(
        AppUpdatePolicy.selectChecksum(
          '${checksum.toUpperCase()} *PiliPalaZ-android-universal-v1.3.0.apk',
          'PiliPalaZ-android-universal-v1.3.0.apk',
        ),
        checksum,
      );
    });

    test('rejects malformed hashes and non-exact filenames', () {
      expect(
        AppUpdatePolicy.selectChecksum(
          'not-a-hash  PiliPalaZ-android-arm64-v8a-v1.3.0.apk\n'
              '$checksum  nested/PiliPalaZ-android-arm64-v8a-v1.3.0.apk',
          'PiliPalaZ-android-arm64-v8a-v1.3.0.apk',
        ),
        isNull,
      );
    });
  });
}

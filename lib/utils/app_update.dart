import 'package:pilipalaz/models/github/latest.dart';
import 'package:pub_semver/pub_semver.dart';

class AppUpdateCandidates {
  const AppUpdateCandidates({this.stable, this.prerelease});

  final LatestDataModel? stable;
  final LatestDataModel? prerelease;
}

class AppUpdatePolicy {
  AppUpdatePolicy._();

  static Version? parseVersion(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final parsed = Version.parse(normalized);
      return Version(
        parsed.major,
        parsed.minor,
        parsed.patch,
        pre: parsed.preRelease.isEmpty ? null : parsed.preRelease.join('.'),
      );
    } on FormatException {
      return null;
    }
  }

  static LatestDataModel? selectRelease({
    required String localVersion,
    required Iterable<LatestDataModel> releases,
  }) {
    final local = parseVersion(localVersion);
    if (local == null) {
      return null;
    }

    final candidates = selectCandidates(
      localVersion: localVersion,
      releases: releases,
    );
    if (!local.isPreRelease) {
      return candidates.stable;
    }
    final stableVersion = parseVersion(candidates.stable?.tagName);
    final prereleaseVersion = parseVersion(candidates.prerelease?.tagName);
    if (stableVersion == null) {
      return candidates.prerelease;
    }
    if (prereleaseVersion == null || stableVersion >= prereleaseVersion) {
      return candidates.stable;
    }
    return candidates.prerelease;
  }

  static AppUpdateCandidates selectCandidates({
    required String localVersion,
    required Iterable<LatestDataModel> releases,
  }) {
    final local = parseVersion(localVersion);
    if (local == null) {
      return const AppUpdateCandidates();
    }

    LatestDataModel? stable;
    Version? stableVersion;
    LatestDataModel? prerelease;
    Version? prereleaseVersion;

    for (final release in releases) {
      if (release.draft) {
        continue;
      }
      final candidate = parseVersion(release.tagName);
      if (candidate == null || candidate <= local) {
        continue;
      }
      if (release.prerelease) {
        if (prereleaseVersion == null || candidate > prereleaseVersion) {
          prerelease = release;
          prereleaseVersion = candidate;
        }
      } else if (stableVersion == null || candidate > stableVersion) {
        stable = release;
        stableVersion = candidate;
      }
    }
    return AppUpdateCandidates(stable: stable, prerelease: prerelease);
  }

  static AssetItem? selectAndroidAsset(Iterable<AssetItem> assets, String abi) {
    final apkAssets = assets
        .where((asset) {
          final name = asset.name?.toLowerCase() ?? '';
          return name.endsWith('.apk') && isSafeAndroidAsset(asset);
        })
        .toList(growable: false);
    final normalizedAbi = abi.toLowerCase();

    if (normalizedAbi.isNotEmpty) {
      for (final asset in apkAssets) {
        if (asset.name!.toLowerCase().contains(normalizedAbi)) {
          return asset;
        }
      }
    }
    for (final asset in apkAssets) {
      if (asset.name!.toLowerCase().contains('universal')) {
        return asset;
      }
    }

    const knownAbis = <String>['arm64-v8a', 'armeabi-v7a', 'x86_64'];
    for (final asset in apkAssets) {
      final name = asset.name!.toLowerCase();
      if (!knownAbis.any(name.contains)) {
        return asset;
      }
    }
    return null;
  }

  static bool isSafeAndroidAsset(AssetItem asset) {
    final name = asset.name;
    final url = Uri.tryParse(asset.downloadUrl ?? '');
    return name != null &&
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*\.apk$').hasMatch(name) &&
        url != null &&
        url.scheme == 'https' &&
        url.host.isNotEmpty;
  }

  static String? selectChecksum(String manifest, String assetName) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*\.apk$').hasMatch(assetName)) {
      return null;
    }
    final linePattern = RegExp(r'^([0-9A-Fa-f]{64})[ \t]+[*]?(.+)$');
    for (final line in manifest.split(RegExp(r'\r?\n'))) {
      final match = linePattern.firstMatch(line.trim());
      if (match != null && match.group(2) == assetName) {
        return match.group(1)!.toLowerCase();
      }
    }
    return null;
  }
}

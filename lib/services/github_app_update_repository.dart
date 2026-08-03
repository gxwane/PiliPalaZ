import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/models/github/latest.dart';
import 'package:pilipalaz/services/app_update_service.dart';
import 'package:pilipalaz/utils/app_update.dart';
import 'package:pilipalaz/utils/storage.dart';

class GitHubAppUpdateReleaseRepository implements AppUpdateReleaseRepository {
  GitHubAppUpdateReleaseRepository({Dio? client})
    : _client = client ?? _createClient() {
    _client.options.headers.addAll(const <String, String>{
      Headers.acceptHeader: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'PiliPalaZ',
    });
  }

  static const String _atomUrl = '${ProjectLinks.releases}.atom';
  static const String _latestReleaseUrl = '${ProjectLinks.releases}/latest';
  static const String _fallbackFailureMessage =
      'GitHub API 已限流，备用更新源也无法访问，请稍后重试';

  final Dio _client;

  @override
  Future<List<LatestDataModel>> fetchReleases() async {
    try {
      return await _fetchApiReleases();
    } on _GitHubRateLimitException {
      return _fetchFallbackReleases();
    }
  }

  @override
  Future<LatestDataModel?> fetchLatestStable() async {
    try {
      final response = await _client.get<dynamic>(
        ProjectLinks.latestReleaseApi,
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['tag_name'] is! String) {
        throw const AppUpdateException(
          AppUpdateErrorCode.invalidResponse,
          'GitHub Release 返回了无效数据',
        );
      }
      return LatestDataModel.fromJson(data);
    } on DioException catch (error) {
      if (!_isRateLimited(error.response)) {
        throw _requestFailure(error);
      }
      final releases = await _fetchFallbackReleases();
      return _latestStable(releases);
    }
  }

  @override
  Future<String> fetchText(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AppUpdateException(
        AppUpdateErrorCode.checksumUnavailable,
        '安装包校验清单地址无效',
      );
    }
    try {
      final response = await _client.get<String>(
        uri.toString(),
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data == null) {
        throw const AppUpdateException(
          AppUpdateErrorCode.checksumUnavailable,
          '无法获取安装包校验清单',
        );
      }
      return data;
    } on AppUpdateException {
      rethrow;
    } on DioException {
      throw const AppUpdateException(
        AppUpdateErrorCode.checksumUnavailable,
        '无法获取安装包校验清单，请检查网络后重试',
      );
    }
  }

  Future<List<LatestDataModel>> _fetchApiReleases() async {
    try {
      final response = await _client.get<dynamic>(
        ProjectLinks.releasesApi,
        queryParameters: const <String, dynamic>{'per_page': 30},
      );
      final data = response.data;
      if (data is! List) {
        throw const AppUpdateException(
          AppUpdateErrorCode.invalidResponse,
          'GitHub Releases 返回了无效数据',
        );
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(LatestDataModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      if (_isRateLimited(error.response)) {
        throw const _GitHubRateLimitException();
      }
      throw _requestFailure(error);
    }
  }

  Future<List<LatestDataModel>> _fetchFallbackReleases() async {
    try {
      final response = await _client.get<String>(
        _atomUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty GitHub Releases feed');
      }
      final releases = _parseAtomFeed(data).toList(growable: true);
      if (releases.isEmpty) {
        throw const FormatException('No valid GitHub Releases feed entries');
      }
      if (!releases.any((release) => !release.prerelease)) {
        final stable = await _fetchLatestStableRedirect();
        if (stable != null) {
          releases.add(stable);
        }
      }
      return List<LatestDataModel>.unmodifiable(releases);
    } on AppUpdateException {
      rethrow;
    } on Object {
      throw const AppUpdateException(
        AppUpdateErrorCode.invalidResponse,
        _fallbackFailureMessage,
      );
    }
  }

  Iterable<LatestDataModel> _parseAtomFeed(String source) sync* {
    final document = html_parser.parse(source);
    for (final entry in document.querySelectorAll('entry')) {
      final alternateLink = entry.querySelectorAll('link').where((link) {
        return link.attributes['rel'] == 'alternate' &&
            link.attributes['href'] != null;
      }).firstOrNull;
      final releaseUri = Uri.tryParse(alternateLink?.attributes['href'] ?? '');
      final tag = _releaseTag(releaseUri);
      final version = AppUpdatePolicy.parseVersion(tag);
      if (releaseUri == null || tag == null || version == null) {
        continue;
      }
      final encodedBody = entry.querySelector('content')?.text ?? '';
      final body = (html_parser.parseFragment(encodedBody).text ?? '').trim();
      yield LatestDataModel(
        htmlUrl: releaseUri.toString(),
        tagName: tag,
        createdAt: entry.querySelector('updated')?.text.trim(),
        assets: _releaseAssets(tag),
        body: body,
        bodyHtml: encodedBody.trim(),
        prerelease: version.isPreRelease,
      );
    }
  }

  Future<LatestDataModel?> _fetchLatestStableRedirect() async {
    try {
      final response = await _client.get<String>(
        _latestReleaseUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      final location = response.headers.value('location');
      final releaseUri = location == null
          ? response.realUri
          : response.realUri.resolve(location);
      final tag = _releaseTag(releaseUri);
      final version = AppUpdatePolicy.parseVersion(tag);
      if (tag == null || version == null || version.isPreRelease) {
        return null;
      }
      return LatestDataModel(
        htmlUrl: releaseUri.toString(),
        tagName: tag,
        assets: _releaseAssets(tag),
      );
    } on Object {
      return null;
    }
  }

  LatestDataModel? _latestStable(Iterable<LatestDataModel> releases) {
    LatestDataModel? selected;
    for (final release in releases.where((release) => !release.prerelease)) {
      final version = AppUpdatePolicy.parseVersion(release.tagName);
      final selectedVersion = AppUpdatePolicy.parseVersion(selected?.tagName);
      if (version != null &&
          (selectedVersion == null || version > selectedVersion)) {
        selected = release;
      }
    }
    return selected;
  }

  String? _releaseTag(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'github.com') {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.length != 5 ||
        segments[0].toLowerCase() != 'gxwane' ||
        segments[1].toLowerCase() != 'pilipalaz' ||
        segments[2] != 'releases' ||
        segments[3] != 'tag' ||
        segments[4].isEmpty) {
      return null;
    }
    return segments[4];
  }

  List<AssetItem> _releaseAssets(String tag) {
    final version = tag.replaceFirst(RegExp(r'^[vV]'), '');
    final names = <String>[
      'PiliPalaZ-android-arm64-v8a-v$version.apk',
      'PiliPalaZ-android-armeabi-v7a-v$version.apk',
      'PiliPalaZ-android-x86_64-v$version.apk',
      'PiliPalaZ-android-universal-v$version.apk',
      'PiliPalaZ-ios-unsigned-v$version.ipa',
      'SHA256SUMS',
    ];
    return names
        .map(
          (name) => AssetItem(
            name: name,
            downloadUrl: Uri(
              scheme: 'https',
              host: 'github.com',
              pathSegments: <String>[
                'gxwane',
                'PiliPalaZ',
                'releases',
                'download',
                tag,
                name,
              ],
            ).toString(),
          ),
        )
        .toList(growable: false);
  }

  bool _isRateLimited(Response<dynamic>? response) {
    final status = response?.statusCode;
    if (status != 403 && status != 429) {
      return false;
    }
    if (response!.headers.value('x-ratelimit-remaining') == '0' ||
        response.headers.value('retry-after') != null) {
      return true;
    }
    final data = response.data;
    final message = data is Map
        ? data['message']?.toString()
        : data?.toString();
    return message?.toLowerCase().contains('rate limit') == true;
  }

  AppUpdateException _requestFailure(DioException error) {
    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout => '连接 GitHub 超时，请检查网络后重试',
      DioExceptionType.connectionError => '无法连接 GitHub，请检查网络或代理设置',
      DioExceptionType.badCertificate => 'GitHub 连接证书校验失败',
      _ => 'GitHub 更新服务暂时不可用，请稍后重试',
    };
    return AppUpdateException(AppUpdateErrorCode.invalidResponse, message);
  }

  static Dio _createClient() {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
    final setting = GStorage.setting;
    final enabled = setting.get(
      SettingBoxKey.enableSystemProxy,
      defaultValue: false,
    );
    final host = setting
        .get(SettingBoxKey.systemProxyHost, defaultValue: '')
        .toString()
        .trim();
    final port = setting
        .get(SettingBoxKey.systemProxyPort, defaultValue: '')
        .toString()
        .trim();
    if (enabled == true && host.isNotEmpty && int.tryParse(port) != null) {
      client.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final httpClient = HttpClient();
          httpClient.findProxy = (_) => 'PROXY $host:$port';
          return httpClient;
        },
      );
    }
    return client;
  }
}

class _GitHubRateLimitException implements Exception {
  const _GitHubRateLimitException();
}

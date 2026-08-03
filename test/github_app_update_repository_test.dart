import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/app_update_service.dart';
import 'package:pilipalaz/services/github_app_update_repository.dart';

typedef _ResponseHandler = ResponseBody Function(RequestOptions options);

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final _ResponseHandler handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(_RecordingAdapter adapter) {
  final client = Dio();
  client.httpClientAdapter = adapter;
  return client;
}

ResponseBody _jsonResponse(Object value, int statusCode, {int? remaining}) {
  return ResponseBody.fromString(
    jsonEncode(value),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      if (remaining != null) 'x-ratelimit-remaining': <String>['$remaining'],
    },
  );
}

ResponseBody _textResponse(String value, int statusCode) {
  return ResponseBody.fromString(
    value,
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[
        'application/atom+xml; charset=utf-8',
      ],
    },
  );
}

const String _releaseFeed = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>tag:github.com,2008:Repository/1284569999/v1.3.0-beta.3</id>
    <updated>2026-08-03T13:41:36Z</updated>
    <link rel="alternate" type="text/html"
      href="https://github.com/gxwane/PiliPalaZ/releases/tag/v1.3.0-beta.3" />
    <title>PiliPalaZ v1.3.0-beta.3</title>
    <content type="html">&lt;h3&gt;修复&lt;/h3&gt;&lt;ul&gt;&lt;li&gt;VPN 更新检查&lt;/li&gt;&lt;/ul&gt;</content>
  </entry>
  <entry>
    <id>tag:github.com,2008:Repository/1284569999/v1.2.3</id>
    <updated>2026-07-25T15:47:25Z</updated>
    <link rel="alternate" type="text/html"
      href="https://github.com/gxwane/PiliPalaZ/releases/tag/v1.2.3" />
    <title>PiliPalaZ v1.2.3</title>
    <content type="html">&lt;p&gt;稳定版说明&lt;/p&gt;</content>
  </entry>
  <entry>
    <updated>2026-08-03T13:41:36Z</updated>
    <link rel="alternate" type="text/html"
      href="https://example.com/gxwane/PiliPalaZ/releases/tag/v9.9.9" />
    <title>foreign release</title>
  </entry>
</feed>
''';

const String _prereleaseOnlyFeed = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <updated>2026-08-03T13:41:36Z</updated>
    <link rel="alternate" type="text/html"
      href="https://github.com/gxwane/PiliPalaZ/releases/tag/v1.3.0-beta.3" />
    <title>PiliPalaZ v1.3.0-beta.3</title>
    <content type="html">&lt;p&gt;测试版说明&lt;/p&gt;</content>
  </entry>
</feed>
''';

void main() {
  group('GitHubAppUpdateReleaseRepository', () {
    test('uses the REST response without requesting the Atom fallback', () async {
      final adapter = _RecordingAdapter((options) {
        expect(options.uri.host, 'api.github.com');
        return _jsonResponse(<Map<String, Object?>>[
          <String, Object?>{
            'tag_name': 'v1.3.0-beta.3',
            'html_url':
                'https://github.com/gxwane/PiliPalaZ/releases/tag/v1.3.0-beta.3',
            'body': '## 修复\n\n- 保留 **Markdown** 格式',
            'prerelease': true,
            'draft': false,
            'assets': <Object?>[],
          },
        ], 200);
      });
      final repository = GitHubAppUpdateReleaseRepository(
        client: _client(adapter),
      );

      final releases = await repository.fetchReleases();

      expect(releases.single.tagName, 'v1.3.0-beta.3');
      expect(releases.single.body, '## 修复\n\n- 保留 **Markdown** 格式');
      expect(releases.single.bodyHtml, isEmpty);
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers[Headers.acceptHeader],
        'application/vnd.github+json',
      );
    });

    test(
      'falls back to Atom when the shared VPN exit is rate limited',
      () async {
        final adapter = _RecordingAdapter((options) {
          if (options.uri.host == 'api.github.com') {
            return _jsonResponse(
              <String, Object?>{'message': 'API rate limit exceeded'},
              403,
              remaining: 0,
            );
          }
          if (options.uri.path.endsWith('/releases.atom')) {
            return _textResponse(_releaseFeed, 200);
          }
          fail('Unexpected request: ${options.uri}');
        });
        final repository = GitHubAppUpdateReleaseRepository(
          client: _client(adapter),
        );

        final releases = await repository.fetchReleases();

        expect(releases.map((release) => release.tagName), <String?>[
          'v1.3.0-beta.3',
          'v1.2.3',
        ]);
        final prerelease = releases.first;
        expect(prerelease.prerelease, isTrue);
        expect(prerelease.createdAt, '2026-08-03T13:41:36Z');
        expect(prerelease.body, contains('VPN 更新检查'));
        expect(prerelease.bodyHtml, '<h3>修复</h3><ul><li>VPN 更新检查</li></ul>');
        expect(
          prerelease.assets.map((asset) => asset.name),
          containsAll(<String>[
            'PiliPalaZ-android-arm64-v8a-v1.3.0-beta.3.apk',
            'PiliPalaZ-android-armeabi-v7a-v1.3.0-beta.3.apk',
            'PiliPalaZ-android-x86_64-v1.3.0-beta.3.apk',
            'PiliPalaZ-android-universal-v1.3.0-beta.3.apk',
            'PiliPalaZ-ios-unsigned-v1.3.0-beta.3.ipa',
            'SHA256SUMS',
          ]),
        );
        expect(
          prerelease.assets.every(
            (asset) => Uri.parse(asset.downloadUrl!).scheme == 'https',
          ),
          isTrue,
        );
      },
    );

    test('automatic stable checks use the same rate-limit fallback', () async {
      final adapter = _RecordingAdapter((options) {
        if (options.uri.host == 'api.github.com') {
          expect(options.uri.path, endsWith('/releases/latest'));
          return _jsonResponse(
            <String, Object?>{'message': 'API rate limit exceeded'},
            403,
            remaining: 0,
          );
        }
        if (options.uri.path.endsWith('/releases.atom')) {
          return _textResponse(_releaseFeed, 200);
        }
        fail('Unexpected request: ${options.uri}');
      });
      final repository = GitHubAppUpdateReleaseRepository(
        client: _client(adapter),
      );

      final release = await repository.fetchLatestStable();

      expect(release?.tagName, 'v1.2.3');
      expect(release?.prerelease, isFalse);
    });

    test(
      'does not treat an unrelated forbidden response as rate limiting',
      () async {
        final adapter = _RecordingAdapter((options) {
          return _jsonResponse(
            <String, Object?>{'message': 'Resource not accessible'},
            403,
            remaining: 42,
          );
        });
        final repository = GitHubAppUpdateReleaseRepository(
          client: _client(adapter),
        );

        await expectLater(
          repository.fetchReleases(),
          throwsA(isA<AppUpdateException>()),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test(
      'uses the latest stable redirect when Atom has only prereleases',
      () async {
        final adapter = _RecordingAdapter((options) {
          if (options.uri.host == 'api.github.com') {
            return _jsonResponse(
              <String, Object?>{'message': 'API rate limit exceeded'},
              429,
              remaining: 0,
            );
          }
          if (options.uri.path.endsWith('/releases.atom')) {
            return _textResponse(_prereleaseOnlyFeed, 200);
          }
          if (options.uri.path.endsWith('/releases/latest')) {
            return ResponseBody.fromString(
              '',
              302,
              headers: <String, List<String>>{
                'location': <String>[
                  'https://github.com/gxwane/PiliPalaZ/releases/tag/v1.2.3',
                ],
              },
            );
          }
          fail('Unexpected request: ${options.uri}');
        });
        final repository = GitHubAppUpdateReleaseRepository(
          client: _client(adapter),
        );

        final releases = await repository.fetchReleases();

        expect(releases.map((release) => release.tagName), <String?>[
          'v1.3.0-beta.3',
          'v1.2.3',
        ]);
        expect(releases.last.prerelease, isFalse);
      },
    );

    test('reports a clear error when both rate-limited sources fail', () async {
      final adapter = _RecordingAdapter((options) {
        if (options.uri.host == 'api.github.com') {
          return _jsonResponse(
            <String, Object?>{'message': 'API rate limit exceeded'},
            403,
            remaining: 0,
          );
        }
        return _textResponse('unavailable', 503);
      });
      final repository = GitHubAppUpdateReleaseRepository(
        client: _client(adapter),
      );

      await expectLater(
        repository.fetchReleases(),
        throwsA(
          isA<AppUpdateException>().having(
            (error) => error.message,
            'message',
            allOf(contains('GitHub API 已限流'), contains('备用更新源')),
          ),
        ),
      );
    });
  });
}

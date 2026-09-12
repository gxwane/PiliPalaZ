import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/auth/webview_session_bridge.dart';

void main() {
  group('isAllowedBilibiliUri', () {
    test('allows only HTTPS Bilibili hosts', () {
      expect(isAllowedBilibiliUri(Uri.parse('https://bilibili.com')), isTrue);
      expect(
        isAllowedBilibiliUri(Uri.parse('https://www.bilibili.com/video')),
        isTrue,
      );
      expect(isAllowedBilibiliUri(Uri.parse('https://bilibili.cn')), isTrue);
      expect(
        isAllowedBilibiliUri(Uri.parse('https://passport.bilibili.tv')),
        isTrue,
      );

      expect(
        isAllowedBilibiliUri(Uri.parse('http://www.bilibili.com')),
        isFalse,
      );
      expect(
        isAllowedBilibiliUri(Uri.parse('https://evilbilibili.com')),
        isFalse,
      );
      expect(
        isAllowedBilibiliUri(Uri.parse('https://bilibili.com.evil.test')),
        isFalse,
      );
      expect(isAllowedBilibiliUri(Uri.parse('https://example.com')), isFalse);
    });
  });

  group('WebViewSessionBridge', () {
    test('clear removes all WebView cookies', () async {
      final cookieJar = _RecordingCookieJar(<Cookie>[]);
      final cookieStore = _RecordingWebViewCookieStore();
      final bridge = WebViewSessionBridge(
        cookieJar: cookieJar,
        webViewCookieStore: cookieStore,
      );

      await bridge.clear();

      expect(cookieStore.clearCount, 1);
      expect(cookieStore.cookies, isEmpty);
      expect(cookieJar.loadedUris, isEmpty);
    });

    test('injects only cookies returned for an allowed URI', () async {
      final cookies = <Cookie>[
        Cookie('SESSDATA', 'fake-session')
          ..domain = '.bilibili.com'
          ..path = '/'
          ..secure = true
          ..httpOnly = true,
        Cookie('bili_jct', 'fake-csrf')..path = '/account',
      ];
      final cookieJar = _RecordingCookieJar(cookies);
      final cookieStore = _RecordingWebViewCookieStore();
      final bridge = WebViewSessionBridge(
        cookieJar: cookieJar,
        webViewCookieStore: cookieStore,
      );
      final uri = Uri.parse('https://space.bilibili.com/account/profile');

      await bridge.prepare(uri);

      expect(cookieStore.clearCount, 1);
      expect(cookieJar.loadedUris, <Uri>[uri]);
      expect(cookieStore.cookies, <_RecordedWebViewCookie>[
        const _RecordedWebViewCookie(
          name: 'SESSDATA',
          value: 'fake-session',
          domain: '.bilibili.com',
          path: '/',
        ),
        const _RecordedWebViewCookie(
          name: 'bili_jct',
          value: 'fake-csrf',
          domain: 'space.bilibili.com',
          path: '/account',
        ),
      ]);
    });

    test('clears without reading or injecting for a third-party URI', () async {
      final cookieJar = _RecordingCookieJar(<Cookie>[
        Cookie('SESSDATA', 'must-not-leak')..domain = '.bilibili.com',
      ]);
      final cookieStore = _RecordingWebViewCookieStore();
      final bridge = WebViewSessionBridge(
        cookieJar: cookieJar,
        webViewCookieStore: cookieStore,
      );

      await bridge.prepare(Uri.parse('https://example.com'));

      expect(cookieStore.clearCount, 1);
      expect(cookieJar.loadedUris, isEmpty);
      expect(cookieStore.cookies, isEmpty);
    });

    test('clears partial injection when setting a cookie fails', () async {
      final cookieJar = _RecordingCookieJar(<Cookie>[
        Cookie('first', 'fake-first')..domain = '.bilibili.com',
        Cookie('second', 'fake-second')..domain = '.bilibili.com',
      ]);
      final cookieStore = _RecordingWebViewCookieStore(failAtSetCall: 2);
      final bridge = WebViewSessionBridge(
        cookieJar: cookieJar,
        webViewCookieStore: cookieStore,
      );

      await expectLater(
        bridge.prepare(Uri.parse('https://www.bilibili.com')),
        throwsStateError,
      );

      expect(cookieStore.clearCount, 2);
      expect(cookieStore.cookies, isEmpty);
    });
  });
}

final class _RecordingCookieJar implements CookieJar {
  _RecordingCookieJar(this.cookies);

  final List<Cookie> cookies;
  final List<Uri> loadedUris = <Uri>[];

  @override
  bool get ignoreExpires => false;

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async {
    loadedUris.add(uri);
    return cookies;
  }

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {}
}

final class _RecordingWebViewCookieStore implements WebViewCookieStore {
  _RecordingWebViewCookieStore({this.failAtSetCall});

  final int? failAtSetCall;
  final List<_RecordedWebViewCookie> cookies = <_RecordedWebViewCookie>[];
  int clearCount = 0;
  int _setCallCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    cookies.clear();
  }

  @override
  Future<void> setCookie({
    required String name,
    required String value,
    required String domain,
    required String path,
  }) async {
    _setCallCount += 1;
    if (_setCallCount == failAtSetCall) {
      throw StateError('synthetic WebView cookie failure');
    }
    cookies.add(
      _RecordedWebViewCookie(
        name: name,
        value: value,
        domain: domain,
        path: path,
      ),
    );
  }
}

final class _RecordedWebViewCookie {
  const _RecordedWebViewCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
  });

  final String name;
  final String value;
  final String domain;
  final String path;

  @override
  bool operator ==(Object other) =>
      other is _RecordedWebViewCookie &&
      name == other.name &&
      value == other.value &&
      domain == other.domain &&
      path == other.path;

  @override
  int get hashCode => Object.hash(name, value, domain, path);
}

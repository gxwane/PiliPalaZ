import 'package:cookie_jar/cookie_jar.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The narrow platform boundary used to manage cookies shared by WebViews.
abstract interface class WebViewCookieStore {
  Future<void> clear();

  Future<void> setCookie({
    required String name,
    required String value,
    required String domain,
    required String path,
  });
}

/// Production [WebViewCookieStore] backed by `webview_flutter`.
final class FlutterWebViewCookieStore implements WebViewCookieStore {
  FlutterWebViewCookieStore({WebViewCookieManager? cookieManager})
    : _cookieManager = cookieManager ?? WebViewCookieManager();

  final WebViewCookieManager _cookieManager;

  @override
  Future<void> clear() async {
    await _cookieManager.clearCookies();
  }

  @override
  Future<void> setCookie({
    required String name,
    required String value,
    required String domain,
    required String path,
  }) {
    return _cookieManager.setCookie(
      WebViewCookie(name: name, value: value, domain: domain, path: path),
    );
  }
}

/// Temporarily exposes the HTTP session to a trusted Bilibili WebView page.
///
/// WebView cookies are cleared before every preparation and should also be
/// cleared when the page closes. Credentials are sourced solely from the
/// in-memory [CookieJar]; access and refresh tokens are never injected.
final class WebViewSessionBridge {
  WebViewSessionBridge({
    required CookieJar cookieJar,
    WebViewCookieStore? webViewCookieStore,
  }) : _cookieJar = cookieJar,
       _webViewCookieStore = webViewCookieStore ?? FlutterWebViewCookieStore();

  final CookieJar _cookieJar;
  final WebViewCookieStore _webViewCookieStore;

  Future<void> clear() => _webViewCookieStore.clear();

  Future<void> prepare(Uri uri) async {
    await clear();
    if (!isAllowedBilibiliUri(uri)) {
      return;
    }

    try {
      final cookies = await _cookieJar.loadForRequest(uri);
      for (final cookie in cookies) {
        await _webViewCookieStore.setCookie(
          name: cookie.name,
          value: cookie.value,
          domain: _effectiveDomain(cookie, uri),
          path: _effectivePath(cookie),
        );
      }
    } catch (_) {
      try {
        await clear();
      } catch (_) {
        // Preserve the original failure while still making a best-effort
        // cleanup of any cookies injected before it.
      }
      rethrow;
    }
  }
}

bool isAllowedBilibiliUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https') {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host == 'bilibili.com' ||
      host.endsWith('.bilibili.com') ||
      host == 'bilibili.cn' ||
      host.endsWith('.bilibili.cn') ||
      host == 'bilibili.tv' ||
      host.endsWith('.bilibili.tv');
}

String _effectiveDomain(Cookie cookie, Uri uri) {
  final domain = cookie.domain;
  return domain == null || domain.isEmpty ? uri.host : domain;
}

String _effectivePath(Cookie cookie) {
  final path = cookie.path;
  return path == null || path.isEmpty ? '/' : path;
}

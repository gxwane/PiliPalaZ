import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/about/cache_usage_tile.dart';
import 'package:pilipalaz/utils/cache_manage.dart';

void main() {
  testWidgets('waits for the route transition before refreshing cache size', (
    tester,
  ) async {
    final cacheService = _FakeApplicationCacheService(cachedBytes: 2048);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: CacheUsageTile(
                    cacheService: cacheService,
                    onClear: () async => false,
                  ),
                ),
              ),
            ),
            child: const Text('打开关于页'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开关于页'));
    await tester.pump();

    expect(find.text('图片及网络缓存 2.00K', skipOffstage: false), findsOneWidget);
    expect(cacheService.refreshCalls, 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(cacheService.refreshCalls, 0);

    await tester.pumpAndSettle();
    expect(cacheService.refreshCalls, 1);

    cacheService.completeRefresh(4096);
    await tester.pumpAndSettle();
    expect(find.text('图片及网络缓存 4.00K', skipOffstage: false), findsOneWidget);
  });

  testWidgets('shows a loading label until the first refresh completes', (
    tester,
  ) async {
    final cacheService = _FakeApplicationCacheService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CacheUsageTile(
            cacheService: cacheService,
            onClear: () async => false,
          ),
        ),
      ),
    );

    expect(find.text('图片及网络缓存 计算中…'), findsOneWidget);
    expect(cacheService.refreshCalls, 1);

    cacheService.completeRefresh(512);
    await tester.pump();
    expect(find.text('图片及网络缓存 512.00B'), findsOneWidget);
  });

  testWidgets('shows a read error only when no cached value is available', (
    tester,
  ) async {
    final cacheService = _FakeApplicationCacheService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CacheUsageTile(
            cacheService: cacheService,
            onClear: () async => false,
          ),
        ),
      ),
    );
    cacheService.failRefresh(StateError('cache unavailable'));
    await tester.pump();

    expect(find.text('图片及网络缓存 暂时无法读取'), findsOneWidget);
  });

  testWidgets('ignores a refresh that completes after the page is disposed', (
    tester,
  ) async {
    final cacheService = _FakeApplicationCacheService();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: CacheUsageTile(
                    cacheService: cacheService,
                    onClear: () async => false,
                  ),
                ),
              ),
            ),
            child: const Text('打开关于页'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开关于页'));
    await tester.pumpAndSettle();
    expect(cacheService.refreshCalls, 1);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    cacheService.completeRefresh(1024);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('refreshes after an attempted clear but not after cancellation', (
    tester,
  ) async {
    final cacheService = _FakeApplicationCacheService(cachedBytes: 1024);
    var shouldRefreshAfterClear = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CacheUsageTile(
            cacheService: cacheService,
            onClear: () async => shouldRefreshAfterClear,
          ),
        ),
      ),
    );
    expect(cacheService.refreshCalls, 1);
    cacheService.completeRefresh(1024);
    await tester.pump();

    await tester.tap(find.text('清除缓存'));
    await tester.pump();
    expect(cacheService.refreshCalls, 1);

    shouldRefreshAfterClear = true;
    await tester.tap(find.text('清除缓存'));
    await tester.pump();
    expect(cacheService.refreshCalls, 2);
  });
}

class _FakeApplicationCacheService implements ApplicationCacheService {
  _FakeApplicationCacheService({int? cachedBytes})
    : cachedApplicationCacheSizeBytes = cachedBytes;

  @override
  int? cachedApplicationCacheSizeBytes;

  int refreshCalls = 0;
  final List<Completer<int?>> _refreshCompleters = <Completer<int?>>[];

  @override
  Future<void> clearApplicationCache() async {}

  @override
  Future<int?> refreshApplicationCacheSize() {
    refreshCalls++;
    final completer = Completer<int?>();
    _refreshCompleters.add(completer);
    return completer.future;
  }

  void completeRefresh(int? bytes) {
    cachedApplicationCacheSizeBytes = bytes;
    _refreshCompleters.removeAt(0).complete(bytes);
  }

  void failRefresh(Object error) {
    _refreshCompleters.removeAt(0).completeError(error, StackTrace.empty);
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/utils/cache_manage.dart';

void main() {
  test('cache management does not use synchronous filesystem APIs', () {
    final source = File('lib/utils/cache_manage.dart').readAsStringSync();

    expect(source, isNot(contains('listSync(')));
    expect(source, isNot(contains('existsSync(')));
    expect(source, isNot(contains('deleteSync(')));
  });

  group('CacheManage', () {
    late Directory rootDirectory;
    late Directory temporaryDirectory;
    late Directory documentsDirectory;
    late CacheManage cacheManage;

    setUp(() async {
      rootDirectory = await Directory.systemTemp.createTemp(
        'pilipalaz-cache-manage-test-',
      );
      temporaryDirectory = Directory(
        '${rootDirectory.path}${Platform.pathSeparator}cache',
      );
      documentsDirectory = Directory(
        '${rootDirectory.path}${Platform.pathSeparator}documents',
      );
      await temporaryDirectory.create();
      await documentsDirectory.create();
      cacheManage = CacheManage(
        temporaryDirectoryProvider: () async => temporaryDirectory,
        applicationDocumentsDirectoryProvider: () async => documentsDirectory,
      );
    });

    tearDown(() async {
      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    test('recursively totals temporary files and DioCache.db', () async {
      final nestedDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}nested',
      );
      await nestedDirectory.create();
      await File(
        '${temporaryDirectory.path}${Platform.pathSeparator}image.cache',
      ).writeAsBytes(List<int>.filled(1024, 1));
      await File(
        '${nestedDirectory.path}${Platform.pathSeparator}network.cache',
      ).writeAsBytes(List<int>.filled(2048, 2));
      await File(
        '${documentsDirectory.path}${Platform.pathSeparator}DioCache.db',
      ).writeAsBytes(List<int>.filled(512, 3));

      final result = await cacheManage.refreshApplicationCacheSize();

      expect(result, 3584);
      expect(cacheManage.cachedApplicationCacheSizeBytes, 3584);
    });

    test('missing cache paths count as empty', () async {
      await temporaryDirectory.delete();
      await documentsDirectory.delete();

      expect(await cacheManage.refreshApplicationCacheSize(), 0);
      expect(cacheManage.cachedApplicationCacheSizeBytes, 0);
    });

    test('concurrent refreshes share one scan', () async {
      final temporaryDirectoryCompleter = Completer<Directory>();
      var temporaryDirectoryRequests = 0;
      cacheManage = CacheManage(
        temporaryDirectoryProvider: () {
          temporaryDirectoryRequests++;
          return temporaryDirectoryCompleter.future;
        },
        applicationDocumentsDirectoryProvider: () async => documentsDirectory,
      );

      final firstRefresh = cacheManage.refreshApplicationCacheSize();
      final secondRefresh = cacheManage.refreshApplicationCacheSize();

      expect(temporaryDirectoryRequests, 1);
      temporaryDirectoryCompleter.complete(temporaryDirectory);
      expect(await firstRefresh, 0);
      expect(await secondRefresh, 0);
      expect(temporaryDirectoryRequests, 1);
    });

    test(
      'a scan invalidated by clearing cannot overwrite the new snapshot',
      () async {
        final staleDirectoryCompleter = Completer<Directory>();
        var temporaryDirectoryRequests = 0;
        cacheManage = CacheManage(
          temporaryDirectoryProvider: () {
            temporaryDirectoryRequests++;
            if (temporaryDirectoryRequests == 1) {
              return staleDirectoryCompleter.future;
            }
            return Future<Directory>.value(temporaryDirectory);
          },
          applicationDocumentsDirectoryProvider: () async => documentsDirectory,
        );

        final staleRefresh = cacheManage.refreshApplicationCacheSize();
        await cacheManage.clearApplicationCache();
        await File(
          '${temporaryDirectory.path}${Platform.pathSeparator}new.cache',
        ).writeAsBytes(List<int>.filled(64, 4));
        final currentRefresh = cacheManage.refreshApplicationCacheSize();
        staleDirectoryCompleter.complete(temporaryDirectory);

        expect(await staleRefresh, isNull);
        expect(await currentRefresh, 64);
        expect(cacheManage.cachedApplicationCacheSizeBytes, 64);
      },
    );

    test('refresh errors preserve the last successful snapshot', () async {
      var failDocumentsLookup = false;
      cacheManage = CacheManage(
        temporaryDirectoryProvider: () async => temporaryDirectory,
        applicationDocumentsDirectoryProvider: () {
          if (failDocumentsLookup) {
            return Future<Directory>.error(StateError('documents unavailable'));
          }
          return Future<Directory>.value(documentsDirectory);
        },
      );
      await File(
        '${temporaryDirectory.path}${Platform.pathSeparator}image.cache',
      ).writeAsBytes(List<int>.filled(32, 1));
      expect(await cacheManage.refreshApplicationCacheSize(), 32);

      failDocumentsLookup = true;

      await expectLater(
        cacheManage.refreshApplicationCacheSize(),
        throwsA(isA<StateError>()),
      );
      expect(cacheManage.cachedApplicationCacheSizeBytes, 32);
    });

    test(
      'clears counted caches but preserves cache and documents directories',
      () async {
        final nestedDirectory = Directory(
          '${temporaryDirectory.path}${Platform.pathSeparator}nested',
        );
        await nestedDirectory.create();
        await File(
          '${nestedDirectory.path}${Platform.pathSeparator}image.cache',
        ).writeAsBytes(const <int>[1, 2, 3]);
        final dioCache = File(
          '${documentsDirectory.path}${Platform.pathSeparator}DioCache.db',
        );
        final settings = File(
          '${documentsDirectory.path}${Platform.pathSeparator}settings.db',
        );
        await dioCache.writeAsBytes(const <int>[4, 5]);
        await settings.writeAsBytes(const <int>[6]);

        await cacheManage.clearApplicationCache();

        expect(await temporaryDirectory.exists(), isTrue);
        expect(await temporaryDirectory.list().isEmpty, isTrue);
        expect(await documentsDirectory.exists(), isTrue);
        expect(await dioCache.exists(), isFalse);
        expect(await settings.exists(), isTrue);
        expect(cacheManage.cachedApplicationCacheSizeBytes, isNull);
      },
    );
  });

  group('formatCacheSize', () {
    test(
      'formats binary unit boundaries without overflowing the unit list',
      () {
        expect(formatCacheSize(0), '0.00B');
        expect(formatCacheSize(1024), '1.00K');
        expect(formatCacheSize(1024 * 1024), '1.00M');
        expect(formatCacheSize(1024 * 1024 * 1024), '1.00G');
        expect(formatCacheSize(1024 * 1024 * 1024 * 1024), '1.00T');
      },
    );
  });
}

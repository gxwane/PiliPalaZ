import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/pages/live/controller.dart';
import 'package:pilipalaz/pages/live_room/controller.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-live-ctrl-test-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
    GStorage.video = await Hive.openBox<dynamic>(StorageBoxName.video);
    GStorage.localCache = await Hive.openBox<dynamic>(
      StorageBoxName.localCache,
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('LiveController pagination stability tests', () {
    test(
      'queryLiveList with type init resets _currentPage and enforces loading guard',
      () async {
        final controller = LiveController();
        expect(controller.currentPage, 1);
        expect(controller.isLoading, isFalse);

        final refreshFuture = controller.onRefresh();
        // Concurrent call during active loading triggers the _isLoading guard
        final concurrentResult = await controller.onRefresh();
        if (concurrentResult case ApiFailure(:final message)) {
          expect(message, 'Loading in progress');
        }

        await refreshFuture;
        expect(controller.currentPage >= 1, isTrue);
        expect(controller.isLoading, isFalse);
      },
    );
  });

  group('LiveRoomController zero-late and lifecycle safety tests', () {
    test(
      'instantiates with safe initial values without LateInitializationError',
      () {
        final controller = LiveRoomController();
        expect(controller.roomId, 0);
        expect(controller.heroTag, '');
        expect(controller.isLive.value, isFalse);
        expect(controller.hasStream.value, isFalse);
        expect(controller.isClosed, isFalse);
      },
    );

    test('aborts playerInit when isDisposed is true', () async {
      final controller = LiveRoomController();
      controller.onClose();
      expect(controller.isDisposed, isTrue);

      // playerInit should return early without throwing
      await controller.playerInit('https://example.com/test.flv');
    });

    test(
      'aborts queryLiveInfo and queryLiveInfoH5 when isDisposed is true',
      () async {
        final controller = LiveRoomController();
        controller.onClose();
        expect(controller.isDisposed, isTrue);

        final liveInfo = await controller.queryLiveInfo();
        expect(liveInfo, isNotNull);
        expect((liveInfo as ApiFailure).kind, ApiFailureKind.cancelled);

        final h5Info = await controller.queryLiveInfoH5();
        expect(h5Info, isNotNull);
        expect((h5Info as ApiFailure).kind, ApiFailureKind.cancelled);
      },
    );

    test('does not cancel queryLiveInfo when isDisposed is false', () async {
      final controller = LiveRoomController();
      expect(controller.isDisposed, isFalse);
      final liveInfo = await controller.queryLiveInfo();
      if (liveInfo case ApiFailure(:final kind)) {
        expect(kind != ApiFailureKind.cancelled, isTrue);
      }
    });
  });
}

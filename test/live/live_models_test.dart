import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/models/live/room_info_h5.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/storage_contract.dart';
import 'package:pilipalaz/utils/video_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz-live-test-',
    );
    Hive.init(hiveDirectory.path);
    GStorage.setting = await Hive.openBox<dynamic>(StorageBoxName.setting);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('RoomInfoH5Model deserialization tests', () {
    test('parses live_status correctly from modern API payload', () {
      final json = {
        'room_info': {'room_id': 12345, 'title': 'Test Room', 'live_status': 1},
        'anchor_info': null,
      };

      final model = RoomInfoH5Model.fromJson(json);
      expect(model.roomInfo?.roomId, 12345);
      expect(model.roomInfo?.liveStatus, 1);
    });

    test('parses live_status from legacy liveS_satus payload if present', () {
      final json = {
        'room_info': {'room_id': 12345, 'title': 'Test Room', 'liveS_satus': 2},
      };

      final model = RoomInfoH5Model.fromJson(json);
      expect(model.roomInfo?.liveStatus, 2);
    });

    test('handles missing or null anchor_info safely', () {
      final json = {
        'room_info': {'room_id': 999},
      };

      final model = RoomInfoH5Model.fromJson(json);
      expect(model.roomInfo?.roomId, 999);
      expect(model.anchorInfo, isNull);
    });
  });

  group('RoomInfoModel null-safety tests', () {
    test('handles null playurl_info without throwing', () {
      final json = {
        'room_id': 1001,
        'live_status': 0,
        'live_time': 0,
        'playurl_info': null,
      };

      final model = RoomInfoModel.fromJson(json);
      expect(model.roomId, 1001);
      expect(model.liveStatus, 0);
      expect(model.playurlInfo, isNull);
    });

    test('handles empty streams or codecs safely', () {
      final json = {
        'room_id': 1002,
        'live_status': 1,
        'playurl_info': {
          'playurl': {'cid': 1002, 'g_qn_desc': [], 'stream': []},
        },
      };

      final model = RoomInfoModel.fromJson(json);
      expect(model.playurlInfo?.playurl?.stream, isEmpty);
      expect(model.playurlInfo?.playurl?.gQnDesc, isEmpty);
    });

    test('converts hdr_qn int or string safely in CodecItem', () {
      final json = {'codec_name': 'avc', 'current_qn': 10000, 'hdr_n': 1};

      final codec = CodecItem.fromJson(json);
      expect(codec.codecName, 'avc');
      expect(codec.hdrQn, '1');
    });
  });

  group('VideoUtils.getCdnUrl for live CodecItem tests', () {
    test('returns full URL when CodecItem has valid urlInfo', () {
      final codec = CodecItem(
        baseUrl: '/live-bvc/test.flv',
        urlInfo: [
          UrlInfoItem(
            host: 'https://d1.live.bilivideo.com',
            extra: '?token=xyz',
          ),
        ],
      );

      final url = VideoUtils.getCdnUrl(codec);
      expect(url, 'https://d1.live.bilivideo.com/live-bvc/test.flv?token=xyz');
    });

    test(
      'returns empty string when urlInfo is null or empty without throwing',
      () {
        final codecEmpty = CodecItem(
          baseUrl: '/live-bvc/test.flv',
          urlInfo: [],
        );

        final urlEmpty = VideoUtils.getCdnUrl(codecEmpty);
        expect(urlEmpty, '');

        final codecNull = CodecItem(
          baseUrl: '/live-bvc/test.flv',
          urlInfo: null,
        );

        final urlNull = VideoUtils.getCdnUrl(codecNull);
        expect(urlNull, '');
      },
    );
  });
}

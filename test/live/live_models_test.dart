import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/live/item.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/models/live/room_info_h5.dart';
import 'package:pilipalaz/models/member/info.dart';
import 'package:pilipalaz/models/search/result.dart';
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

  group('LiveItemModel.fromDynamic polymorphic tests', () {
    test('returns same instance when already LiveItemModel', () {
      final origin = LiveItemModel(roomId: 10001, uname: 'Streamer');
      final result = LiveItemModel.fromDynamic(origin);
      expect(identical(result, origin), isTrue);
    });

    test('deconstructs SearchLiveItemModel safely with flattened title', () {
      final searchItem = SearchLiveItemModel(
        roomid: 20002,
        uid: 9999,
        uname: 'UpName',
        uface: 'https://example.com/face.png',
        userCover: 'https://example.com/cover.png',
        cateName: '单机游戏',
        online: 12345,
        title: [
          {'type': 'text', 'text': '我的'},
          {'type': 'em', 'text': '世界'},
          ' 直播间',
        ],
      );

      final model = LiveItemModel.fromDynamic(searchItem);
      expect(model, isNotNull);
      expect(model!.roomId, 20002);
      expect(model.uid, 9999);
      expect(model.uname, 'UpName');
      expect(model.face, 'https://example.com/face.png');
      expect(model.cover, 'https://example.com/cover.png');
      expect(model.areaName, '单机游戏');
      expect(model.online, 12345);
      expect(model.title, '我的世界 直播间');
      expect(model.liveStatus, 1);
    });

    test('parses Map and Map<String, dynamic> safely', () {
      final map = {
        'roomid': 30003,
        'uname': 'MapUser',
        'title': 'Map Title',
        'live_status': 1,
      };
      final model = LiveItemModel.fromDynamic(map);
      expect(model, isNotNull);
      expect(model!.roomId, 30003);
      expect(model.uname, 'MapUser');
      expect(model.title, 'Map Title');
    });

    test('parses arbitrary dynamic object with duck typing', () {
      final duck = _MockLiveSeed(
        roomId: 40004,
        uname: 'DuckUser',
        title: 'Duck Title',
        cover: 'https://example.com/duck.jpg',
      );
      final model = LiveItemModel.fromDynamic(duck);
      expect(model, isNotNull);
      expect(model!.roomId, 40004);
      expect(model.uname, 'DuckUser');
      expect(model.cover, 'https://example.com/duck.jpg');
    });

    test('returns null for null, empty or invalid input', () {
      expect(LiveItemModel.fromDynamic(null), isNull);
      expect(LiveItemModel.fromDynamic('random string'), isNull);
      expect(LiveItemModel.fromDynamic(12345), isNull);
    });
  });

  group('MemberInfoModel and LiveRoom tolerant deserialization tests', () {
    test('parses modern snake_case live_room payload correctly', () {
      final json = {
        'card': {'mid': '1001', 'name': 'Up1', 'face': 'http://face.jpg'},
        'live_room': {
          'room_status': 1,
          'live_status': 1,
          'url': 'https://live.bilibili.com/555',
          'title': 'Living Now',
          'cover': 'http://live_cover.jpg',
          'room_id': 555,
          'round_status': 0,
        },
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.card?.name, 'Up1');
      expect(info.liveRoom, isNotNull);
      expect(info.liveRoom!.liveStatus, 1);
      expect(info.liveRoom!.roomId, 555);
      expect(info.liveRoom!.title, 'Living Now');
    });

    test('parses legacy camelCase live payload correctly', () {
      final json = {
        'card': {'mid': '1002', 'name': 'Up2', 'face': 'http://face2.jpg'},
        'live': {
          'roomStatus': 1,
          'liveStatus': 1,
          'title': 'Legacy Live',
          'roomid': 777,
        },
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.liveRoom, isNotNull);
      expect(info.liveRoom!.liveStatus, 1);
      expect(info.liveRoom!.roomId, 777);
      expect(info.liveRoom!.title, 'Legacy Live');
    });

    test('parses card nested live_room payload correctly', () {
      final json = {
        'card': {
          'mid': '1003',
          'name': 'Up3',
          'live_room': {'live_status': '1', 'room_id': '888'},
        },
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.liveRoom, isNotNull);
      expect(info.liveRoom!.liveStatus, 1);
      expect(info.liveRoom!.roomId, 888);
    });

    test('handles missing liveRoom or offline主播 gracefully', () {
      final json = {
        'card': {'mid': '1004', 'name': 'Up4'},
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.card?.name, 'Up4');
      expect(info.liveRoom, isNull);
    });
  });
}

class _MockLiveSeed {
  final int roomId;
  final String uname;
  final String title;
  final String cover;
  _MockLiveSeed({
    required this.roomId,
    required this.uname,
    required this.title,
    required this.cover,
  });
}

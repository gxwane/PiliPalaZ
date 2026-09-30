import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/live/room_info.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/video_utils.dart';

void main() {
  group('VideoUtils.getLiveCdnUrl Tests', () {
    final mockCodec = CodecItem(
      codecName: 'avc',
      currentQn: 10000,
      baseUrl: '/live-bvc/test/index.m3u8?',
      urlInfo: [
        UrlInfoItem(
          host: 'https://line1.bilivideo.com',
          extra: 'token=aaa&order=1',
        ),
        UrlInfoItem(
          host: 'https://line2.bilivideo.com',
          extra: 'token=bbb&order=2',
        ),
      ],
    );

    test('extracts line 0 by default', () {
      final url = VideoUtils.getLiveCdnUrl(mockCodec);
      expect(
        url,
        'https://line1.bilivideo.com/live-bvc/test/index.m3u8?token=aaa&order=1',
      );
    });

    test('extracts line 1 when specified', () {
      final url = VideoUtils.getLiveCdnUrl(mockCodec, lineIndex: 1);
      expect(
        url,
        'https://line2.bilivideo.com/live-bvc/test/index.m3u8?token=bbb&order=2',
      );
    });

    test('safely clamps out-of-bounds line index to 0', () {
      final urlNegative = VideoUtils.getLiveCdnUrl(mockCodec, lineIndex: -1);
      expect(
        urlNegative,
        'https://line1.bilivideo.com/live-bvc/test/index.m3u8?token=aaa&order=1',
      );

      final urlTooHigh = VideoUtils.getLiveCdnUrl(mockCodec, lineIndex: 99);
      expect(
        urlTooHigh,
        'https://line1.bilivideo.com/live-bvc/test/index.m3u8?token=aaa&order=1',
      );
    });

    test('handles null item safely', () {
      final url = VideoUtils.getLiveCdnUrl(null);
      expect(url, '');
    });

    test('handles empty urlInfo safely', () {
      final emptyCodec = CodecItem(
        codecName: 'avc',
        baseUrl: '/test',
        urlInfo: [],
      );
      final url = VideoUtils.getLiveCdnUrl(emptyCodec);
      expect(url, '');
    });

    test('handles empty host safely', () {
      final noHostCodec = CodecItem(
        codecName: 'avc',
        baseUrl: '/test',
        urlInfo: [UrlInfoItem(host: '', extra: '')],
      );
      final url = VideoUtils.getLiveCdnUrl(noHostCodec);
      expect(url, '');
    });

    test('VideoUtils.getCdnUrl delegates to getLiveCdnUrl for CodecItem', () {
      final url = VideoUtils.getCdnUrl(mockCodec);
      expect(
        url,
        'https://line1.bilivideo.com/live-bvc/test/index.m3u8?token=aaa&order=1',
      );
    });
  });

  group('Live Room Quality & Stream parsing logic', () {
    final mockRoomJson = <String, dynamic>{
      'room_id': 452138,
      'live_status': 1,
      'playurl_info': {
        'playurl': {
          'g_qn_desc': [
            {'qn': 10000, 'desc': '原画'},
            {'qn': 400, 'desc': '蓝光'},
            {'qn': 250, 'desc': '超清'},
            {'qn': 150, 'desc': '高清'},
          ],
          'stream': [
            {
              'protocol_name': 'http_stream',
              'format': [
                {
                  'format_name': 'flv',
                  'codec': [
                    {
                      'codec_name': 'avc',
                      'current_qn': 10000,
                      'accept_qn': [10000, 400, 250, 150],
                      'base_url': '/live/stream_avc.flv?',
                      'url_info': [
                        {'host': 'https://cdn-flv-1.com', 'extra': 'key=1'},
                        {'host': 'https://cdn-flv-2.com', 'extra': 'key=2'},
                      ],
                    },
                    {
                      'codec_name': 'hevc',
                      'current_qn': 10000,
                      'accept_qn': [10000, 400, 250, 150],
                      'base_url': '/live/stream_hevc.flv?',
                      'url_info': [
                        {'host': 'https://cdn-hevc-1.com', 'extra': 'key=3'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    };

    test('parses multi-quality and multi-codec correctly', () {
      final roomModel = RoomInfoModel.fromJson(mockRoomJson);
      expect(roomModel.roomId, 452138);
      expect(roomModel.liveStatus, 1);

      final playurl = roomModel.playurlInfo?.playurl;
      expect(playurl, isNotNull);
      expect(playurl!.gQnDesc?.length, 4);
      expect(playurl.gQnDesc?[0].desc, '原画');
      expect(playurl.gQnDesc?[1].desc, '蓝光');

      final stream = playurl.stream?.first;
      expect(stream?.protocolName, 'http_stream');
      final format = stream?.format?.first;
      expect(format?.formatName, 'flv');
      expect(format?.codec?.length, 2);

      final avcCodec = format?.codec?[0];
      expect(avcCodec?.codecName, 'avc');
      expect(avcCodec?.urlInfo?.length, 2);

      final line1Url = VideoUtils.getLiveCdnUrl(avcCodec, lineIndex: 0);
      expect(line1Url, 'https://cdn-flv-1.com/live/stream_avc.flv?key=1');

      final line2Url = VideoUtils.getLiveCdnUrl(avcCodec, lineIndex: 1);
      expect(line2Url, 'https://cdn-flv-2.com/live/stream_avc.flv?key=2');

      final hevcCodec = format?.codec?[1];
      expect(hevcCodec?.codecName, 'hevc');
      final hevcUrl = VideoUtils.getLiveCdnUrl(hevcCodec, lineIndex: 0);
      expect(hevcUrl, 'https://cdn-hevc-1.com/live/stream_hevc.flv?key=3');
    });

    test('SettingBoxKey.defaultLiveQa key is correctly defined', () {
      expect(SettingBoxKey.defaultLiveQa, 'defaultLiveQa');
    });

    test('Codec list generation and line count calculation', () {
      final roomModel = RoomInfoModel.fromJson(mockRoomJson);
      final codecs =
          roomModel.playurlInfo?.playurl?.stream?.first.format?.first.codec ??
          [];
      final codecNames = codecs
          .map((c) => c.codecName?.toLowerCase() ?? '')
          .toList();
      expect(codecNames, containsAll(['avc', 'hevc']));

      final avc = codecs.firstWhere((c) => c.codecName == 'avc');
      final lines = List.generate(
        avc.urlInfo?.length ?? 0,
        (i) => '线路 ${i + 1}',
      );
      expect(lines.length, 2);
      expect(lines[0], '线路 1');
      expect(lines[1], '线路 2');
    });

    group('BDD Quality Filtering & Codec Downgrade Tests', () {
      final allMockQualities = [
        GQnDesc(qn: 30000, desc: '杜比'),
        GQnDesc(qn: 20000, desc: '4K'),
        GQnDesc(qn: 10000, desc: '原画'),
        GQnDesc(qn: 400, desc: '蓝光'),
        GQnDesc(qn: 250, desc: '超清'),
        GQnDesc(qn: 150, desc: '高清'),
      ];

      test(
        'Scenario 1: filters out 4K/Dolby and sorts descending by accept_qn',
        () {
          final filtered = VideoUtils.filterAndSortQualities(
            allQualities: allMockQualities,
            acceptQn: [10000, 400, 250],
          );
          expect(filtered.map((e) => e.qn).toList(), [10000, 400, 250]);
          expect(filtered.map((e) => e.desc).toList(), ['原画', '蓝光', '超清']);
        },
      );

      test('Scenario 2: parses dirty accept_qn data safely', () {
        final parsed = VideoUtils.parseAcceptQn([
          '10000',
          400,
          250.0,
          null,
          'invalid',
          -5,
        ]);
        expect(parsed, {10000, 400, 250});
      });

      test('Scenario 3: safe fallback when accept_qn is null or empty', () {
        final nullFallback = VideoUtils.filterAndSortQualities(
          allQualities: allMockQualities,
          acceptQn: null,
        );
        expect(nullFallback.length, 6);
        expect(nullFallback.first.qn, 30000);

        final emptyFallback = VideoUtils.filterAndSortQualities(
          allQualities: allMockQualities,
          acceptQn: [],
        );
        expect(emptyFallback.length, 6);
      });

      test('Scenario 4: safe fallback when intersection is empty', () {
        final fallback = VideoUtils.filterAndSortQualities(
          allQualities: allMockQualities,
          acceptQn: [99999],
        );
        expect(fallback.length, 6);
      });

      test('Scenario 5: retains currentQn when supported by target codec', () {
        final resolved = VideoUtils.resolveSupportedQn(
          acceptQn: [10000, 400, 250],
          currentQn: 400,
        );
        expect(resolved, 400);
      });

      test('Scenario 6: gracefully downgrades to highest supported Qn', () {
        final resolved = VideoUtils.resolveSupportedQn(
          acceptQn: [400, 250],
          currentQn: 10000,
        );
        expect(resolved, 400);
      });
    });
  });
}

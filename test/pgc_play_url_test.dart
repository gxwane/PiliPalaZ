import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/video/play/url.dart';

void main() {
  test('parses a playable PGC preview response', () {
    final PlayUrlModel model = PlayUrlModel.fromJson(<String, dynamic>{
      'quality': 16,
      'timelength': 7200000,
      'accept_quality': <int>[16],
      'accept_description': <String>['试看'],
      'is_preview': 1,
      'error_code': -10403,
      'is_drm': false,
      'durl': <Map<String, dynamic>>[
        <String, dynamic>{
          'order': 1,
          'length': 360000,
          'url': 'https://example.com/preview.mp4',
        },
      ],
    });

    expect(model.isPreview, isTrue);
    expect(model.errorCode, -10403);
    expect(model.isDrm, isFalse);
    expect(model.playableDuration, const Duration(minutes: 6));
  });

  test('parses snake_case DASH fields returned by the PGC endpoint', () {
    final PlayUrlModel model = PlayUrlModel.fromJson(<String, dynamic>{
      'quality': 80,
      'accept_quality': <int>[80],
      'dash': <String, dynamic>{
        'duration': 120,
        'min_buffer_time': 1.5,
        'video': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 80,
            'base_url': 'https://example.com/video.m4s',
            'backup_url': <String>[],
            'bandwidth': 1000,
            'mime_type': 'video/mp4',
            'codecs': 'avc1.640028',
            'width': 1920,
            'height': 1080,
            'frame_rate': '30',
            'start_with_sap': 1,
            'segment_base': <String, dynamic>{},
          },
        ],
        'audio': <Map<String, dynamic>>[],
      },
    });

    expect(model.dash!.minBufferTime, 1.5);
    expect(model.dash!.video!.single.baseUrl, contains('video.m4s'));
    expect(model.dash!.video!.single.bandWidth, 1000);
  });

  test('gives clear restriction messages without suggesting a bypass', () {
    expect(PgcPlaybackRestriction.messageFor(isDrm: true), contains('DRM'));
    expect(
      PgcPlaybackRestriction.messageFor(errorCode: -10403),
      contains('大会员或购买'),
    );
    expect(
      PgcPlaybackRestriction.messageFor(message: '抱歉您所在地区不可观看'),
      contains('当前地区'),
    );
  });
}

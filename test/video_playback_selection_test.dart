import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/video/play/quality.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/pages/video/video_playback_selection.dart';

void main() {
  group('HardwareAlternativeRecoveryGuard', () {
    test('allows one source replacement attempt until explicitly reset', () {
      final HardwareAlternativeRecoveryGuard guard =
          HardwareAlternativeRecoveryGuard();

      expect(guard.tryBegin(), isTrue);
      expect(guard.tryBegin(), isFalse);

      guard.reset();

      expect(guard.tryBegin(), isTrue);
    });
  });

  group('hasSelectableDashVideo', () {
    test('does not expose stale DASH controls for a DURL preview', () {
      expect(
        hasSelectableDashVideo(
          PlayUrlModel.fromJson(<String, dynamic>{
            'quality': VideoQuality.fluent360.code,
            'durl': <Map<String, dynamic>>[
              <String, dynamic>{
                'url': 'https://example.com/preview.mp4',
                'length': 60000,
              },
            ],
          }),
        ),
        isFalse,
      );
    });

    test('exposes controls only for the current non-empty DASH response', () {
      expect(
        hasSelectableDashVideo(
          PlayUrlModel(
            dash: Dash(
              video: <VideoItem>[
                _video(
                  quality: VideoQuality.high1080,
                  codec: 'avc1.640032',
                  width: 1920,
                  height: 1080,
                  url: 'https://example.com/video.m4s',
                ),
              ],
            ),
          ),
        ),
        isTrue,
      );
    });
  });

  group('selectPreferredVideoQualityCode', () {
    test('keeps HDR out of an implicit highest-quality fallback', () {
      expect(
        selectPreferredVideoQualityCode(
          preferredCode: VideoQuality.super8k.code,
          availableCodes: <int>[
            VideoQuality.hdr.code,
            VideoQuality.super4K.code,
            VideoQuality.high1080.code,
          ],
        ),
        VideoQuality.super4K.code,
      );
    });

    test('honors an explicitly selected HDR representation', () {
      expect(
        selectPreferredVideoQualityCode(
          preferredCode: VideoQuality.hdr.code,
          availableCodes: <int>[
            VideoQuality.hdr.code,
            VideoQuality.super4K.code,
          ],
        ),
        VideoQuality.hdr.code,
      );
    });

    test('falls back to standard SDR when explicit HDR is unavailable', () {
      expect(
        selectPreferredVideoQualityCode(
          preferredCode: VideoQuality.hdr.code,
          availableCodes: <int>[
            VideoQuality.super4K.code,
            VideoQuality.high1080.code,
          ],
        ),
        VideoQuality.super4K.code,
      );
    });

    test(
      'keeps content playable when only a special representation exists',
      () {
        expect(
          selectPreferredVideoQualityCode(
            preferredCode: VideoQuality.super8k.code,
            availableCodes: <int>[VideoQuality.hdr.code],
          ),
          VideoQuality.hdr.code,
        );
      },
    );
  });

  group('selectCompatibleFallbackVideo', () {
    test('prefers same-resolution AVC after a 1080p HEVC failure', () {
      final VideoItem current = _video(
        quality: VideoQuality.hdr,
        codec: 'hvc1.2.4.L120.90',
        width: 1920,
        height: 1080,
        url: 'https://example.com/hdr-hevc.m4s',
      );
      final VideoItem avc = _video(
        quality: VideoQuality.high1080,
        codec: 'avc1.640032',
        width: 1920,
        height: 1080,
        url: 'https://example.com/1080-avc.m4s',
      );
      final VideoItem lowerAvc = _video(
        quality: VideoQuality.high720,
        codec: 'avc1.64001f',
        width: 1280,
        height: 720,
        url: 'https://example.com/720-avc.m4s',
      );

      expect(
        selectCompatibleFallbackVideo(
          current: current,
          candidates: <VideoItem>[lowerAvc, current, avc],
        ),
        same(avc),
      );
    });

    test('prefers AVC over HEVC among equal-resolution candidates', () {
      final VideoItem current = _video(
        quality: VideoQuality.super4K,
        codec: 'hev1.2.4.L153.B0',
        width: 3840,
        height: 2160,
        url: 'https://example.com/4k-hevc.m4s',
      );
      final VideoItem hevc = _video(
        quality: VideoQuality.super4K,
        codec: 'hvc1.1.6.L153.B0',
        width: 3840,
        height: 2160,
        url: 'https://example.com/4k-hevc-main.m4s',
      );
      final VideoItem avc = _video(
        quality: VideoQuality.super4K,
        codec: 'avc1.640033',
        width: 3840,
        height: 2160,
        url: 'https://example.com/4k-avc.m4s',
      );

      expect(
        selectCompatibleFallbackVideo(
          current: current,
          candidates: <VideoItem>[hevc, avc],
        ),
        same(avc),
      );
    });

    test('never promotes recovery above the failed source resolution', () {
      final VideoItem current = _video(
        quality: VideoQuality.high1080,
        codec: 'hev1.1.6.L120.90',
        width: 1920,
        height: 1080,
        url: 'https://example.com/1080-hevc.m4s',
      );
      final VideoItem fourKAvc = _video(
        quality: VideoQuality.super4K,
        codec: 'avc1.640033',
        width: 3840,
        height: 2160,
        url: 'https://example.com/4k-avc.m4s',
      );

      expect(
        selectCompatibleFallbackVideo(
          current: current,
          candidates: <VideoItem>[fourKAvc],
        ),
        isNull,
      );
    });

    test('uses the quality ladder when dimensions are unavailable', () {
      final VideoItem current = VideoItem(
        id: VideoQuality.high1080.code,
        quality: VideoQuality.high1080,
        codecs: 'hev1.1.6.L120.90',
        baseUrl: 'https://example.com/1080-hevc.m4s',
      );
      final VideoItem fourKAvc = VideoItem(
        id: VideoQuality.super4K.code,
        quality: VideoQuality.super4K,
        codecs: 'avc1.640033',
        baseUrl: 'https://example.com/4k-avc.m4s',
      );
      final VideoItem sevenTwentyAvc = VideoItem(
        id: VideoQuality.high720.code,
        quality: VideoQuality.high720,
        codecs: 'avc1.64001f',
        baseUrl: 'https://example.com/720-avc.m4s',
      );

      expect(
        selectCompatibleFallbackVideo(
          current: current,
          candidates: <VideoItem>[fourKAvc, sevenTwentyAvc],
        ),
        same(sevenTwentyAvc),
      );
    });

    test('does not automatically recover to HDR or Dolby Vision', () {
      final VideoItem current = _video(
        quality: VideoQuality.high1080,
        codec: 'av01.0.08M.08',
        width: 1920,
        height: 1080,
        url: 'https://example.com/1080-av1.m4s',
      );
      final VideoItem hdr = _video(
        quality: VideoQuality.hdr,
        codec: 'hvc1.2.4.L120.90',
        width: 1920,
        height: 1080,
        url: 'https://example.com/hdr.m4s',
      );

      expect(
        selectCompatibleFallbackVideo(
          current: current,
          candidates: <VideoItem>[hdr],
        ),
        isNull,
      );
    });
  });

  group('VideoDecodeFormatsCode', () {
    test('recognizes HEVC sample entry aliases', () {
      expect(
        VideoDecodeFormatsCode.fromString('hvc1.2.4.L120.90'),
        VideoDecodeFormats.HEVC,
      );
      expect(
        VideoDecodeFormatsCode.fromString('hev1.1.6.L120.90'),
        VideoDecodeFormats.HEVC,
      );
    });

    test('recognizes Dolby Vision aliases', () {
      expect(
        VideoDecodeFormatsCode.fromString('dvh1.08.07'),
        VideoDecodeFormats.DVH1,
      );
      expect(
        VideoDecodeFormatsCode.fromString('dvhe.08.07'),
        VideoDecodeFormats.DVH1,
      );
    });

    test('does not silently classify an unknown codec as Dolby Vision', () {
      expect(VideoDecodeFormatsCode.fromString('vp09.00.10.08'), isNull);
      expect(describeVideoCodec('vp09.00.10.08'), 'VP09');
    });
  });
}

VideoItem _video({
  required VideoQuality quality,
  required String codec,
  required int width,
  required int height,
  required String url,
}) {
  return VideoItem(
    id: quality.code,
    quality: quality,
    codecs: codec,
    width: width,
    height: height,
    baseUrl: url,
  );
}

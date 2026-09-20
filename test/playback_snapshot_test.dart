import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/diagnostics/playback_snapshot.dart';
import 'package:pilipalaz/models/video/play/url.dart';

void main() {
  group('PlaybackSnapshot Model Tests', () {
    test('computes formatted duration and buffer percentage correctly', () {
      const snapshot = PlaybackSnapshot(
        engineName: 'Media3 (ExoPlayer)',
        rendererType: 'Flutter Texture (SurfaceTexture)',
        hwdec: 'MediaCodec (硬解优先/软解回退)',
        audioOutput: 'AudioTrack',
        videoQuality: '高清 1080P',
        videoCodec: 'AVC (avc1.640033)',
        resolution: '1920x1080',
        frameRate: '30 fps',
        videoBitrate: '2500.0 kbps',
        audioQuality: '高码率 192K',
        audioCodec: 'mp4a.40.2',
        audioBitrate: '192.0 kbps',
        position: Duration(minutes: 1, seconds: 15),
        duration: Duration(minutes: 5, seconds: 0),
        bufferedPosition: Duration(minutes: 2, seconds: 30),
        playbackSpeed: 1.25,
        playbackState: '播放中',
        bvid: 'BV1xx411c7mD',
        cid: 123456,
        cdnHost: 'upos-sz-mirrorcosov.bilivideo.com',
        sourceType: '投稿视频 (UGC)',
      );

      expect(snapshot.formattedPosition, '01:15');
      expect(snapshot.formattedDuration, '05:00');
      expect(snapshot.formattedBuffered, '02:30');
      expect(snapshot.bufferPercent, 50);

      final markdown = snapshot.toMarkdown();
      expect(markdown, contains('### PiliPalaZ 播放统计与排障信息'));
      expect(markdown, contains('Media3 (ExoPlayer)'));
      expect(markdown, contains('SurfaceTexture'));
      expect(markdown, contains('高清 1080P (1920x1080 @ 30 fps)'));
      expect(markdown, contains('AVC (avc1.640033)'));
      expect(markdown, contains('高码率 192K'));
      expect(markdown, contains('01:15 / 05:00'));
      expect(markdown, contains('02:30 (50%)'));
      expect(markdown, contains('1.3x'));
      expect(markdown, contains('BV1xx411c7mD'));
      expect(markdown, contains('upos-sz-mirrorcosov.bilivideo.com'));
      expect(markdown, isNot(contains('?token=')));
    });

    test('handles hours duration and zero duration gracefully', () {
      const zeroSnapshot = PlaybackSnapshot(
        engineName: 'MPV (media_kit)',
        rendererType: 'Flutter Texture',
        hwdec: '关闭',
        audioOutput: 'AudioTrack (AAudio)',
        videoQuality: '未知',
        videoCodec: '未知',
        resolution: '未知',
        frameRate: '未知',
        videoBitrate: '未知',
        audioQuality: '无独立音频',
        audioCodec: '未知',
        audioBitrate: '未知',
        position: Duration(hours: 1, minutes: 2, seconds: 3),
        duration: Duration.zero,
        bufferedPosition: Duration.zero,
        playbackSpeed: 1.0,
        playbackState: '未就绪',
        bvid: '',
        cid: 0,
        cdnHost: '未知',
        sourceType: '投稿视频 (UGC)',
      );

      expect(zeroSnapshot.formattedPosition, '01:02:03');
      expect(zeroSnapshot.formattedDuration, '00:00');
      expect(zeroSnapshot.bufferPercent, 0);

      final markdown = zeroSnapshot.toMarkdown();
      expect(markdown, contains('01:02:03 / 00:00'));
      expect(markdown, contains('MPV (media_kit)'));
    });

    test(
      'AudioItem.fromJson safely handles known and unknown audio quality IDs',
      () {
        final item192k = AudioItem.fromJson(<String, dynamic>{
          'id': 30280,
          'bandwidth': 192000,
          'codecs': 'mp4a.40.2',
          'baseUrl': 'https://example.com/audio.m4s',
        });
        expect(item192k.quality, '192K');
        expect(item192k.codecs, 'mp4a.40.2');
        expect(item192k.bandWidth, 192000);

        final itemDolby = AudioItem.fromJson(<String, dynamic>{
          'id': 30250,
          'bandwidth': 320000,
          'codecs': 'ec-3',
        });
        expect(itemDolby.quality, '杜比全景声');

        final itemHiRes = AudioItem.fromJson(<String, dynamic>{
          'id': 30251,
          'codecs': 'fLaC',
        });
        expect(itemHiRes.quality, 'Hi-Res无损');

        // Unknown ID must not throw StateError and fallback gracefully
        final itemUnknown = AudioItem.fromJson(<String, dynamic>{
          'id': 999999,
          'codecs': 'opus',
        });
        expect(itemUnknown.quality, '未知');
        expect(itemUnknown.codecs, 'opus');
      },
    );
  });
}

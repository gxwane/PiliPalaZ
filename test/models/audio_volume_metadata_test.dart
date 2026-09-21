import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/video/play/url.dart';

void main() {
  group('AudioVolumeMetadata', () {
    test('parses standard float values correctly', () {
      final json = <String, dynamic>{
        'measured_i': -14.2,
        'measured_lra': 10.5,
        'measured_tp': -1.2,
        'measured_threshold': -24.5,
        'target_offset': -0.8,
        'target_i': -14.0,
        'target_tp': -1.0,
      };

      final meta = AudioVolumeMetadata.fromJson(json);
      expect(meta, isNotNull);
      expect(meta!.measuredI, -14.2);
      expect(meta.measuredLra, 10.5);
      expect(meta.measuredTp, -1.2);
      expect(meta.measuredThreshold, -24.5);
      expect(meta.targetOffset, -0.8);
      expect(meta.targetI, -14.0);
      expect(meta.targetTp, -1.0);
    });

    test('safely parses integer numbers without type cast exception', () {
      final json = <String, dynamic>{
        'measured_i': -15,
        'measured_lra': 8,
        'measured_tp': 3,
        'measured_threshold': -25,
        'target_offset': 2,
        'target_i': -14,
        'target_tp': -1,
      };

      final meta = AudioVolumeMetadata.fromJson(json);
      expect(meta, isNotNull);
      expect(meta!.measuredI, -15.0);
      expect(meta.measuredLra, 8.0);
      expect(meta.measuredTp, 3.0);
      expect(meta.measuredThreshold, -25.0);
      expect(meta.targetOffset, 2.0);
      expect(meta.targetI, -14.0);
      expect(meta.targetTp, -1.0);
    });

    test('handles null json safely', () {
      expect(AudioVolumeMetadata.fromJson(null), isNull);
    });

    test('serializes to json matching properties', () {
      const meta = AudioVolumeMetadata(
        measuredI: -16.0,
        measuredLra: 7.0,
        measuredTp: -0.5,
        measuredThreshold: -26.0,
        targetOffset: -1.5,
        targetI: -14.0,
        targetTp: -1.0,
      );

      final json = meta.toJson();
      expect(json['measured_i'], -16.0);
      expect(json['target_offset'], -1.5);
      expect(json['target_i'], -14.0);
    });

    test('PlayUrlModel parses top-level volume field', () {
      final playUrlJson = <String, dynamic>{
        'from': 'local',
        'result': 'suee',
        'quality': 80,
        'timelength': 120000,
        'volume': <String, dynamic>{
          'measured_i': -13.4,
          'target_offset': -1.3,
          'target_i': -14.0,
          'target_tp': -1.0,
        },
      };

      final playUrl = PlayUrlModel.fromJson(playUrlJson);
      expect(playUrl.volume, isNotNull);
      expect(playUrl.volume!.measuredI, -13.4);
      expect(playUrl.volume!.targetOffset, -1.3);
      expect(playUrl.volume!.targetI, -14.0);
    });

    test('PlayUrlModel handles missing volume gracefully', () {
      final playUrlJson = <String, dynamic>{
        'from': 'local',
        'result': 'suee',
        'quality': 80,
      };

      final playUrl = PlayUrlModel.fromJson(playUrlJson);
      expect(playUrl.volume, isNull);
    });
  });
}

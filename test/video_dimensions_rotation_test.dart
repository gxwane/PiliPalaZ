import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/src/utils/dimensions.dart';

void main() {
  group('computeRotatedDimensions', () {
    test(
      'preserves dimensions when rotate is null (uninitialized metadata)',
      () {
        final VideoDimension dimension = computeRotatedDimensions(
          rawWidth: 1920,
          rawHeight: 1080,
          rotate: null,
        );
        expect(dimension.width, 1920);
        expect(dimension.height, 1080);
        expect(dimension, const VideoDimension(1920, 1080));
      },
    );

    test('preserves dimensions when rotate is 0 degrees', () {
      final VideoDimension dimension = computeRotatedDimensions(
        rawWidth: 1920,
        rawHeight: 1080,
        rotate: 0,
      );
      expect(dimension.width, 1920);
      expect(dimension.height, 1080);
    });

    test('preserves dimensions when rotate is 180 degrees', () {
      final VideoDimension dimension = computeRotatedDimensions(
        rawWidth: 1280,
        rawHeight: 720,
        rotate: 180,
      );
      expect(dimension.width, 1280);
      expect(dimension.height, 720);
    });

    test('swaps dimensions when rotate is 90 degrees', () {
      final VideoDimension dimension = computeRotatedDimensions(
        rawWidth: 1920,
        rawHeight: 1080,
        rotate: 90,
      );
      expect(dimension.width, 1080);
      expect(dimension.height, 1920);
    });

    test('swaps dimensions when rotate is 270 degrees', () {
      final VideoDimension dimension = computeRotatedDimensions(
        rawWidth: 1920,
        rawHeight: 1080,
        rotate: 270,
      );
      expect(dimension.width, 1080);
      expect(dimension.height, 1920);
    });

    test('handles portrait input with 90 degrees rotation correctly', () {
      final VideoDimension dimension = computeRotatedDimensions(
        rawWidth: 1080,
        rawHeight: 1920,
        rotate: 90,
      );
      expect(dimension.width, 1920);
      expect(dimension.height, 1080);
    });

    test('handles unexpected rotation angles without unwarranted swapping', () {
      for (final int? angle in <int?>[null, 0, 180, 360, 45, -90]) {
        if (angle == 90 || angle == 270) continue;
        final VideoDimension dimension = computeRotatedDimensions(
          rawWidth: 1920,
          rawHeight: 1080,
          rotate: angle,
        );
        expect(
          dimension.width,
          1920,
          reason: 'Expected width to remain 1920 for angle $angle',
        );
        expect(
          dimension.height,
          1080,
          reason: 'Expected height to remain 1080 for angle $angle',
        );
      }
    });

    test('VideoDimension value equality and string formatting', () {
      const VideoDimension d1 = VideoDimension(1920, 1080);
      const VideoDimension d2 = VideoDimension(1920, 1080);
      const VideoDimension d3 = VideoDimension(1080, 1920);

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1, isNot(equals(d3)));
      expect(d1.toString(), 'VideoDimension(1920, 1080)');
    });
  });
}

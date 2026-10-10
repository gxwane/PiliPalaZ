import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/pages/dynamics/widgets/nine_grid_gallery.dart';

void main() {
  group('GalleryMediaItem Tests', () {
    test('from parses plain String URL correctly', () {
      final item = GalleryMediaItem.from('https://example.com/pic.jpg');
      expect(item.url, equals('https://example.com/pic.jpg'));
      expect(item.width, isNull);
      expect(item.height, isNull);
      expect(item.aspectRatio, isNull);
      expect(item.isLongImage, isFalse);
    });

    test('from parses OpusPicsModel correctly', () {
      final opus = OpusPicsModel(
        url: 'https://example.com/opus.png',
        width: 1080,
        height: 2400,
        size: 500000,
      );
      final item = GalleryMediaItem.from(opus);
      expect(item.url, equals('https://example.com/opus.png'));
      expect(item.width, equals(1080.0));
      expect(item.height, equals(2400.0));
      expect(item.aspectRatio, closeTo(1080 / 2400, 0.001));
      expect(item.isLongImage, isTrue);
    });

    test('from parses DynamicDrawItemModel correctly', () {
      final draw = DynamicDrawItemModel(
        src: 'https://example.com/draw.png',
        width: 1920,
        height: 1080,
      );
      final item = GalleryMediaItem.from(draw);
      expect(item.url, equals('https://example.com/draw.png'));
      expect(item.width, equals(1920.0));
      expect(item.height, equals(1080.0));
      expect(item.aspectRatio, closeTo(1920 / 1080, 0.001));
      expect(item.isLongImage, isFalse);
    });

    test('isLongImage returns true when height >= 2 * width', () {
      const longItem = GalleryMediaItem(
        url: 'https://example.com/long.jpg',
        width: 400,
        height: 1200,
      );
      expect(longItem.aspectRatio, closeTo(400 / 1200, 0.001));
      expect(longItem.isLongImage, isTrue);

      const squareItem = GalleryMediaItem(
        url: 'https://example.com/sq.jpg',
        width: 500,
        height: 500,
      );
      expect(squareItem.isLongImage, isFalse);
    });
  });

  group('NineGridGalleryLayout Pure Geometry Tests', () {
    test('returns zero dimensions for 0 items or 0 container width', () {
      final res1 = NineGridGalleryLayout.compute(
        itemCount: 0,
        containerWidth: 360,
      );
      expect(res1.height, equals(0.0));

      final res2 = NineGridGalleryLayout.compute(
        itemCount: 4,
        containerWidth: 0,
      );
      expect(res2.height, equals(0.0));
    });

    test('single long image is clamped and marked as isSingleLongImage', () {
      // aspectRatio = 0.3 (ultra long image)
      final res = NineGridGalleryLayout.compute(
        itemCount: 1,
        containerWidth: 360,
        singleImageAspectRatio: 0.3,
      );

      expect(res.crossAxisCount, equals(1));
      expect(res.isSingleLongImage, isTrue);
      expect(res.isSingleWideImage, isFalse);
      // Width is containerWidth * 0.65 clamped to <= 240
      expect(res.width, equals(234.0));
      // Height is clamped between 180 and 360
      expect(res.height, equals(360.0));
    });

    test('single wide image is clamped and marked as isSingleWideImage', () {
      // aspectRatio = 3.0 (panoramic banner)
      final res = NineGridGalleryLayout.compute(
        itemCount: 1,
        containerWidth: 360,
        singleImageAspectRatio: 3.0,
      );

      expect(res.crossAxisCount, equals(1));
      expect(res.isSingleWideImage, isTrue);
      expect(res.isSingleLongImage, isFalse);
      expect(res.width, equals(360.0));
      // 360 / 3.0 = 120 (clamped between 100 and 200)
      expect(res.height, equals(120.0));
    });

    test('single normal image adheres to standard bounds', () {
      // 16:9 landscape image (aspectRatio = 1.777)
      final resLandscape = NineGridGalleryLayout.compute(
        itemCount: 1,
        containerWidth: 360,
        singleImageAspectRatio: 16 / 9,
      );
      expect(resLandscape.crossAxisCount, equals(1));
      expect(resLandscape.isSingleLongImage, isFalse);
      expect(resLandscape.isSingleWideImage, isFalse);
      expect(resLandscape.width, closeTo(306.0, 0.5));
      expect(resLandscape.height, closeTo(306.0 / (16 / 9), 0.5));

      // Unknown aspect ratio defaults to 4:3
      final resUnknown = NineGridGalleryLayout.compute(
        itemCount: 1,
        containerWidth: 360,
        singleImageAspectRatio: null,
      );
      expect(resUnknown.childAspectRatio, equals(4 / 3));
    });

    test('2 items renders 1 row 2 columns', () {
      const containerW = 360.0;
      const spacing = 4.0;
      final res = NineGridGalleryLayout.compute(
        itemCount: 2,
        containerWidth: containerW,
        spacing: spacing,
      );

      expect(res.crossAxisCount, equals(2));
      const expectedItemW = (360.0 - 4.0) / 2; // 178.0
      expect(res.itemWidth, equals(expectedItemW));
      expect(res.height, equals(expectedItemW));
      expect(res.childAspectRatio, equals(1.0));
    });

    test('3 items renders 1 row 3 columns', () {
      const containerW = 360.0;
      const spacing = 4.0;
      final res = NineGridGalleryLayout.compute(
        itemCount: 3,
        containerWidth: containerW,
        spacing: spacing,
      );

      expect(res.crossAxisCount, equals(3));
      const expectedItemW = (360.0 - 8.0) / 3; // 117.333
      expect(res.itemWidth, closeTo(expectedItemW, 0.01));
      expect(res.height, closeTo(expectedItemW, 0.01));
      expect(res.childAspectRatio, equals(1.0));
    });

    test('4 items renders 2x2 symmetric grid with crossAxisCount: 2', () {
      const containerW = 360.0;
      const spacing = 4.0;
      final res = NineGridGalleryLayout.compute(
        itemCount: 4,
        containerWidth: containerW,
        spacing: spacing,
      );

      // SPEC-01: 4 items MUST be 2x2
      expect(res.crossAxisCount, equals(2));
      const colW = (360.0 - 8.0) / 3; // 117.333
      const expectedTotalW = colW * 2 + spacing;
      expect(res.width, closeTo(expectedTotalW, 0.01));
      expect(res.height, closeTo(expectedTotalW, 0.01));
      expect(res.itemWidth, closeTo(colW, 0.01));
      expect(res.childAspectRatio, equals(1.0));
    });

    test('5 to 9 items renders 3 columns with multi-row height calculation', () {
      const containerW = 360.0;
      const spacing = 4.0;
      const colW = (360.0 - 8.0) / 3; // 117.333

      // 5 items -> 2 rows
      final res5 = NineGridGalleryLayout.compute(
        itemCount: 5,
        containerWidth: containerW,
        spacing: spacing,
      );
      expect(res5.crossAxisCount, equals(3));
      expect(res5.height, closeTo(colW * 2 + spacing, 0.01));

      // 6 items -> 2 rows
      final res6 = NineGridGalleryLayout.compute(
        itemCount: 6,
        containerWidth: containerW,
        spacing: spacing,
      );
      expect(res6.crossAxisCount, equals(3));
      expect(res6.height, closeTo(colW * 2 + spacing, 0.01));

      // 9 items -> 3 rows
      final res9 = NineGridGalleryLayout.compute(
        itemCount: 9,
        containerWidth: containerW,
        spacing: spacing,
      );
      expect(res9.crossAxisCount, equals(3));
      expect(res9.height, closeTo(colW * 3 + 2 * spacing, 0.01));
    });
  });
}

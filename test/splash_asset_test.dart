import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _android12Source = 'icon_sources/pilipalaz_splash_android12.png';
const _legacySource = 'icon_sources/pilipalaz_splash.png';

Future<_DecodedImage> _decodePng(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final decoded = _DecodedImage(
    width: image.width,
    height: image.height,
    pixels: byteData!.buffer.asUint8List(),
  );
  image.dispose();
  codec.dispose();
  return decoded;
}

String _android12Block(String pubspec) {
  final match = RegExp(
    r'^  android_12:\r?\n((?: {4}.+(?:\r?\n|$))+)',
    multiLine: true,
  ).firstMatch(pubspec);
  expect(match, isNotNull, reason: 'pubspec.yaml must define android_12');
  return match!.group(1)!;
}

void main() {
  test(
    'Android 12 splash uses a dedicated safe high-resolution source',
    () async {
      final source = File(_android12Source);
      expect(source.existsSync(), isTrue);

      final image = await _decodePng(_android12Source);
      expect((image.width, image.height), (1152, 1152));

      final cornerOffsets = <int>[
        0,
        (image.width - 1) * 4,
        (image.height - 1) * image.width * 4,
        ((image.height * image.width) - 1) * 4,
      ];
      for (final offset in cornerOffsets) {
        expect(image.pixels[offset + 3], 0);
      }

      const center = 576.0;
      var visiblePixels = 0;
      var maxSolidRadius = 0.0;
      var maxVisibleRadius = 0.0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final alpha = image.pixels[((y * image.width) + x) * 4 + 3];
          if (alpha == 0) {
            continue;
          }
          visiblePixels++;
          final radius = math.sqrt(
            math.pow(x + 0.5 - center, 2) + math.pow(y + 0.5 - center, 2),
          );
          maxVisibleRadius = math.max(maxVisibleRadius, radius);
          if (alpha >= 8) {
            maxSolidRadius = math.max(maxSolidRadius, radius);
          }
        }
      }

      expect(visiblePixels, greaterThan(50000));
      expect(maxSolidRadius, inInclusiveRange(340.0, 361.0));
      expect(maxVisibleRadius, lessThanOrEqualTo(384.0));

      final pubspec = File('pubspec.yaml').readAsStringSync();
      final android12 = _android12Block(pubspec);
      expect(
        RegExp(RegExp.escape(_android12Source)).allMatches(android12).length,
        2,
      );
      expect(
        RegExp(RegExp.escape(_legacySource)).allMatches(android12),
        isEmpty,
      );
      final nonAndroid12 = pubspec.replaceFirst(android12, '');
      expect(
        RegExp(RegExp.escape(_legacySource)).allMatches(nonAndroid12).length,
        2,
      );
    },
  );

  test(
    'generated Android splash resources preserve density contracts',
    () async {
      const densities = <String, int>{
        'mdpi': 288,
        'hdpi': 432,
        'xhdpi': 576,
        'xxhdpi': 864,
        'xxxhdpi': 1152,
      };
      const legacySizes = <String, int>{
        'mdpi': 128,
        'hdpi': 192,
        'xhdpi': 256,
        'xxhdpi': 384,
        'xxxhdpi': 512,
      };

      for (final dark in <bool>[false, true]) {
        final qualifier = dark ? 'drawable-night' : 'drawable';
        for (final density in densities.entries) {
          final android12 = await _decodePng(
            'android/app/src/main/res/'
            '$qualifier-${density.key}/android12splash.png',
          );
          expect(
            (android12.width, android12.height),
            (density.value, density.value),
          );

          final legacy = await _decodePng(
            'android/app/src/main/res/'
            '$qualifier-${density.key}/splash.png',
          );
          expect(
            (legacy.width, legacy.height),
            (legacySizes[density.key], legacySizes[density.key]),
          );
        }
      }
    },
  );
}

class _DecodedImage {
  const _DecodedImage({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;
  final Uint8List pixels;
}

/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

/// Represents 2D video output dimensions.
class VideoDimension {
  final int width;
  final int height;

  const VideoDimension(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoDimension &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'VideoDimension($width, $height)';
}

/// Calculates display dimensions considering video rotation.
///
/// Rotation is in clockwise degrees (0, 90, 180, 270).
/// Only 90° and 270° rotations swap width and height.
/// Unspecified (null), 0°, and 180° preserve original dimensions.
VideoDimension computeRotatedDimensions({
  required int rawWidth,
  required int rawHeight,
  int? rotate,
}) {
  final int normalized = rotate ?? 0;
  if (normalized == 90 || normalized == 270) {
    return VideoDimension(rawHeight, rawWidth);
  }
  return VideoDimension(rawWidth, rawHeight);
}

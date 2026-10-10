import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/widgets/video_detail_layout_coordinator.dart';

void main() {
  group('VideoDetailLayoutCoordinator Pull-To-FullScreen TDD Unit Tests', () {
    test(
      'resolvePullToFullScreenDisplacement returns 40.0 for standard single-column',
      () {
        final displacement =
            VideoDetailLayoutCoordinator.resolvePullToFullScreenDisplacement(
              isDualColumn: false,
            );
        expect(displacement, 40.0);
      },
    );

    test(
      'resolvePullToFullScreenDisplacement returns 80.0 for dual-column to prevent accidental triggers',
      () {
        final displacement =
            VideoDetailLayoutCoordinator.resolvePullToFullScreenDisplacement(
              isDualColumn: true,
            );
        expect(displacement, 80.0);
      },
    );

    test('dual-column displacement is strictly greater than single-column', () {
      final singleDisplacement =
          VideoDetailLayoutCoordinator.resolvePullToFullScreenDisplacement(
            isDualColumn: false,
          );
      final dualDisplacement =
          VideoDetailLayoutCoordinator.resolvePullToFullScreenDisplacement(
            isDualColumn: true,
          );
      expect(dualDisplacement, greaterThan(singleDisplacement));
    });
  });
}

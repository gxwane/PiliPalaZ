import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/live_room/widgets/bottom_control.dart'
    as live_bottom;
import 'package:pilipalaz/pages/video/widgets/header_control.dart';

void main() {
  group('PreferredSizeWidget contract', () {
    test('HeaderControl implements preferredSize without throwing', () {
      const header = HeaderControl(heroTag: 'test_tag');
      expect(header, isA<PreferredSizeWidget>());
      expect(() => header.preferredSize, returnsNormally);
      expect(header.preferredSize.height, kToolbarHeight);
      expect(header.preferredSize.width, double.infinity);
    });

    test('BottomControl implements preferredSize without throwing', () {
      const bottom = live_bottom.BottomControl();
      expect(bottom, isA<PreferredSizeWidget>());
      expect(() => bottom.preferredSize, returnsNormally);
      expect(bottom.preferredSize.height, kToolbarHeight);
      expect(bottom.preferredSize.width, double.infinity);
    });
  });
}

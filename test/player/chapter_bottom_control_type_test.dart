import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/models/bottom_control_type.dart';
import 'package:pilipalaz/plugin/pl_player/widgets/bottom_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BottomControl Chapter Button Types Tests', () {
    test(
      'buildDefaultBottomControlTypes includes chapter when hasChapters is true',
      () {
        final controlsWithChapter = buildDefaultBottomControlTypes(
          hasEpisodes: false,
          isEquivalentFullScreen: false,
          hasSubtitles: false,
          hasChapters: true,
        );

        expect(controlsWithChapter, contains(BottomControlType.chapter));

        final controlsWithoutChapter = buildDefaultBottomControlTypes(
          hasEpisodes: false,
          isEquivalentFullScreen: false,
          hasSubtitles: false,
          hasChapters: false,
        );

        expect(
          controlsWithoutChapter,
          isNot(contains(BottomControlType.chapter)),
        );
      },
    );

    test('resolveBottomControlLayout places chapter in optional priority', () {
      final layout = resolveBottomControlLayout(
        maxWidth: 5 * bottomControlItemExtent,
        controls: const [
          BottomControlType.playOrPause,
          BottomControlType.chapter,
          BottomControlType.speed,
          BottomControlType.fullscreen,
        ],
      );

      expect(layout.visible, contains(BottomControlType.chapter));
      expect(layout.visible, contains(BottomControlType.playOrPause));
      expect(layout.visible, contains(BottomControlType.fullscreen));
    });
  });
}

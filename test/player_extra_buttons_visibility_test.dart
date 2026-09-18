import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/view.dart';

void main() {
  group('resolveExtraButtonVisibility', () {
    test('shows on phone portrait when enabled and controls shown', () {
      final visible = resolveExtraButtonVisibility(
        isLive: false,
        enableExtraButtonOnFullScreen: true,
        showControls: true,
        isFullScreen: false,
        isEquivalentFullScreen: false,
        isLandscape: false,
        controlsLock: false,
      );
      expect(visible, isTrue);
    });

    test('shows on phone landscape even if not logic fullscreen', () {
      final visible = resolveExtraButtonVisibility(
        isLive: false,
        enableExtraButtonOnFullScreen: true,
        showControls: true,
        isFullScreen: false,
        isEquivalentFullScreen: false,
        isLandscape: true,
        controlsLock: false,
      );
      expect(visible, isTrue);
    });

    test(
      'shows on tablet landscape split view where equivalent fullscreen was false',
      () {
        // Regression test: on tablet landscape split view, ScreenUtils.isTablet returned false
        // for isEquivalentFullScreen, but orientation is landscape. Lock button must be visible!
        final visible = resolveExtraButtonVisibility(
          isLive: false,
          enableExtraButtonOnFullScreen: true,
          showControls: true,
          isFullScreen: false,
          isEquivalentFullScreen: false,
          isLandscape: true,
          controlsLock: false,
        );
        expect(visible, isTrue);
      },
    );

    test('shows when isFullScreen is true', () {
      final visible = resolveExtraButtonVisibility(
        isLive: false,
        enableExtraButtonOnFullScreen: true,
        showControls: true,
        isFullScreen: true,
        isEquivalentFullScreen: false,
        isLandscape: false,
        controlsLock: false,
      );
      expect(visible, isTrue);
    });

    test('shows unlock button when controlsLock is true even in portrait', () {
      final visible = resolveExtraButtonVisibility(
        isLive: false,
        enableExtraButtonOnFullScreen: true,
        showControls: true,
        isFullScreen: false,
        isEquivalentFullScreen: false,
        isLandscape: false,
        controlsLock: true,
      );
      expect(visible, isTrue);
    });

    test('hides when enableExtraButtonOnFullScreen setting is false', () {
      final visible = resolveExtraButtonVisibility(
        isLive: false,
        enableExtraButtonOnFullScreen: false,
        showControls: true,
        isFullScreen: true,
        isEquivalentFullScreen: true,
        isLandscape: true,
        controlsLock: false,
      );
      expect(visible, isFalse);
    });

    test('hides when showControls is false', () {
      final visible = resolveExtraButtonVisibility(
        isLive: false,
        enableExtraButtonOnFullScreen: true,
        showControls: false,
        isFullScreen: true,
        isEquivalentFullScreen: true,
        isLandscape: true,
        controlsLock: false,
      );
      expect(visible, isFalse);
    });

    test('hides on live streams', () {
      final visible = resolveExtraButtonVisibility(
        isLive: true,
        enableExtraButtonOnFullScreen: true,
        showControls: true,
        isFullScreen: true,
        isEquivalentFullScreen: true,
        isLandscape: true,
        controlsLock: false,
      );
      expect(visible, isFalse);
    });
  });

  group('resolveScreenshotButtonVisibility', () {
    test(
      'shows on landscape or fullscreen when enabled and controls shown',
      () {
        expect(
          resolveScreenshotButtonVisibility(
            enableExtraButtonOnFullScreen: true,
            showControls: true,
            isFullScreen: false,
            isEquivalentFullScreen: false,
            isLandscape: true,
          ),
          isTrue,
        );

        expect(
          resolveScreenshotButtonVisibility(
            enableExtraButtonOnFullScreen: true,
            showControls: true,
            isFullScreen: true,
            isEquivalentFullScreen: false,
            isLandscape: false,
          ),
          isTrue,
        );
      },
    );

    test('hides when disabled by setting or controls hidden', () {
      expect(
        resolveScreenshotButtonVisibility(
          enableExtraButtonOnFullScreen: false,
          showControls: true,
          isFullScreen: true,
          isEquivalentFullScreen: true,
          isLandscape: true,
        ),
        isFalse,
      );

      expect(
        resolveScreenshotButtonVisibility(
          enableExtraButtonOnFullScreen: true,
          showControls: false,
          isFullScreen: true,
          isEquivalentFullScreen: true,
          isLandscape: true,
        ),
        isFalse,
      );
    });

    test('hides when controlsLock is true even if controls are shown', () {
      expect(
        resolveScreenshotButtonVisibility(
          enableExtraButtonOnFullScreen: true,
          showControls: true,
          isFullScreen: true,
          isEquivalentFullScreen: true,
          isLandscape: true,
          controlsLock: true,
        ),
        isFalse,
      );
    });
  });
}

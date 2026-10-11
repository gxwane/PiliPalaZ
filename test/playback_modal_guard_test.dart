import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/view.dart';
import 'package:pilipalaz/plugin/pl_player/playback_modal_guard.dart';

class _MockOpaqueRoute extends PageRoute<void> {
  _MockOpaqueRoute();

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox();

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  bool get opaque => true;
}

class _MockTransparentRoute extends PageRoute<void> {
  _MockTransparentRoute();

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox();

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  bool get opaque => false;
}

class _TestRouteAware with RouteAware {
  final List<String> events;
  _TestRouteAware(this.events);

  @override
  void didPushNext() {
    events.add('didPushNext');
  }

  @override
  void didPopNext() {
    events.add('didPopNext');
  }
}

void main() {
  group('VideoRouteObserver', () {
    test(
      'ignores non-opaque transparent routes and only notifies opaque routes',
      () {
        final VideoRouteObserver observer = VideoRouteObserver();
        final List<String> events = <String>[];
        final _TestRouteAware listener = _TestRouteAware(events);
        final _MockOpaqueRoute baseRoute = _MockOpaqueRoute();
        final _MockTransparentRoute transparentRoute = _MockTransparentRoute();
        final _MockOpaqueRoute opaqueNextRoute = _MockOpaqueRoute();

        observer.subscribe(listener, baseRoute);

        // Pushing transparent route: should be ignored
        observer.didPush(transparentRoute, baseRoute);
        expect(events, isEmpty);

        // Popping transparent route: should be ignored
        observer.didPop(transparentRoute, baseRoute);
        expect(events, isEmpty);

        // Pushing opaque route: should trigger didPushNext
        observer.didPush(opaqueNextRoute, baseRoute);
        expect(events, <String>['didPushNext']);

        // Popping opaque route: should trigger didPopNext
        observer.didPop(opaqueNextRoute, baseRoute);
        expect(events, <String>['didPushNext', 'didPopNext']);
      },
    );
  });

  group('runPlaybackAwareModal', () {
    test('pauses before the modal and resumes after it closes', () async {
      final List<String> events = <String>[];

      final int? result = await runPlaybackAwareModal<int>(
        wasPlaying: true,
        pause: () async => events.add('pause'),
        showModal: () async {
          events.add('show');
          return 42;
        },
        canResume: () {
          events.add('canResume');
          return true;
        },
        resume: () async => events.add('resume'),
      );

      expect(result, 42);
      expect(events, <String>['pause', 'show', 'canResume', 'resume']);
    });

    test('does not touch playback when it was already paused', () async {
      final List<String> events = <String>[];

      await runPlaybackAwareModal<void>(
        wasPlaying: false,
        pause: () async => events.add('pause'),
        showModal: () async => events.add('show'),
        canResume: () {
          events.add('canResume');
          return true;
        },
        resume: () async => events.add('resume'),
      );

      expect(events, <String>['show']);
    });

    test('does not resume when the playback resource changed', () async {
      final List<String> events = <String>[];

      await runPlaybackAwareModal<void>(
        wasPlaying: true,
        pause: () async => events.add('pause'),
        showModal: () async => events.add('show'),
        canResume: () {
          events.add('canResume');
          return false;
        },
        resume: () async => events.add('resume'),
      );

      expect(events, <String>['pause', 'show', 'canResume']);
    });

    test('checks restoration and preserves a modal error', () async {
      final List<String> events = <String>[];
      final StateError error = StateError('preview failed');

      await expectLater(
        runPlaybackAwareModal<void>(
          wasPlaying: true,
          pause: () async => events.add('pause'),
          showModal: () async {
            events.add('show');
            throw error;
          },
          canResume: () {
            events.add('canResume');
            return true;
          },
          resume: () async => events.add('resume'),
        ),
        throwsA(same(error)),
      );
      expect(events, <String>['pause', 'show', 'canResume', 'resume']);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/playback_modal_guard.dart';

void main() {
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

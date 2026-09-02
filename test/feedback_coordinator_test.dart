import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/feedback_coordinator.dart';

void main() {
  group('FeedbackCoordinator', () {
    test('builds the bug and feature Issue Form URLs', () {
      const coordinator = FeedbackCoordinator();

      final bugUri = coordinator.uriFor(FeedbackKind.bug);
      final featureUri = coordinator.uriFor(FeedbackKind.feature);

      expect(
        bugUri.toString(),
        'https://github.com/gxwane/PiliPalaZ/issues/new?template=bug_report.yml',
      );
      expect(
        featureUri.toString(),
        'https://github.com/gxwane/PiliPalaZ/issues/new?template=feature_request.yml',
      );
    });

    test('reports opened when the external browser accepts the URL', () async {
      Uri? launchedUri;
      final copied = <String>[];
      final coordinator = FeedbackCoordinator(
        launchExternal: (uri) async {
          launchedUri = uri;
          return true;
        },
        writeClipboard: (text) async => copied.add(text),
      );

      final result = await coordinator.open(FeedbackKind.feature);

      expect(result, FeedbackOpenResult.opened);
      expect(launchedUri?.queryParameters['template'], 'feature_request.yml');
      expect(copied, isEmpty);
    });

    test('copies the Issue Form URL when the browser cannot open it', () async {
      final copied = <String>[];
      final coordinator = FeedbackCoordinator(
        launchExternal: (_) async => false,
        writeClipboard: (text) async => copied.add(text),
      );

      final result = await coordinator.open(FeedbackKind.bug);

      expect(result, FeedbackOpenResult.copiedOnly);
      expect(copied, hasLength(1));
      expect(copied.single, contains('template=bug_report.yml'));
    });

    test('copies diagnostics before opening the bug form', () async {
      final events = <String>[];
      Uri? launchedUri;
      final coordinator = FeedbackCoordinator(
        launchExternal: (uri) async {
          events.add('launch');
          launchedUri = uri;
          return true;
        },
        writeClipboard: (text) async => events.add('copy:$text'),
      );

      final result = await coordinator.open(
        FeedbackKind.bug,
        diagnosticReport: 'reviewed diagnostics',
      );

      expect(result, FeedbackOpenResult.opened);
      expect(events, <String>['copy:reviewed diagnostics', 'launch']);
      expect(launchedUri.toString(), isNot(contains('reviewed')));
      expect(launchedUri?.queryParameters, <String, String>{
        'template': 'bug_report.yml',
      });
    });

    test('does not open the browser when diagnostic copying fails', () async {
      var launchCount = 0;
      final coordinator = FeedbackCoordinator(
        launchExternal: (_) async {
          launchCount += 1;
          return true;
        },
        writeClipboard: (_) => Future<void>.error(StateError('clipboard')),
      );

      final result = await coordinator.open(
        FeedbackKind.bug,
        diagnosticReport: 'reviewed diagnostics',
      );

      expect(result, FeedbackOpenResult.failed);
      expect(launchCount, 0);
    });

    test('keeps copied diagnostics when browser launching fails', () async {
      final copied = <String>[];
      final coordinator = FeedbackCoordinator(
        launchExternal: (_) async => false,
        writeClipboard: (text) async => copied.add(text),
      );

      final result = await coordinator.open(
        FeedbackKind.bug,
        diagnosticReport: 'reviewed diagnostics',
      );

      expect(result, FeedbackOpenResult.copiedOnly);
      expect(copied, <String>['reviewed diagnostics']);
    });

    test('falls back to copying the URL after a launcher exception', () async {
      final copied = <String>[];
      final coordinator = FeedbackCoordinator(
        launchExternal: (_) => Future<bool>.error(StateError('launcher')),
        writeClipboard: (text) async => copied.add(text),
      );

      final result = await coordinator.open(FeedbackKind.feature);

      expect(result, FeedbackOpenResult.copiedOnly);
      expect(copied.single, contains('template=feature_request.yml'));
    });

    test('never includes diagnostic text in the destination URI', () async {
      const diagnostics = 'access_token=private&cookie=private';
      Uri? launchedUri;
      final coordinator = FeedbackCoordinator(
        launchExternal: (uri) async {
          launchedUri = uri;
          return true;
        },
        writeClipboard: (_) async {},
      );

      await coordinator.open(FeedbackKind.bug, diagnosticReport: diagnostics);

      expect(launchedUri.toString(), isNot(contains('private')));
      expect(launchedUri.toString(), isNot(contains('access_token')));
      expect(launchedUri.toString(), isNot(contains('cookie')));
    });
  });
}

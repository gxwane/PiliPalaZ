import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pilipalaz/common/widgets/html_render.dart';

import '../test/support/html_render_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profiles representative HTML documents', (tester) async {
    final results = <String, Object?>{};
    for (final fixture in <(String, int)>[
      ('short', 2 * 1024),
      ('medium', 25 * 1024),
      ('long', 100 * 1024),
    ]) {
      results[fixture.$1] = await _profileFixture(
        tester,
        name: fixture.$1,
        html: buildHtmlRenderFixture(fixture.$2),
      );
    }

    binding.reportData = <String, Object?>{'html_renderer': results};
    // Kept as a single machine-readable line for local profile comparisons.
    debugPrint('HTML_RENDERER_PROFILE=${jsonEncode(results)}');
  });
}

Future<Map<String, Object?>> _profileFixture(
  WidgetTester tester, {
  required String name,
  required String html,
}) async {
  final markerText = 'HTML_PROFILE_START_$name';
  final profileHtml = '<p>$markerText</p>$html';
  final firstContentMicros = <int>[];
  final frameTimings = <FrameTiming>[];
  var peakRss = ProcessInfo.currentRss;

  void collectTimings(List<FrameTiming> timings) =>
      frameTimings.addAll(timings);
  SchedulerBinding.instance.addTimingsCallback(collectTimings);
  try {
    for (var run = 0; run < 10; run++) {
      debugPrint('HTML_PROFILE_PROGRESS=$name:$run:start');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final controller = ScrollController();
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  HtmlRenderSliver(
                    key: ValueKey('$name-$run'),
                    htmlContent: profileHtml,
                    constrainedWidth: 360,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final marker = find.textContaining(markerText, findRichText: true);
      for (
        var attempt = 0;
        attempt < 100 && marker.evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(marker, findsOneWidget);
      stopwatch.stop();
      firstContentMicros.add(stopwatch.elapsedMicroseconds);
      debugPrint('HTML_PROFILE_PROGRESS=$name:$run:rendered');
      peakRss = peakRss < ProcessInfo.currentRss
          ? ProcessInfo.currentRss
          : peakRss;

      if (run < 3 && controller.hasClients) {
        final maxScrollExtent = controller.position.maxScrollExtent;
        for (var frame = 1; frame <= 60; frame++) {
          controller.jumpTo(maxScrollExtent * frame / 60);
          await tester.pump(const Duration(milliseconds: 15));
        }
        for (var frame = 59; frame >= 0; frame--) {
          controller.jumpTo(maxScrollExtent * frame / 60);
          await tester.pump(const Duration(milliseconds: 15));
        }
        debugPrint('HTML_PROFILE_PROGRESS=$name:$run:scrolled');
        peakRss = peakRss < ProcessInfo.currentRss
            ? ProcessInfo.currentRss
            : peakRss;
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
      debugPrint('HTML_PROFILE_PROGRESS=$name:$run:done');
    }

    await tester.pump(const Duration(milliseconds: 100));
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collectTimings);
  }

  firstContentMicros.sort();
  final buildMicros = frameTimings
      .map((timing) => timing.buildDuration.inMicroseconds)
      .toList();
  final workMicros = frameTimings
      .map(
        (timing) =>
            timing.buildDuration.inMicroseconds +
            timing.rasterDuration.inMicroseconds,
      )
      .toList();
  final totalSpanMicros = frameTimings
      .map((timing) => timing.totalSpan.inMicroseconds)
      .toList();
  final slowFrames = workMicros.where((value) => value > 16667).length;

  return <String, Object?>{
    'htmlLength': profileHtml.length,
    'coldRuns': firstContentMicros.length,
    'medianFirstContentMicros':
        firstContentMicros[firstContentMicros.length ~/ 2],
    'maxBuildMicros': buildMicros.isEmpty ? 0 : buildMicros.reduce(_max),
    'maxFrameWorkMicros': workMicros.isEmpty ? 0 : workMicros.reduce(_max),
    'maxTotalSpanMicros': totalSpanMicros.isEmpty
        ? 0
        : totalSpanMicros.reduce(_max),
    'frameCount': workMicros.length,
    'slowFrameRate': workMicros.isEmpty ? 0 : slowFrames / workMicros.length,
    'peakRssBytes': peakRss,
  };
}

int _max(int left, int right) => left > right ? left : right;

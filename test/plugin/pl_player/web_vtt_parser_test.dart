import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/utils/web_vtt_parser.dart';

void main() {
  group('WebVttParser TDD Unit Tests (Gate 4)', () {
    test('parses standard WebVTT cues with hours correctly', () {
      const vtt = '''WEBVTT

1
00:00:01.500 --> 00:00:04.200
Hello World

2
00:01:10.000 --> 00:01:15.500
Second Subtitle Line
''';

      final cues = WebVttParser.parse(vtt);

      expect(cues.length, equals(2));
      expect(
        cues[0].start,
        equals(const Duration(seconds: 1, milliseconds: 500)),
      );
      expect(
        cues[0].end,
        equals(const Duration(seconds: 4, milliseconds: 200)),
      );
      expect(cues[0].text, equals('Hello World'));

      expect(cues[1].start, equals(const Duration(minutes: 1, seconds: 10)));
      expect(
        cues[1].end,
        equals(const Duration(minutes: 1, seconds: 15, milliseconds: 500)),
      );
      expect(cues[1].text, equals('Second Subtitle Line'));
    });

    test('parses short timecodes without hours (mm:ss.mmm)', () {
      const vtt = '''WEBVTT

01:20.100 --> 01:25.300
Short Timecode Text
''';

      final cues = WebVttParser.parse(vtt);

      expect(cues.length, equals(1));
      expect(
        cues[0].start,
        equals(const Duration(minutes: 1, seconds: 20, milliseconds: 100)),
      );
      expect(
        cues[0].end,
        equals(const Duration(minutes: 1, seconds: 25, milliseconds: 300)),
      );
      expect(cues[0].text, equals('Short Timecode Text'));
    });

    test('parses SRT style timecodes with commas', () {
      const srt = '''1
00:00:05,123 --> 00:00:08,789
Comma separated timecode
''';

      final cues = WebVttParser.parse(srt);

      expect(cues.length, equals(1));
      expect(
        cues[0].start,
        equals(const Duration(seconds: 5, milliseconds: 123)),
      );
      expect(
        cues[0].end,
        equals(const Duration(seconds: 8, milliseconds: 789)),
      );
      expect(cues[0].text, equals('Comma separated timecode'));
    });

    test('aggregates multi-line subtitles into single cue with newline', () {
      const vtt = '''WEBVTT

00:00:02.000 --> 00:00:05.000
Line 1: Hello
Line 2: World
Line 3: Multiple Lines
''';

      final cues = WebVttParser.parse(vtt);

      expect(cues.length, equals(1));
      expect(
        cues[0].text,
        equals('Line 1: Hello\nLine 2: World\nLine 3: Multiple Lines'),
      );
    });

    test('sanitizes HTML tags and decodes common HTML entities', () {
      const vtt = '''WEBVTT

00:00:01.000 --> 00:00:03.000
<c.yellow><b>Tom &amp; Jerry</b></c> &lt;3 &quot;friends&quot;
''';

      final cues = WebVttParser.parse(vtt);

      expect(cues.length, equals(1));
      expect(cues[0].text, equals('Tom & Jerry <3 "friends"'));
    });

    test(
      'handles empty or completely malformed inputs gracefully without throwing',
      () {
        expect(WebVttParser.parse(''), isEmpty);
        expect(WebVttParser.parse('   \n\n  '), isEmpty);
        expect(
          WebVttParser.parse('WEBVTT\nInvalid file with no timecodes'),
          isEmpty,
        );
        expect(
          WebVttParser.parse('00:00:01.000 --> invalid_end\nBad cue'),
          isEmpty,
        );
      },
    );

    test(
      'findActiveSubtitles correctly finds active cue and handles overlapping cues',
      () {
        final cues = [
          SubtitleCue(
            start: const Duration(seconds: 1),
            end: const Duration(seconds: 5),
            text: 'Speaker A: Hi',
          ),
          SubtitleCue(
            start: const Duration(seconds: 3),
            end: const Duration(seconds: 7),
            text: 'Speaker B: Hello too',
          ),
          SubtitleCue(
            start: const Duration(seconds: 10),
            end: const Duration(seconds: 15),
            text: 'Speaker A: Bye',
          ),
        ];

        // At 0.5s (before start)
        expect(
          WebVttParser.findActiveText(cues, const Duration(milliseconds: 500)),
          equals(''),
        );

        // At 2.0s (only Speaker A)
        expect(
          WebVttParser.findActiveText(cues, const Duration(seconds: 2)),
          equals('Speaker A: Hi'),
        );

        // At 4.0s (overlapping A and B)
        expect(
          WebVttParser.findActiveText(cues, const Duration(seconds: 4)),
          equals('Speaker A: Hi\nSpeaker B: Hello too'),
        );

        // At 6.0s (only Speaker B)
        expect(
          WebVttParser.findActiveText(cues, const Duration(seconds: 6)),
          equals('Speaker B: Hello too'),
        );

        // At 8.0s (silence gap between 7s and 10s)
        expect(
          WebVttParser.findActiveText(cues, const Duration(seconds: 8)),
          equals(''),
        );

        // At 12.0s (Speaker A: Bye)
        expect(
          WebVttParser.findActiveText(cues, const Duration(seconds: 12)),
          equals('Speaker A: Bye'),
        );

        // At 16.0s (after end)
        expect(
          WebVttParser.findActiveText(cues, const Duration(seconds: 16)),
          equals(''),
        );
      },
    );
  });
}

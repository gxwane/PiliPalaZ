import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/utils/reply_timestamp_parser.dart';

void main() {
  group('ReplyTimestampParser TDD Unit Tests', () {
    test('parseToSeconds parses standard mm:ss accurately', () {
      expect(ReplyTimestampParser.parseToSeconds('01:23'), 83);
      expect(ReplyTimestampParser.parseToSeconds('00:00'), 0);
      expect(ReplyTimestampParser.parseToSeconds('00:45'), 45);
      expect(ReplyTimestampParser.parseToSeconds('10:00'), 600);
      expect(ReplyTimestampParser.parseToSeconds('59:59'), 3599);
    });

    test('parseToSeconds parses single-digit minute m:ss', () {
      expect(ReplyTimestampParser.parseToSeconds('1:23'), 83);
      expect(ReplyTimestampParser.parseToSeconds('0:05'), 5);
      expect(ReplyTimestampParser.parseToSeconds('9:30'), 570);
    });

    test('parseToSeconds parses hh:mm:ss accurately', () {
      expect(ReplyTimestampParser.parseToSeconds('01:02:03'), 3723);
      expect(ReplyTimestampParser.parseToSeconds('1:02:03'), 3723);
      expect(ReplyTimestampParser.parseToSeconds('02:00:00'), 7200);
    });

    test('parseToSeconds handles full-width Chinese colon', () {
      expect(ReplyTimestampParser.parseToSeconds('01：23'), 83);
      expect(ReplyTimestampParser.parseToSeconds('1：02：03'), 3723);
      expect(ReplyTimestampParser.parseToSeconds('01：02:03'), 3723);
    });

    test('parseToSeconds rejects invalid or malformed timestamps', () {
      expect(ReplyTimestampParser.parseToSeconds(''), isNull);
      expect(ReplyTimestampParser.parseToSeconds('abc'), isNull);
      expect(
        ReplyTimestampParser.parseToSeconds('12:60'),
        isNull,
      ); // second 60 is invalid
      expect(
        ReplyTimestampParser.parseToSeconds('60:00'),
        isNull,
      ); // minute 60 is invalid
      expect(ReplyTimestampParser.parseToSeconds('12:34:56:78'), isNull);
    });

    test(
      'extractTimestamps extracts timestamps from Chinese text without URL pollution',
      () {
        const text = '前言看01:23，高能时刻在12:45，参考网址http://127.0.0.1:8080勿点';
        final timestamps = ReplyTimestampParser.extractTimestamps(text);
        expect(timestamps, contains('01:23'));
        expect(timestamps, contains('12:45'));
        expect(timestamps, isNot(contains('8080')));
        expect(timestamps, isNot(contains('0.1:8080')));
      },
    );

    test('isTimestamp validates full string strictly', () {
      expect(ReplyTimestampParser.isTimestamp(' 01:23 '), isTrue);
      expect(ReplyTimestampParser.isTimestamp('1:02:03'), isTrue);
      expect(ReplyTimestampParser.isTimestamp('01：23'), isTrue);
      expect(ReplyTimestampParser.isTimestamp('01:23 extra'), isFalse);
      expect(
        ReplyTimestampParser.isTimestamp('http://127.0.0.1:8080'),
        isFalse,
      );
    });

    test('seekToTimestamp returns false for invalid timestamps', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(await ReplyTimestampParser.seekToTimestamp('invalid'), isFalse);
      expect(await ReplyTimestampParser.seekToTimestamp('12:60'), isFalse);
      expect(await ReplyTimestampParser.seekToTimestamp(''), isFalse);
    });

    test('splitMapJoin with timestampPattern extracts and splits cleanly', () {
      final pattern = RegExp(
        '(@someone|#topic#|${ReplyTimestampParser.timestampPattern.pattern})',
      );
      const text = '你好@someone 看01:23这里#topic#还有12：34';
      final matches = <String>[];
      final nonMatches = <String>[];

      text.splitMapJoin(
        pattern,
        onMatch: (m) {
          matches.add(m[0]!);
          return m[0]!;
        },
        onNonMatch: (nm) {
          nonMatches.add(nm);
          return nm;
        },
      );

      expect(matches, contains('@someone'));
      expect(matches, contains('01:23'));
      expect(matches, contains('#topic#'));
      expect(matches, contains('12：34'));
      expect(ReplyTimestampParser.isTimestamp('01:23'), isTrue);
      expect(ReplyTimestampParser.isTimestamp('12：34'), isTrue);
      expect(ReplyTimestampParser.isTimestamp('@someone'), isFalse);
    });

    test(
      'extractTimestamps resists chained colons in half-width and full-width',
      () {
        const chained1 = '测试12:34:56:78非法串';
        expect(ReplyTimestampParser.extractTimestamps(chained1), isEmpty);

        const chained2 = '测试12：34：56：78全角非法串';
        expect(ReplyTimestampParser.extractTimestamps(chained2), isEmpty);

        const mixed = '正常01:23与全角02：34，以及12：34：56：78';
        final res = ReplyTimestampParser.extractTimestamps(mixed);
        expect(res, contains('01:23'));
        expect(res, contains('02：34'));
        expect(res, isNot(contains('34：56')));
        expect(res.length, 2);
      },
    );
  });
}

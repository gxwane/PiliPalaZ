import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/log_sanitizer.dart';

void main() {
  test('redacts sensitive URI and cookie values', () {
    const String input =
        'https://api.bilibili.com/x/relation?access_key=secret-token&vmid=1 '
        'Cookie: SESSDATA=session-secret; bili_jct=csrf-secret';

    final String output = redactSensitiveLog(input);

    expect(output, contains('access_key=<redacted>'));
    expect(output, contains('SESSDATA=<redacted>'));
    expect(output, contains('bili_jct=<redacted>'));
    expect(output, isNot(contains('secret-token')));
    expect(output, isNot(contains('session-secret')));
    expect(output, isNot(contains('csrf-secret')));
    expect(output, contains('vmid=1'));
  });

  test(
    'redacts sensitive JSON and map fields without hiding normal fields',
    () {
      const String input =
          '{"access_token":"token-value","refresh_token":"refresh-value",'
          '"mid":7584632, csrf: csrf-value}';

      final String output = redactSensitiveLog(input);

      expect(output, contains('"access_token":"<redacted>"'));
      expect(output, contains('"refresh_token":"<redacted>"'));
      expect(output, contains('csrf: <redacted>'));
      expect(output, contains('"mid":7584632'));
      expect(output, isNot(contains('token-value')));
      expect(output, isNot(contains('refresh-value')));
      expect(output, isNot(contains('csrf-value')));
    },
  );

  test('redacts values case-insensitively', () {
    expect(
      redactSensitiveLog('ACCESS_KEY=uppercase-secret'),
      'ACCESS_KEY=<redacted>',
    );
  });
}

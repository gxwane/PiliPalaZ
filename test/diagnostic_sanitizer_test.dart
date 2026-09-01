import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/diagnostics/diagnostic_sanitizer.dart';

void main() {
  test('redacts credentials urls content ids and sandbox paths', () {
    const input =
        'Cookie: SESSDATA=session-secret; bili_jct=csrf-secret '
        'https://upos.example.com/video.m4s?token=private '
        'bvid=BV1xx411c7mD cid=123456 '
        '/data/user/0/io.github.gxwane.pilipalaz/files/private.db '
        '/private/var/mobile/Containers/Data/Application/UUID/private.db '
        '/Users/example/Library/private.db';

    final output = sanitizeDiagnosticText(input);

    expect(output, isNot(contains('session-secret')));
    expect(output, isNot(contains('csrf-secret')));
    expect(output, isNot(contains('upos.example.com')));
    expect(output, isNot(contains('BV1xx411c7mD')));
    expect(output, isNot(contains('123456')));
    expect(output, isNot(contains('private.db')));
    expect(output, isNot(contains('UUID')));
    expect(output, isNot(contains('/Users/example')));
    expect(output, contains('<redacted>'));
    expect(output, contains('<url>'));
    expect(output, contains('<content-id>'));
    expect(output, contains('<app-path>'));
  });

  test('player details keep only compatibility allowlist', () {
    final output = sanitizePlayerDetails(<String, Object?>{
      'bvid': 'BV1xx411c7mD',
      'cid': 123456,
      'videoSource': 'https://upos.example.com/video.m4s?token=private',
      'video-codec': 'hevc',
      'video-out-params/pixelformat': 'p010',
      'width': 3840,
      'height': 2160,
      'positionMs': 60000,
      'vpnActive': true,
      'error': 'Failed to open https://upos.example.com/private.m4s',
    });

    expect(output, <String, Object?>{
      'video-codec': 'hevc',
      'video-out-params/pixelformat': 'p010',
      'width': 3840,
      'height': 2160,
      'error': 'Failed to open <url>',
    });
  });

  test('caps diagnostic messages without removing the useful prefix', () {
    final output = sanitizeDiagnosticText('a' * 5000, maxLength: 64);

    expect(output, hasLength(64));
    expect(output, 'a' * 64);
  });
}

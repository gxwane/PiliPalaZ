import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/services/player_diagnostics.dart';

void main() {
  test('sanitizes media URLs before writing diagnostics', () {
    expect(
      sanitizeMediaUri(
        'https://user:secret@upos.example.com:8443/video.m4s'
        '?token=private&deadline=123',
      ),
      'https://upos.example.com:8443',
    );
  });

  test('redacts complete URLs embedded in native player messages', () {
    final redacted = redactDiagnosticText(
      'Failed to open https://upos.example.com/video.m4s?token=private',
    );

    expect(redacted, 'Failed to open https://upos.example.com');
    expect(redacted, isNot(contains('token')));
    expect(redacted, isNot(contains('video.m4s')));
  });

  test('keeps the newest diagnostic content when trimming', () {
    final content = List<String>.generate(
      20,
      (index) => 'line-$index',
    ).join('\n');

    final trimmed = trimDiagnosticContent(content, maxCharacters: 40);

    expect(trimmed.length, lessThanOrEqualTo(40));
    expect(trimmed, contains('line-19'));
    expect(trimmed, isNot(contains('line-0\n')));
  });
}

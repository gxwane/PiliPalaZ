import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/plugin/pl_player/external_audio_command.dart';

void main() {
  group('buildExternalAudioCommand', () {
    test('clears the list without opening an empty external file', () {
      expect(buildExternalAudioCommand(null, isWindows: false), <String>[
        'change-list',
        'audio-files',
        'clr',
        '',
      ]);
      expect(buildExternalAudioCommand('', isWindows: false), <String>[
        'change-list',
        'audio-files',
        'clr',
        '',
      ]);
    });

    test('sets and escapes a standalone audio source', () {
      expect(
        buildExternalAudioCommand(
          'https://example.com/audio.m4s',
          isWindows: false,
        ),
        <String>[
          'change-list',
          'audio-files',
          'set',
          r'https\://example.com/audio.m4s',
        ],
      );
      expect(
        buildExternalAudioCommand(r'C:\media\audio.m4s', isWindows: true),
        <String>['change-list', 'audio-files', 'set', r'C:\media\audio.m4s'],
      );
    });
  });
}

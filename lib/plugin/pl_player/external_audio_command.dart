List<String> buildExternalAudioCommand(
  String? audioSource, {
  required bool isWindows,
}) {
  if (audioSource?.isNotEmpty != true) {
    return <String>['change-list', 'audio-files', 'clr', ''];
  }

  final String escapedSource = isWindows
      ? audioSource!.replaceAll(';', r'\;')
      : audioSource!.replaceAll(':', r'\:');
  return <String>['change-list', 'audio-files', 'set', escapedSource];
}

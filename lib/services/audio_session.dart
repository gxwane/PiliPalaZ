import 'package:audio_session/audio_session.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';

class AudioSessionHandler implements PlaybackAudioSession {
  late final Future<AudioSession> _sessionFuture;
  bool _playInterrupted = false;

  @override
  Future<bool> setActive(bool active) async {
    final session = await _sessionFuture;
    return session.setActive(active);
  }

  AudioSessionHandler() {
    _sessionFuture = _initSession();
  }

  Future<AudioSession> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.interruptionEventStream.listen((event) {
      final playerStatus = PlPlayerController.getPlayerStatusIfExists();
      // final player = PlPlayerController.getInstance();
      if (event.begin) {
        if (playerStatus != PlayerStatus.playing) return;
        // if (!player.playerStatus.playing) return;
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.setVolumeIfExists(
                (PlPlayerController.getVolumeIfExists() ?? 0) * 0.5);
            // player.setVolume(player.volume.value * 0.5);
            break;
          case AudioInterruptionType.pause:
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
          case AudioInterruptionType.unknown:
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.setVolumeIfExists(
                (PlPlayerController.getVolumeIfExists() ?? 0) * 2);
            // player.setVolume(player.volume.value * 2);
            break;
          case AudioInterruptionType.pause:
            if (_playInterrupted) PlPlayerController.playIfExists();
              //player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
        _playInterrupted = false;
      }
    });

    // 耳机拔出暂停
    session.becomingNoisyEventStream.listen((_) {
      PlPlayerController.pauseIfExists();
      // final player = PlPlayerController.getInstance();
      // if (player.playerStatus.playing) {
      //   player.pause();
      // }
    });

    return session;
  }
}

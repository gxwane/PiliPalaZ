import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/services/pgc_playback_coordinator.dart';

void main() {
  final List<EpisodeItem> episodes = <EpisodeItem>[
    EpisodeItem(epId: 11, bvid: 'BV11', cid: 101, cover: 'one'),
    EpisodeItem(epId: 22, bvid: 'BV22', cid: 202, cover: 'two'),
  ];

  test('explicit episode has priority over progress', () {
    final EpisodeItem selected = PgcEpisodeSelector.select(
      episodes: episodes,
      explicitEpId: 11,
      progressEpId: 22,
    );
    expect(selected.epId, 11);
  });

  test('progress episode is used when no explicit episode was requested', () {
    final EpisodeItem selected = PgcEpisodeSelector.select(
      episodes: episodes,
      progressEpId: 22,
    );
    expect(selected.epId, 22);
  });

  test('first episode is the final fallback', () {
    final EpisodeItem selected = PgcEpisodeSelector.select(episodes: episodes);
    expect(selected.epId, 11);
  });

  test('a missing explicit episode is an error and never falls back', () {
    expect(
      () => PgcEpisodeSelector.select(
        episodes: episodes,
        explicitEpId: 99,
        progressEpId: 22,
      ),
      throwsA(isA<PgcEpisodeNotFoundException>()),
    );
  });

  test('an empty season cannot be played', () {
    expect(
      () => PgcEpisodeSelector.select(episodes: const <EpisodeItem>[]),
      throwsA(isA<PgcEpisodeNotFoundException>()),
    );
  });

  test('next episode navigation includes the last episode', () {
    expect(
      PgcEpisodeNavigator.nextIndex(
        episodeCount: 3,
        currentIndex: 1,
        cycle: false,
      ),
      2,
    );
  });

  test('next episode navigation stops or cycles after the last episode', () {
    expect(
      PgcEpisodeNavigator.nextIndex(
        episodeCount: 3,
        currentIndex: 2,
        cycle: false,
      ),
      isNull,
    );
    expect(
      PgcEpisodeNavigator.nextIndex(
        episodeCount: 3,
        currentIndex: 2,
        cycle: true,
      ),
      0,
    );
  });
}

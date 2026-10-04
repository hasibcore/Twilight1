import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/domain/entities/song.dart';
import 'package:melody_tube/domain/entities/playlist.dart';
import 'package:melody_tube/domain/repositories/music_repository.dart';
import 'package:melody_tube/presentation/providers/player_provider.dart';

class MockMusicRepository implements MusicRepository {
  final List<Song> recentlyPlayed = [];
  final List<Song> favorites = [];
  final List<Playlist> playlists = [];

  @override
  Future<void> addRecentlyPlayed(Song song) async {
    recentlyPlayed.removeWhere((s) => s.id == song.id);
    recentlyPlayed.insert(0, song);
  }

  @override
  Future<void> clearRecentlyPlayed() async => recentlyPlayed.clear();

  @override
  Future<List<Song>> getRecentlyPlayed() async => recentlyPlayed;

  @override
  Future<List<Song>> getFavorites() async => favorites;

  @override
  Future<bool> isFavorite(String songId) async =>
      favorites.any((s) => s.id == songId);

  @override
  Future<void> toggleFavorite(Song song) async {
    if (favorites.any((s) => s.id == song.id)) {
      favorites.removeWhere((s) => s.id == song.id);
    } else {
      favorites.add(song);
    }
  }

  @override
  Future<List<Playlist>> getUserPlaylists() async => playlists;

  @override
  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final pl = Playlist(
      id: 'pl_${playlists.length + 1}',
      title: title,
      description: description ?? '',
      thumbnailUrl: '',
      updatedAt: DateTime.now(),
    );
    playlists.add(pl);
    return pl;
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {}

  @override
  Future<void> renamePlaylist(String playlistId, String newTitle) async {}

  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {}

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {}

  @override
  Future<List<String>> getSearchHistory() async => [];

  @override
  Future<void> addSearchHistory(String query) async {}

  @override
  Future<void> clearSearchHistory() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMusicRepository mockMusicRepo;
  late PlayerProvider player;

  const songA = Song(
    id: 'song_alpha_01',
    title: 'Alpha Melody',
    artist: 'Artist Alpha',
    channelId: 'ch1',
    thumbnailUrl: 'https://example.com/a.jpg',
    durationSeconds: 200,
    durationFormatted: '03:20',
  );

  const songB = Song(
    id: 'song_beta_02',
    title: 'Beta Harmony',
    artist: 'Artist Beta',
    channelId: 'ch2',
    thumbnailUrl: 'https://example.com/b.jpg',
    durationSeconds: 180,
    durationFormatted: '03:00',
  );

  const songC = Song(
    id: 'song_gamma_03',
    title: 'Gamma Rhythm',
    artist: 'Artist Gamma',
    channelId: 'ch3',
    thumbnailUrl: 'https://example.com/c.jpg',
    durationSeconds: 240,
    durationFormatted: '04:00',
  );

  const songD = Song(
    id: 'song_delta_04',
    title: 'Delta Beat',
    artist: 'Artist Delta',
    channelId: 'ch4',
    thumbnailUrl: 'https://example.com/d.jpg',
    durationSeconds: 210,
    durationFormatted: '03:30',
  );

  setUp(() {
    mockMusicRepo = MockMusicRepository();
    player = PlayerProvider(musicRepository: mockMusicRepo);
  });

  group('Phase 2 — Song Switching & Instant UI Synchronization', () {
    test(
        'Song A -> Song B immediately switches currentSong, 0:00 position, and duration',
        () async {
      await player.playSong(songA, newQueue: [songA, songB]);
      expect(player.currentSong?.id, equals('song_alpha_01'));
      expect(player.currentIndex, equals(0));

      // Switch to songB
      final futureB = player.playSong(songB);

      // Verify synchronous state updates occurred before future completed
      expect(player.currentSong?.id, equals('song_beta_02'));
      expect(player.currentPosition, equals(Duration.zero));
      expect(player.totalDuration.inSeconds, equals(180));
      expect(player.currentIndex, equals(1));

      await futureB;
      expect(player.isPlaying, isTrue);
      expect(player.currentSong?.id, equals('song_beta_02'));
    });

    test(
        'Rapid consecutive song selection (A -> B -> C) results in final song C playing',
        () async {
      await player.playSong(songA, newQueue: [songA, songB, songC]);

      // Rapidly fire songB then songC without awaiting songB
      final futureB = player.playSong(songB);
      final futureC = player.playSong(songC);

      await Future.wait([futureB, futureC]);

      // Song C must win the race condition and be active
      expect(player.currentSong?.id, equals('song_gamma_03'));
      expect(player.currentIndex, equals(2));
      expect(player.isPlaying, isTrue);
      expect(player.errorMessage, isNull);
    });
  });

  group('Phase 6 — Queue Management & Shuffle Restoration', () {
    test('Queue maintains strict sequence A -> B -> C -> D', () async {
      await player.playSong(songA, newQueue: [songA, songB, songC, songD]);

      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.id, equals(songA.id));

      await player.next();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.id, equals(songB.id));

      await player.next();
      expect(player.currentIndex, equals(2));
      expect(player.currentSong?.id, equals(songC.id));

      await player.next();
      expect(player.currentIndex, equals(3));
      expect(player.currentSong?.id, equals(songD.id));
    });

    test(
        'toggleShuffle on shuffles queue, toggleShuffle off restores original queue sequence',
        () async {
      await player.playSong(songA, newQueue: [songA, songB, songC, songD]);

      expect(player.isShuffle, isFalse);
      expect(
          player.queue.map((s) => s.id).toList(),
          equals([
            'song_alpha_01',
            'song_beta_02',
            'song_gamma_03',
            'song_delta_04'
          ]));

      // Toggle Shuffle ON
      player.toggleShuffle();
      expect(player.isShuffle, isTrue);
      expect(player.currentSong?.id, equals(songA.id));
      expect(player.currentIndex, equals(0));

      // Toggle Shuffle OFF -> Must restore original playlist order
      player.toggleShuffle();
      expect(player.isShuffle, isFalse);
      expect(
          player.queue.map((s) => s.id).toList(),
          equals([
            'song_alpha_01',
            'song_beta_02',
            'song_gamma_03',
            'song_delta_04'
          ]));
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.id, equals(songA.id));
    });

    test(
        'removeFromQueue correctly clamps index and plays next song when current is deleted',
        () async {
      await player.playSong(songA, newQueue: [songA, songB, songC]);
      expect(player.currentIndex, equals(0));

      // Delete the currently playing song (index 0)
      await player.removeFromQueue(0);

      expect(player.queue.length, equals(2));
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.id, equals('song_beta_02'));
    });
  });

  group('Phase 7 — Auto Next & Double-Trigger Prevention', () {
    test('Concurrent onTrackEnded calls only advance to next song once',
        () async {
      await player.playSong(songA, newQueue: [songA, songB, songC]);
      expect(player.currentIndex, equals(0));

      // Fire onTrackEnded concurrently twice
      await Future.wait([
        player.onTrackEnded(),
        player.onTrackEnded(),
      ]);

      // Must have advanced only ONCE to song B, never skipping to song C
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.id, equals('song_beta_02'));
    });

    test(
        'previous() restarts track if position > 3s, or goes to previous if position <= 3s',
        () async {
      await player.playSong(songB, newQueue: [songA, songB, songC]);
      expect(player.currentIndex, equals(1));

      // 1. Position > 3s -> Should restart current track
      player.seekTo(const Duration(seconds: 15));
      expect(player.currentPosition.inSeconds, equals(15));

      await player.previous();
      expect(player.currentIndex, equals(1));
      expect(player.currentSong?.id, equals('song_beta_02'));
      expect(player.currentPosition, equals(Duration.zero));

      // 2. Position <= 3s -> Should navigate to previous track (songA)
      await player.previous();
      expect(player.currentIndex, equals(0));
      expect(player.currentSong?.id, equals('song_alpha_01'));
    });

    test(
        'seekTo clamps negative positions and positions exceeding totalDuration',
        () async {
      await player.playSong(songA);
      final total = player.totalDuration;
      expect(total.inSeconds, greaterThan(0));

      // Negative seek -> Clamped to Duration.zero
      player.seekTo(const Duration(seconds: -10));
      expect(player.currentPosition, equals(Duration.zero));

      // Over seek -> Clamped to totalDuration
      player.seekTo(Duration(seconds: total.inSeconds + 500));
      expect(player.currentPosition, equals(total));
    });

    test('Queue addition during shuffle keeps unshuffled queue synchronized',
        () async {
      await player.playSong(songA, newQueue: [songA, songB]);
      player.toggleShuffle();
      expect(player.isShuffle, isTrue);

      // Add song C while shuffled
      player.addToQueue(songC);
      expect(player.queue.any((s) => s.id == songC.id), isTrue);

      // Toggle shuffle off -> Song C must still exist in restored queue
      player.toggleShuffle();
      expect(player.isShuffle, isFalse);
      expect(player.queue.any((s) => s.id == songC.id), isTrue);
      expect(player.queue.length, equals(3));
    });
  });
}

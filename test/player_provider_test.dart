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
  Future<void> clearRecentlyPlayed() async {
    recentlyPlayed.clear();
  }

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
  late PlayerProvider playerProvider;

  const songA = Song(
    id: 'dQw4w9WgXcQ',
    title: 'Song Alpha',
    artist: 'Artist One',
    channelId: 'ch1',
    thumbnailUrl: 'https://example.com/1.jpg',
    durationSeconds: 212,
    durationFormatted: '03:32',
  );

  const songB = Song(
    id: 'kXYiU_JCYtU',
    title: 'Song Beta',
    artist: 'Artist Two',
    channelId: 'ch2',
    thumbnailUrl: 'https://example.com/2.jpg',
    durationSeconds: 180,
    durationFormatted: '03:00',
  );

  setUp(() {
    mockMusicRepo = MockMusicRepository();
    playerProvider = PlayerProvider(musicRepository: mockMusicRepo);
  });

  group('PlayerProvider Single-Track Integrity Tests', () {
    test('playSong sets currentSong accurately and avoids song mismatches',
        () async {
      await playerProvider.playSong(songA, newQueue: [songA, songB]);

      expect(playerProvider.currentSong?.id, equals('dQw4w9WgXcQ'));
      expect(playerProvider.currentSong?.title, equals('Song Alpha'));
      expect(playerProvider.currentIndex, equals(0));
      expect(playerProvider.queue.length, equals(2));

      // Selecting Song B immediately switches currentSong to Song B
      await playerProvider.playSong(songB);

      expect(playerProvider.currentSong?.id, equals('kXYiU_JCYtU'));
      expect(playerProvider.currentSong?.title, equals('Song Beta'));
      expect(playerProvider.currentIndex, equals(1));
    });

    test('playSong sanitizes full YouTube URLs into clean 11-char video IDs',
        () async {
      const urlSong = Song(
        id: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'Rickroll',
        artist: 'Rick Astley',
        channelId: 'ch_rick',
        thumbnailUrl: '',
        durationSeconds: 212,
        durationFormatted: '03:32',
      );

      await playerProvider.playSong(urlSong);

      // Clean ID extracted without query params or URL prefix
      expect(playerProvider.currentSong?.id, equals('dQw4w9WgXcQ'));
      expect(playerProvider.currentSong?.title, equals('Rickroll'));
    });

    test('Queue operations preserve correct current song and index', () async {
      await playerProvider.playSong(songA, newQueue: [songA, songB]);

      const songC = Song(
        id: '9bZkp7q19f0',
        title: 'Song Gamma',
        artist: 'Artist Three',
        channelId: 'ch3',
        thumbnailUrl: '',
        durationSeconds: 250,
        durationFormatted: '04:10',
      );

      playerProvider.addToQueue(songC);
      expect(playerProvider.queue.length, equals(3));
      expect(playerProvider.upNextQueue.length, equals(2));

      // Reorder items
      playerProvider.reorderItem(2, 1);
      expect(playerProvider.queue[1].id, equals('9bZkp7q19f0'));
      expect(playerProvider.currentIndex, equals(0));
    });

    test('Autoplay defaults to enabled and can be toggled', () {
      expect(playerProvider.isAutoplay, isTrue);

      playerProvider.toggleAutoplay();
      expect(playerProvider.isAutoplay, isFalse);

      playerProvider.toggleAutoplay(value: true);
      expect(playerProvider.isAutoplay, isTrue);
    });

    test('Autoplay continues playback when queue ends', () async {
      await playerProvider.playSong(songA, newQueue: [songA]);
      expect(playerProvider.currentIndex, equals(0));

      playerProvider.toggleAutoplay(value: true);
      await playerProvider.next();

      // Current song remains playing (loops or expands queue)
      expect(playerProvider.isPlaying, isTrue);
      expect(playerProvider.currentSong, isNotNull);
    });

    test(
        'Next song starts playback without premature pause state and pauses when pause() is called',
        () async {
      await playerProvider.playSong(songA, newQueue: [songA, songB]);
      expect(playerProvider.isPlaying, isTrue);
      expect(playerProvider.currentIndex, equals(0));

      // Trigger next song
      await playerProvider.next();

      expect(playerProvider.currentIndex, equals(1));
      expect(playerProvider.currentSong?.id, equals(songB.id));
      expect(playerProvider.isPlaying, isTrue);
      expect(playerProvider.errorMessage, isNull);

      // Now pause explicitly
      playerProvider.pause();
      expect(playerProvider.isPlaying, isFalse);

      // Resume — play() is void async, pump microtasks to let _isPlaying update
      playerProvider.play();
      // In test env _audioPlayer?.play() is a no-op (null-safety), so isPlaying
      // is set synchronously in the try-success path after the null-await resolves.
      await Future<void>.delayed(Duration.zero);
      expect(playerProvider.isPlaying, isTrue);
      expect(playerProvider.errorMessage, isNull);
    });
  });
}

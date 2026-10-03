import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:melody_tube/core/services/artwork_service.dart';
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
  Future<bool> isFavorite(String songId) async => favorites.any((s) => s.id == songId);

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

  group('Background Playback Architecture & Configuration Tests', () {
    test('Android Manifest specifies all mandatory background media playback permissions', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      // Core background playback permissions
      expect(content, contains('android.permission.WAKE_LOCK'),
          reason: 'WAKE_LOCK is required to prevent CPU sleep during background playback');
      expect(content, contains('android.permission.FOREGROUND_SERVICE'),
          reason: 'FOREGROUND_SERVICE is required for continuous audio service');
      expect(content, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
          reason: 'FOREGROUND_SERVICE_MEDIA_PLAYBACK is required on Android 14+ (API 34+)');
      expect(content, contains('android.permission.POST_NOTIFICATIONS'),
          reason: 'POST_NOTIFICATIONS is required on Android 13+ (API 33+) for lockscreen controls');

      // AudioService and MediaBrowserService declaration
      expect(content, contains('com.ryanheise.audioservice.AudioService'),
          reason: 'AudioService must be declared in AndroidManifest');
      expect(content, contains('android:foregroundServiceType="mediaPlayback"'),
          reason: 'foregroundServiceType mediaPlayback is mandatory for Android 14+ background services');
      expect(content, contains('com.ryanheise.audioservice.MediaButtonReceiver'),
          reason: 'MediaButtonReceiver is required for headset / bluetooth controls');
    });

    test('Android status bar notification icon exists and is a valid XML vector drawable', () {
      final iconFile = File('android/app/src/main/res/drawable/ic_stat_music.xml');
      expect(iconFile.existsSync(), isTrue, reason: 'ic_stat_music.xml must exist in res/drawable/');

      final iconContent = iconFile.readAsStringSync();
      expect(iconContent, contains('<vector'), reason: 'Icon must be a vector drawable');
      expect(iconContent, contains('android:viewportWidth="24"'));
    });

    test('iOS Info.plist configures background audio processing mode', () {
      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue, reason: 'Info.plist must exist');

      final content = plistFile.readAsStringSync();
      expect(content, contains('<key>UIBackgroundModes</key>'),
          reason: 'UIBackgroundModes must be defined');
      expect(content, contains('<string>audio</string>'),
          reason: 'audio background mode is mandatory for iOS background playback');
    });

    test('MediaItem tag structures comply with just_audio_background requirements', () {
      const song = Song(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        channelId: 'ch_rick',
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        durationSeconds: 212,
        durationFormatted: '03:32',
      );

      final mediaItem = MediaItem(
        id: song.id,
        album: 'Twilight Music',
        title: song.title,
        artist: song.artist,
        artUri: Uri.parse(song.thumbnailUrl),
        duration: Duration(seconds: song.durationSeconds),
      );

      expect(mediaItem.id, equals('dQw4w9WgXcQ'));
      expect(mediaItem.title, equals('Never Gonna Give You Up'));
      expect(mediaItem.artist, equals('Rick Astley'));
      expect(mediaItem.album, equals('Twilight Music'));
      expect(mediaItem.artUri?.scheme, equals('https'));
      expect(mediaItem.duration?.inSeconds, equals(212));
    });

    test('ArtworkService generates valid fallback URI for background lockscreen art', () async {
      final uri = await ArtworkService.getArtworkUri(
        thumbnailUrl: 'https://i.ytimg.com/vi/test/hqdefault.jpg',
        songId: 'test_song',
      );

      expect(uri, isNotNull);
      expect(uri.toString().isNotEmpty, isTrue);
    });
  });

  group('PlayerProvider Background Playback Controls & Lifecycle Tests', () {
    late MockMusicRepository mockMusicRepo;
    late PlayerProvider playerProvider;

    const track1 = Song(
      id: 'song_bg_1',
      title: 'Background Symphony 1',
      artist: 'Ambient Artist',
      channelId: 'ch_1',
      thumbnailUrl: 'https://example.com/1.jpg',
      durationSeconds: 200,
      durationFormatted: '03:20',
    );

    const track2 = Song(
      id: 'song_bg_2',
      title: 'Background Symphony 2',
      artist: 'Ambient Artist',
      channelId: 'ch_2',
      thumbnailUrl: 'https://example.com/2.jpg',
      durationSeconds: 180,
      durationFormatted: '03:00',
    );

    setUp(() {
      mockMusicRepo = MockMusicRepository();
      playerProvider = PlayerProvider(musicRepository: mockMusicRepo);
    });

    test('playSong initializes background-ready state', () async {
      await playerProvider.playSong(track1, newQueue: [track1, track2]);

      expect(playerProvider.currentSong?.id, equals('song_bg_1'));
      expect(playerProvider.isPlaying, isTrue);
      expect(playerProvider.isLoading, isFalse);
      expect(playerProvider.totalDuration.inSeconds, equals(200));
    });

    test('togglePlayPause cleanly pauses and resumes playback', () async {
      await playerProvider.playSong(track1, newQueue: [track1, track2]);
      expect(playerProvider.isPlaying, isTrue);

      playerProvider.togglePlayPause();
      expect(playerProvider.isPlaying, isFalse);

      playerProvider.togglePlayPause();
      expect(playerProvider.isPlaying, isTrue);
    });

    test('onTrackEnded automatically advances to next track in queue', () async {
      await playerProvider.playSong(track1, newQueue: [track1, track2]);
      expect(playerProvider.currentIndex, equals(0));

      await playerProvider.onTrackEnded();

      expect(playerProvider.currentIndex, equals(1));
      expect(playerProvider.currentSong?.id, equals('song_bg_2'));
      expect(playerProvider.isPlaying, isTrue);
    });

    test('onTrackEnded repeats same track when repeat mode is enabled', () async {
      await playerProvider.playSong(track1, newQueue: [track1, track2]);
      playerProvider.toggleRepeat();
      expect(playerProvider.isRepeat, isTrue);

      await playerProvider.onTrackEnded();

      expect(playerProvider.currentIndex, equals(0));
      expect(playerProvider.currentSong?.id, equals('song_bg_1'));
      expect(playerProvider.currentPosition, equals(Duration.zero));
    });

    test('Continuous autoplay ensures playback does not terminate when queue exhausts', () async {
      await playerProvider.playSong(track1, newQueue: [track1]);
      expect(playerProvider.currentIndex, equals(0));
      playerProvider.toggleAutoplay(value: true);

      await playerProvider.next();

      expect(playerProvider.isPlaying, isTrue);
      expect(playerProvider.currentSong, isNotNull);
    });
  });
}

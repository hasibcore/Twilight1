import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/data/models/song_model.dart';
import 'package:melody_tube/data/models/playlist_model.dart';
import 'package:melody_tube/core/services/download_service.dart';
import 'package:melody_tube/core/services/music_import_service.dart';
import 'package:melody_tube/presentation/providers/player_provider.dart';
import 'package:melody_tube/domain/entities/song.dart';
import 'package:melody_tube/domain/entities/playlist.dart';
import 'package:melody_tube/domain/repositories/music_repository.dart';

class TestMockMusicRepository implements MusicRepository {
  @override
  Future<void> addRecentlyPlayed(Song song) async {}

  @override
  Future<void> clearRecentlyPlayed() async {}

  @override
  Future<List<Song>> getRecentlyPlayed() async => [];

  @override
  Future<List<Song>> getFavorites() async => [];

  @override
  Future<bool> isFavorite(String songId) async => false;

  @override
  Future<void> toggleFavorite(Song song) async {}

  @override
  Future<List<Playlist>> getUserPlaylists() async => [];

  @override
  Future<Playlist> createPlaylist(String title, {String? description}) async {
    return Playlist(
      id: 'pl_1',
      title: title,
      description: description ?? '',
      thumbnailUrl: '',
      songs: [],
      isUserCreated: true,
      updatedAt: DateTime.now(),
    );
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

  group('Robustness & Bug Hardening Tests', () {
    test(
        'SongModel.fromJson safely handles doubles, strings, and missing fields without casting errors',
        () {
      final json = {
        'id': 'abc12345678',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'channelId': 'channel_1',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'durationSeconds': 210.5, // double instead of int
        'durationFormatted': '03:30',
        'viewCount': 1000.0, // double instead of int
        'publishedAt': '2026-09-26T12:00:00Z',
        'isFavorite': true,
      };

      final song = SongModel.fromJson(json);
      expect(song.id, 'abc12345678');
      expect(song.durationSeconds, 210);
      expect(song.viewCount, 1000);
      expect(song.publishedAt, isNotNull);
      expect(song.isFavorite, isTrue);
    });

    test(
        'PlaylistModel.fromJson safely filters corrupted or non-map entries without crashing',
        () {
      final json = {
        'id': 'pl_test',
        'title': 'My Playlist',
        'description': 'A safe playlist',
        'thumbnailUrl': '',
        'songs': [
          {'id': 'song_1', 'title': 'Valid Song 1', 'artist': 'Artist 1'},
          'corrupted_string_entry', // invalid type
          null, // null entry
          42, // integer entry
          {'id': 'song_2', 'title': 'Valid Song 2', 'artist': 'Artist 2'},
        ],
        'isUserCreated': true,
        'updatedAt': '2026-09-26T12:00:00Z',
      };

      final playlist = PlaylistModel.fromJson(json);
      expect(playlist.id, 'pl_test');
      expect(playlist.songs.length, 2);
      expect(playlist.songs[0].id, 'song_1');
      expect(playlist.songs[1].id, 'song_2');
    });

    test(
        'DownloadItem.fromJson safely handles malformed nested song and double numbers',
        () {
      final json = {
        'song': {
          'id': 'dl_1',
          'title': 'Downloaded Track',
          'durationSeconds': 180.0
        },
        'localFilePath': '/data/user/0/app/track.m4a',
        'localThumbnailPath': null,
        'downloadedAtMillis': 1727337600000.0, // double instead of int
        'fileSize': 5242880.0, // double instead of int
      };

      final item = DownloadItem.fromJson(json);
      expect(item.song.id, 'dl_1');
      expect(item.fileSize, 5242880);
      expect(item.downloadedAtMillis, 1727337600000);
    });

    test(
        'PlayerProvider reorderItem clamps targetIndex when reordering to list end without RangeError',
        () {
      final mockRepo = TestMockMusicRepository();
      final player = PlayerProvider(musicRepository: mockRepo);
      const s1 = Song(
          id: 's1',
          title: 'Song 1',
          artist: 'A1',
          channelId: 'c1',
          thumbnailUrl: '',
          durationSeconds: 100,
          durationFormatted: '01:40');
      const s2 = Song(
          id: 's2',
          title: 'Song 2',
          artist: 'A2',
          channelId: 'c2',
          thumbnailUrl: '',
          durationSeconds: 200,
          durationFormatted: '03:20');
      const s3 = Song(
          id: 's3',
          title: 'Song 3',
          artist: 'A3',
          channelId: 'c3',
          thumbnailUrl: '',
          durationSeconds: 300,
          durationFormatted: '05:00');

      player.addToQueue(s1);
      player.addToQueue(s2);
      player.addToQueue(s3);

      expect(player.queue.length, 3);

      // In Flutter ReorderableListView, dragging item 0 to the bottom passes newIndex = 3 (queue length)
      expect(() => player.reorderItem(0, 3), returnsNormally);
      expect(player.queue.last.id, 's1');
      expect(player.queue.first.id, 's2');
    });

    test('MusicImportService recognizes YouTube shorts and embed URLs', () {
      final service = MusicImportService();
      expect(service.isYouTubeUrl('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
          isTrue);
      expect(service.isYouTubeUrl('https://www.youtube.com/embed/dQw4w9WgXcQ'),
          isTrue);
      expect(service.isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(service.isSupportedUrl('https://open.spotify.com/track/12345'),
          isTrue);
    });

    test(
        'PlayerProvider playSong with queueIndex selects exact index even with duplicate songs',
        () async {
      final mockRepo = TestMockMusicRepository();
      final player = PlayerProvider(musicRepository: mockRepo);
      const s1 = Song(
          id: 's_dup',
          title: 'Dup Song',
          artist: 'Artist',
          channelId: 'c1',
          thumbnailUrl: '',
          durationSeconds: 120,
          durationFormatted: '02:00');
      const s2 = Song(
          id: 's_other',
          title: 'Other Song',
          artist: 'Artist',
          channelId: 'c2',
          thumbnailUrl: '',
          durationSeconds: 150,
          durationFormatted: '02:30');
      const s3 = Song(
          id: 's_dup',
          title: 'Dup Song',
          artist: 'Artist',
          channelId: 'c1',
          thumbnailUrl: '',
          durationSeconds: 120,
          durationFormatted: '02:00');

      await player.playSong(s1, newQueue: [s1, s2, s3], queueIndex: 2);
      expect(player.currentIndex, 2);
    });

    test('PlayerProvider reorderItem properly drops items between other items',
        () {
      final mockRepo = TestMockMusicRepository();
      final player = PlayerProvider(musicRepository: mockRepo);
      const s1 = Song(
          id: 's1',
          title: 'Song 1',
          artist: 'A1',
          channelId: 'c1',
          thumbnailUrl: '',
          durationSeconds: 100,
          durationFormatted: '01:40');
      const s2 = Song(
          id: 's2',
          title: 'Song 2',
          artist: 'A2',
          channelId: 'c2',
          thumbnailUrl: '',
          durationSeconds: 200,
          durationFormatted: '03:20');
      const s3 = Song(
          id: 's3',
          title: 'Song 3',
          artist: 'A3',
          channelId: 'c3',
          thumbnailUrl: '',
          durationSeconds: 300,
          durationFormatted: '05:00');

      player.addToQueue(s1);
      player.addToQueue(s2);
      player.addToQueue(s3);

      // Drag item 0 to after item 1 (Flutter passes newIndex = 2)
      player.reorderItem(0, 2);
      expect(player.queue[0].id, 's2');
      expect(player.queue[1].id, 's1');
      expect(player.queue[2].id, 's3');
    });
  });
}

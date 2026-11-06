import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/core/utils/formatters.dart';
import 'package:melody_tube/data/models/playlist_model.dart';
import 'package:melody_tube/data/models/search_result_model.dart';
import 'package:melody_tube/data/models/song_model.dart';
import 'package:melody_tube/presentation/widgets/error_view_widget.dart';
import 'package:melody_tube/core/services/music_import_service.dart';

void main() {
  group('Formatters Tests', () {
    test('Formats duration correctly for mm:ss and hh:mm:ss', () {
      expect(Formatters.formatDuration(const Duration(minutes: 3, seconds: 45)), '03:45');
      expect(Formatters.formatDuration(const Duration(seconds: 9)), '00:09');
      expect(Formatters.formatDuration(const Duration(hours: 1, minutes: 23, seconds: 45)), '1:23:45');
    });

    test('Formats integer seconds correctly', () {
      expect(Formatters.formatSeconds(195), '03:15');
      expect(Formatters.formatSeconds(0), '00:00');
    });

    test('Formats views cleanly with K, M, B abbreviations', () {
      expect(Formatters.formatViews(500), '500');
      expect(Formatters.formatViews(1500), '1.5K');
      expect(Formatters.formatViews(2500000), '2.5M');
      expect(Formatters.formatViews(1200000000), '1.2B');
    });
  });

  group('PlaylistModel Tests', () {
    test('Calculates song count and serializes accurately', () {
      final now = DateTime.now();
      const song = SongModel(
        id: 's1',
        title: 'Song 1',
        artist: 'Artist 1',
        channelId: 'ch1',
        thumbnailUrl: 'https://example.com/s1.jpg',
        durationSeconds: 180,
        durationFormatted: '03:00',
      );

      final playlist = PlaylistModel(
        id: 'pl_test',
        title: 'Chill Acoustic',
        description: 'Acoustic songs collection',
        thumbnailUrl: 'https://example.com/pl.jpg',
        songs: [song],
        isUserCreated: true,
        updatedAt: now,
      );

      expect(playlist.songs.length, 1);
      final json = playlist.toJson();
      expect(json['id'], 'pl_test');
      expect(json['title'], 'Chill Acoustic');
      expect((json['songs'] as List).length, 1);

      final restored = PlaylistModel.fromJson(json);
      expect(restored.id, 'pl_test');
      expect(restored.songs.length, 1);
      expect(restored.songs.first.title, 'Song 1');
    });
  });

  group('SearchResultModel Tests', () {
    test('Initializes with empty lists correctly', () {
      const empty = SearchResultModel(
        songs: [],
        videos: [],
        artists: [],
        playlists: [],
      );

      expect(empty.songs, isEmpty);
      expect(empty.videos, isEmpty);
      expect(empty.artists, isEmpty);
      expect(empty.playlists, isEmpty);

      final entity = empty.toEntity();
      expect(entity.songs, isEmpty);
      expect(entity.artists, isEmpty);
      expect(entity.playlists, isEmpty);
    });
  });

  group('ErrorViewWidget Tests', () {
    testWidgets('Renders message and triggers onRetry callback', (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorViewWidget(
              message: 'Failed to load live music stream',
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Failed to load live music stream'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(retried, isTrue);
    });
  });

  group('MusicImportService Tests', () {
    test('Correctly identifies Spotify and YouTube URLs', () {
      final service = MusicImportService();
      expect(service.isSpotifyUrl('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'), isTrue);
      expect(service.isSpotifyUrl('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'), isTrue);
      expect(service.isSpotifyUrl('https://spotify.link/abc123xyz'), isTrue);
      expect(service.isSpotifyUrl('https://soundcloud.com/track'), isFalse);

      expect(service.isYouTubeUrl('https://www.youtube.com/watch?v=J7s72-X-VyM'), isTrue);
      expect(service.isYouTubeUrl('https://youtu.be/J7s72-X-VyM'), isTrue);
      expect(service.isYouTubeUrl('https://youtube.com/playlist?list=PL12345'), isTrue);
      expect(service.isYouTubeUrl('https://open.spotify.com/track/123'), isFalse);

      expect(service.isSupportedUrl('https://open.spotify.com/track/123'), isTrue);
      expect(service.isSupportedUrl('https://youtu.be/J7s72-X-VyM'), isTrue);
      expect(service.isSupportedUrl('random search query'), isFalse);
    });
  });
}

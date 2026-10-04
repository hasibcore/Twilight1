import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/core/services/music_import_service.dart';

void main() {
  group('MusicImportService URL Tests', () {
    final service = MusicImportService();

    test('Identifies Spotify track, playlist, and album URLs', () {
      expect(
          service.isSpotifyUrl(
              'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'),
          isTrue);
      expect(
          service.isSpotifyUrl(
              'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'),
          isTrue);
      expect(
          service.isSpotifyUrl(
              'https://open.spotify.com/album/1DFixLWuPkv3KT3TnV35m3'),
          isTrue);
      expect(service.isSpotifyUrl('https://spotify.link/xyz123'), isTrue);
      expect(service.isSpotifyUrl('https://youtube.com/watch?v=dQw4w9WgXcQ'),
          isFalse);
    });

    test('Identifies YouTube video and playlist URLs', () {
      expect(
          service.isYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          isTrue);
      expect(service.isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(
          service.isYouTubeUrl(
              'https://www.youtube.com/playlist?list=PL4fGSI1pDJn6jXS_PEoNcnwDX3082a9x_'),
          isTrue);
      expect(
          service.isYouTubeUrl('https://open.spotify.com/track/123'), isFalse);
    });

    test('Identifies any supported universal music URL', () {
      expect(
          service.isSupportedUrl(
              'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'),
          isTrue);
      expect(
          service.isSupportedUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          isTrue);
      expect(service.isSupportedUrl('https://randomwebsite.com/audio.mp3'),
          isFalse);
    });
  });
}

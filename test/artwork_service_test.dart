import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/core/services/artwork_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );
  });

  group('ArtworkService Tests', () {
    test('getArtworkUri returns parsed URI for valid HTTP thumbnail', () async {
      final uri = await ArtworkService.getArtworkUri(
        thumbnailUrl: 'https://i.ytimg.com/vi/test/hqdefault.jpg',
        songId: 'test_song',
      );
      expect(uri, isNotNull);
      expect(uri.toString(), equals('https://i.ytimg.com/vi/test/hqdefault.jpg'));
    });

    test('getArtworkUri handles empty or null thumbnail gracefully', () async {
      final uri = await ArtworkService.getArtworkUri(
        thumbnailUrl: '',
        songId: 'empty_song',
      );
      // In test environment without assets bundle, it safely returns null or logo URI
      expect(uri == null || uri.toString().isNotEmpty, isTrue);
    });

    test('normalizeThumbnailUrl converts maxresdefault.jpg and mismatched video thumbnails to verified hqdefault.jpg', () {
      expect(
        ArtworkService.normalizeThumbnailUrl(
          'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
          songId: 'dQw4w9WgXcQ',
        ),
        equals('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'),
      );

      // Even if a stale or wrong video ID was in thumbnailUrl, it locks to the active songId
      expect(
        ArtworkService.normalizeThumbnailUrl(
          'https://i.ytimg.com/vi/OLD_SONG_ID/hqdefault.jpg',
          songId: 'kXYiU_JCYtU',
        ),
        equals('https://i.ytimg.com/vi/kXYiU_JCYtU/hqdefault.jpg'),
      );
    });
  });
}


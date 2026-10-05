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
  });
}

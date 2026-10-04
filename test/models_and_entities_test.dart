import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/core/services/audio_stream_extractor.dart';
import 'package:melody_tube/core/services/download_service.dart';
import 'package:melody_tube/data/models/song_model.dart';

void main() {
  group('SongModel Tests', () {
    test('Correctly deserializes from Map JSON', () {
      final json = {
        'id': 'test1234',
        'title': 'Twilight Serenade',
        'artist': 'Night Musician',
        'channelId': 'ch_twilight',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'durationSeconds': 215,
        'durationFormatted': '03:35',
        'viewCount': 1000000,
      };

      final song = SongModel.fromJson(json);

      expect(song.id, 'test1234');
      expect(song.title, 'Twilight Serenade');
      expect(song.artist, 'Night Musician');
      expect(song.channelId, 'ch_twilight');
      expect(song.durationSeconds, 215);
      expect(song.durationFormatted, '03:35');
    });

    test('Correctly serializes to Map JSON and back', () {
      const song = SongModel(
        id: 'twilight_01',
        title: 'Aurora',
        artist: 'Harmonics',
        channelId: 'ch_harmonics',
        thumbnailUrl: 'https://example.com/aurora.jpg',
        durationSeconds: 180,
        durationFormatted: '03:00',
      );

      final json = song.toJson();

      expect(json['id'], 'twilight_01');
      expect(json['title'], 'Aurora');
      expect(json['artist'], 'Harmonics');
      expect(json['channelId'], 'ch_harmonics');
      expect(json['durationSeconds'], 180);

      final entity = song.toEntity();
      expect(entity.id, 'twilight_01');
      expect(entity.title, 'Aurora');
    });
  });

  group('DownloadItem Tests', () {
    final song = const SongModel(
      id: 'song_dl_1',
      title: 'Midnight Echo',
      artist: 'Sonic Studio',
      channelId: 'ch_sonic',
      thumbnailUrl: 'https://example.com/midnight.jpg',
      durationSeconds: 240,
      durationFormatted: '04:00',
    ).toEntity();

    test('Initializes with required fields and paths', () {
      final item = DownloadItem(
        song: song,
        localFilePath: '/storage/music/song_dl_1.m4a',
        localThumbnailPath: '/storage/music/song_dl_1.jpg',
        downloadedAtMillis: 1774483200000,
        fileSize: 4449529,
      );

      expect(item.song.id, 'song_dl_1');
      expect(item.localFilePath, '/storage/music/song_dl_1.m4a');
      expect(item.localThumbnailPath, '/storage/music/song_dl_1.jpg');
      expect(item.fileSize, 4449529);
      expect(item.downloadedAtMillis, 1774483200000);
    });

    test('Serializes and deserializes correctly via JSON', () {
      final original = DownloadItem(
        song: song,
        localFilePath: '/storage/music/song_dl_1.m4a',
        localThumbnailPath: '/storage/music/song_dl_1.jpg',
        downloadedAtMillis: 1774483200000,
        fileSize: 4449529,
      );

      final json = original.toJson();
      final restored = DownloadItem.fromJson(json);

      expect(restored.song.id, original.song.id);
      expect(restored.song.title, original.song.title);
      expect(restored.localFilePath, original.localFilePath);
      expect(restored.localThumbnailPath, original.localThumbnailPath);
      expect(restored.fileSize, original.fileSize);
      expect(restored.downloadedAtMillis, original.downloadedAtMillis);
    });
  });

  group('AudioStreamResult Tests', () {
    test(
        'Stores tier, URL, totalBytes, bitrate and direct download flags accurately',
        () {
      final stream = AudioStreamResult(
        url: 'https://inv.nadeko.net/stream/audio.m4a',
        totalBytes: 4449529,
        mimeType: 'audio/mp4',
        bitrate: 131072,
        headers: {'User-Agent': 'Twilight/1.0'},
        isDirectDownloadable: true,
      );

      expect(stream.url, contains('inv.nadeko.net'));
      expect(stream.totalBytes, 4449529);
      expect(stream.mimeType, 'audio/mp4');
      expect(stream.bitrate, 131072);
      expect(stream.isDirectDownloadable, isTrue);
      expect(stream.headers['User-Agent'], 'Twilight/1.0');
    });
  });
}

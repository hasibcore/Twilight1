import '../../domain/entities/song.dart';
import '../../core/utils/formatters.dart';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String channelId;
  final String thumbnailUrl;
  final int durationSeconds;
  final String durationFormatted;
  final int viewCount;
  final DateTime? publishedAt;
  final bool isFavorite;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.channelId,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.durationFormatted,
    this.viewCount = 0,
    this.publishedAt,
    this.isFavorite = false,
  });

  Song toEntity() {
    return Song(
      id: id,
      title: title,
      artist: artist,
      channelId: channelId,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      durationFormatted: durationFormatted,
      viewCount: viewCount,
      publishedAt: publishedAt,
      isFavorite: isFavorite,
    );
  }

  factory SongModel.fromEntity(Song entity) {
    return SongModel(
      id: entity.id,
      title: entity.title,
      artist: entity.artist,
      channelId: entity.channelId,
      thumbnailUrl: entity.thumbnailUrl,
      durationSeconds: entity.durationSeconds,
      durationFormatted: entity.durationFormatted,
      viewCount: entity.viewCount,
      publishedAt: entity.publishedAt,
      isFavorite: entity.isFavorite,
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      channelId: json['channelId'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      durationFormatted: json['durationFormatted'] as String? ?? '00:00',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'channelId': channelId,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'durationFormatted': durationFormatted,
      'viewCount': viewCount,
      'publishedAt': publishedAt?.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  /// Parses YouTube Data API v3 video item
  factory SongModel.fromYouTubeJson(Map<String, dynamic> item) {
    String videoId = '';
    final idField = item['id'];
    if (idField is Map) {
      videoId = idField['videoId'] as String? ?? '';
    } else if (idField is String) {
      videoId = idField;
    }

    final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
    final title = snippet['title'] as String? ?? 'Unknown Song';
    final artist = snippet['channelTitle'] as String? ?? 'Unknown Artist';
    final channelId = snippet['channelId'] as String? ?? '';

    // Extract best available thumbnail
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
    String thumb = '';
    if (thumbnails['maxres'] != null) {
      thumb = thumbnails['maxres']['url'] as String? ?? '';
    } else if (thumbnails['high'] != null) {
      thumb = thumbnails['high']['url'] as String? ?? '';
    } else if (thumbnails['medium'] != null) {
      thumb = thumbnails['medium']['url'] as String? ?? '';
    } else if (thumbnails['default'] != null) {
      thumb = thumbnails['default']['url'] as String? ?? '';
    }

    // Parse ISO 8601 duration (e.g. PT3M45S)
    int durationSecs = 210; // Default fallback 3m30s
    final contentDetails = item['contentDetails'] as Map<String, dynamic>?;
    if (contentDetails != null && contentDetails['duration'] != null) {
      durationSecs = _parseIsoDuration(contentDetails['duration'] as String);
    }

    final statistics = item['statistics'] as Map<String, dynamic>?;
    int views = 0;
    if (statistics != null && statistics['viewCount'] != null) {
      views = int.tryParse(statistics['viewCount'].toString()) ?? 0;
    }

    return SongModel(
      id: videoId,
      title: title,
      artist: artist,
      channelId: channelId,
      thumbnailUrl: thumb.isNotEmpty
          ? thumb
          : (videoId.isNotEmpty ? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg' : ''),
      durationSeconds: durationSecs,
      durationFormatted: Formatters.formatSeconds(durationSecs),
      viewCount: views,
      publishedAt: snippet['publishedAt'] != null
          ? DateTime.tryParse(snippet['publishedAt'] as String)
          : null,
      isFavorite: false,
    );
  }

  static int _parseIsoDuration(String isoDuration) {
    try {
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(isoDuration);
      if (match != null) {
        final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        return (hours * 3600) + (minutes * 60) + seconds;
      }
    } catch (_) {}
    return 180;
  }
}

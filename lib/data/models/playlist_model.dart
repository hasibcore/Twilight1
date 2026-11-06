import '../../domain/entities/playlist.dart';
import 'song_model.dart';

class PlaylistModel {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final List<SongModel> songs;
  final bool isUserCreated;
  final DateTime updatedAt;

  const PlaylistModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.thumbnailUrl,
    this.songs = const [],
    this.isUserCreated = false,
    required this.updatedAt,
  });

  Playlist toEntity() {
    final entities = songs.map((s) => s.toEntity()).toList();
    final effectiveThumb = thumbnailUrl.trim().isNotEmpty
        ? thumbnailUrl.trim()
        : (entities.isNotEmpty ? entities.first.thumbnailUrl : '');
    return Playlist(
      id: id,
      title: title,
      description: description,
      thumbnailUrl: effectiveThumb,
      songs: entities,
      isUserCreated: isUserCreated,
      updatedAt: updatedAt,
    );
  }

  factory PlaylistModel.fromEntity(Playlist entity) {
    return PlaylistModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      thumbnailUrl: entity.effectiveThumbnailUrl,
      songs: entity.songs.map((s) => SongModel.fromEntity(s)).toList(),
      isUserCreated: entity.isUserCreated,
      updatedAt: entity.updatedAt,
    );
  }

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    final rawSongs = json['songs'] is List ? json['songs'] as List<dynamic> : <dynamic>[];
    final List<SongModel> parsedSongs = [];
    for (final s in rawSongs) {
      if (s is Map) {
        try {
          parsedSongs.add(SongModel.fromJson(Map<String, dynamic>.from(s)));
        } catch (_) {}
      }
    }

    final rawThumb = (json['thumbnailUrl'] ?? '').toString().trim();
    final resolvedThumb = rawThumb.isNotEmpty
        ? rawThumb
        : (parsedSongs.isNotEmpty ? parsedSongs.first.thumbnailUrl : '');

    DateTime parsedUpdatedAt = DateTime.now();
    final rawUpdated = json['updatedAt'];
    if (rawUpdated is num) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdated.toInt());
    } else if (rawUpdated != null) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdated.toString()) ?? DateTime.now();
    }

    final rawIsUser = json['isUserCreated'] ?? json['isCustom'];
    final isUserCreated = rawIsUser is bool
        ? rawIsUser
        : (rawIsUser?.toString().toLowerCase() == 'true' || rawIsUser == 1);

    return PlaylistModel(
      id: (json['id'] ?? '').toString().trim(),
      title: (json['title'] ?? 'Untitled Playlist').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      thumbnailUrl: resolvedThumb,
      songs: parsedSongs,
      isUserCreated: isUserCreated,
      updatedAt: parsedUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final effectiveThumb = thumbnailUrl.trim().isNotEmpty
        ? thumbnailUrl.trim()
        : (songs.isNotEmpty ? songs.first.thumbnailUrl : '');
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': effectiveThumb,
      'songs': songs.map((s) => s.toJson()).toList(),
      'isUserCreated': isUserCreated,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

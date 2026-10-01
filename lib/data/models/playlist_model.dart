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
    return Playlist(
      id: id,
      title: title,
      description: description,
      thumbnailUrl: thumbnailUrl,
      songs: songs.map((s) => s.toEntity()).toList(),
      isUserCreated: isUserCreated,
      updatedAt: updatedAt,
    );
  }

  factory PlaylistModel.fromEntity(Playlist entity) {
    return PlaylistModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      thumbnailUrl: entity.thumbnailUrl,
      songs: entity.songs.map((s) => SongModel.fromEntity(s)).toList(),
      isUserCreated: entity.isUserCreated,
      updatedAt: entity.updatedAt,
    );
  }

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    final rawSongs = json['songs'] as List<dynamic>? ?? [];
    final List<SongModel> parsedSongs = [];
    for (final s in rawSongs) {
      if (s is Map) {
        try {
          parsedSongs.add(SongModel.fromJson(Map<String, dynamic>.from(s)));
        } catch (_) {}
      }
    }

    return PlaylistModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Playlist',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      songs: parsedSongs,
      isUserCreated: json['isUserCreated'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'songs': songs.map((s) => s.toJson()).toList(),
      'isUserCreated': isUserCreated,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

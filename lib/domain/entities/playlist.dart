import 'song.dart';

class Playlist {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final List<Song> songs;
  final bool isUserCreated;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.title,
    this.description = '',
    required this.thumbnailUrl,
    this.songs = const [],
    this.isUserCreated = false,
    required this.updatedAt,
  });

  int get songCount => songs.length;

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    List<Song>? songs,
    bool? isUserCreated,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      songs: songs ?? this.songs,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

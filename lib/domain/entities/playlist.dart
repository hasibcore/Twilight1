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

  /// Returns [thumbnailUrl] if non-empty, otherwise falls back to the first song's thumbnail
  String get effectiveThumbnailUrl {
    if (thumbnailUrl.trim().isNotEmpty) return thumbnailUrl.trim();
    for (final s in songs) {
      if (s.thumbnailUrl.trim().isNotEmpty) return s.thumbnailUrl.trim();
    }
    return '';
  }

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    List<Song>? songs,
    bool? isUserCreated,
    DateTime? updatedAt,
  }) {
    final nextSongs = songs ?? this.songs;
    final nextThumb = thumbnailUrl ??
        (this.thumbnailUrl.isNotEmpty
            ? this.thumbnailUrl
            : (nextSongs.isNotEmpty ? nextSongs.first.thumbnailUrl : ''));

    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: nextThumb,
      songs: nextSongs,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

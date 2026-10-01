class Song {
  final String id; // YouTube videoId
  final String title;
  final String artist; // Channel title
  final String channelId;
  final String thumbnailUrl;
  final int durationSeconds;
  final String durationFormatted;
  final int viewCount;
  final DateTime? publishedAt;
  final bool isFavorite;

  const Song({
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

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? channelId,
    String? thumbnailUrl,
    int? durationSeconds,
    String? durationFormatted,
    int? viewCount,
    DateTime? publishedAt,
    bool? isFavorite,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      channelId: channelId ?? this.channelId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      durationFormatted: durationFormatted ?? this.durationFormatted,
      viewCount: viewCount ?? this.viewCount,
      publishedAt: publishedAt ?? this.publishedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

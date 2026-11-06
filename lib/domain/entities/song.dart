class Song {
  final String id; // YouTube videoId or sp_ imported track id
  final String title;
  final String artist; // Channel or artist title
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

  static String _formatSecs(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mStr:$sStr' : '$mStr:$sStr';
  }

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
    final nextDurationSecs = durationSeconds ?? this.durationSeconds;
    final nextDurationFormatted = durationFormatted ??
        (durationSeconds != null && durationSeconds != this.durationSeconds
            ? _formatSecs(nextDurationSecs)
            : (this.durationFormatted.isNotEmpty
                ? this.durationFormatted
                : _formatSecs(nextDurationSecs)));

    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      channelId: channelId ?? this.channelId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: nextDurationSecs,
      durationFormatted: nextDurationFormatted,
      viewCount: viewCount ?? this.viewCount,
      publishedAt: publishedAt ?? this.publishedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Checks whether [other] represents the same logical track, even if one
  /// carries an imported `sp_...` prefix and the other carries the resolved 11-char videoId.
  bool isSameTrack(Song other) {
    if (id.trim() == other.id.trim()) return true;
    final thisTitle = title.toLowerCase().trim();
    final otherTitle = other.title.toLowerCase().trim();
    if (thisTitle.isEmpty || thisTitle != otherTitle) return false;
    final thisArtist = artist.toLowerCase().trim();
    final otherArtist = other.artist.toLowerCase().trim();
    if (thisArtist == otherArtist ||
        thisArtist.contains(otherArtist) ||
        otherArtist.contains(thisArtist)) {
      return true;
    }
    return id.startsWith('sp_') || other.id.startsWith('sp_');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

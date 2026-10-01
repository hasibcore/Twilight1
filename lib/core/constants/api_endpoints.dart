class ApiEndpoints {
  ApiEndpoints._();

  static const String youtubeBaseUrl = 'https://www.googleapis.com/youtube/v3';

  static const String search = '$youtubeBaseUrl/search';
  static const String videos = '$youtubeBaseUrl/videos';
  static const String channels = '$youtubeBaseUrl/channels';
  static const String playlists = '$youtubeBaseUrl/playlists';
  static const String playlistItems = '$youtubeBaseUrl/playlistItems';
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/logger.dart';
import '../models/song_model.dart';
import '../models/artist_model.dart';
import '../models/playlist_model.dart';
import '../models/search_result_model.dart';

/// Handles fetching music, artists, and playlists from YouTube.
/// Uses direct YouTube search via YoutubeExplode for unlimited A to Z music access,
/// with support for YouTube Data API v3 and live streaming.
class YouTubeRemoteDatasource {
  final http.Client client;
  final String apiKey;
  final YoutubeExplode _yt = YoutubeExplode();

  // In-memory cache to prevent redundant network requests and improve performance (capped to prevent memory growth)
  final Map<String, dynamic> _cache = {};
  static const int _maxCacheSize = 100;

  void _setCache(String key, dynamic value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  YouTubeRemoteDatasource({
    required this.client,
    required this.apiKey,
  });

  /// Checks if the configured API key is valid (not empty and not the default placeholder)
  bool get hasValidApiKey =>
      apiKey.isNotEmpty && !apiKey.contains('YOUR_YOUTUBE_DATA_API_V3_KEY_HERE');

  /// Searches for songs, artists, and playlists across all of YouTube.
  Future<SearchResultModel> searchAll(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return _getEmptySearchResult();
    }

    final cacheKey = 'search_${cleanQuery.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as SearchResultModel;
    }

    // 1. Try official YouTube Data API if user configured a valid key
    if (hasValidApiKey) {
      try {
        final url = Uri.parse(
          '${ApiEndpoints.search}?part=snippet&q=${Uri.encodeComponent(cleanQuery)}&type=video,channel,playlist&maxResults=25&key=$apiKey',
        );
        final response = await client.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];

          final List<SongModel> songs = [];
          final List<ArtistModel> artists = [];
          final List<PlaylistModel> playlists = [];

          for (final item in items) {
            final id = item['id'] as Map<String, dynamic>? ?? {};
            final kind = id['kind'] as String? ?? '';
            final snippet = item['snippet'] as Map<String, dynamic>? ?? {};

            if (kind.contains('video')) {
              songs.add(SongModel.fromYouTubeJson(item));
            } else if (kind.contains('channel')) {
              artists.add(ArtistModel(
                id: id['channelId'] as String? ?? '',
                name: snippet['title'] as String? ?? 'Artist',
                thumbnailUrl: snippet['thumbnails']?['high']?['url'] as String? ?? '',
              ));
            } else if (kind.contains('playlist')) {
              playlists.add(PlaylistModel(
                id: id['playlistId'] as String? ?? '',
                title: snippet['title'] as String? ?? 'Playlist',
                description: snippet['description'] as String? ?? '',
                thumbnailUrl: snippet['thumbnails']?['high']?['url'] as String? ?? '',
                updatedAt: DateTime.now(),
              ));
            }
          }

          final result = SearchResultModel(
            songs: songs,
            videos: songs,
            artists: artists,
            playlists: playlists,
          );
          _cache[cacheKey] = result;
          return result;
        }
      } catch (e) {
        AppLogger.error('Official YouTube API search error: $e');
      }
    }

    // 2. Direct search across all of YouTube using YoutubeExplode (A to Z YouTube access)
    try {
      final searchList = await _yt.search.search(cleanQuery).timeout(const Duration(seconds: 4));
      final List<SongModel> songs = [];
      final List<ArtistModel> artists = [];
      final Set<String> seenArtists = {};

      for (final video in searchList) {
        try {
          final durationSecs = video.duration?.inSeconds ?? 0;
          final thumb = video.thumbnails.highResUrl.isNotEmpty
              ? video.thumbnails.highResUrl
              : (video.thumbnails.mediumResUrl.isNotEmpty
                  ? video.thumbnails.mediumResUrl
                  : 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg');

          int views = 0;
          try {
            views = video.engagement.viewCount;
          } catch (_) {}

          DateTime? uploadDate;
          try {
            uploadDate = video.uploadDate;
          } catch (_) {}

          final song = SongModel(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            channelId: video.channelId.value,
            thumbnailUrl: thumb,
            durationSeconds: durationSecs,
            durationFormatted: Formatters.formatDuration(video.duration ?? Duration.zero),
            viewCount: views,
            publishedAt: uploadDate,
          );
          songs.add(song);

          if (video.author.isNotEmpty && !seenArtists.contains(video.author)) {
            seenArtists.add(video.author);
            artists.add(ArtistModel(
              id: video.channelId.value,
              name: video.author,
              thumbnailUrl: thumb,
            ));
          }
        } catch (_) {}
      }

      if (songs.isNotEmpty) {
        final result = SearchResultModel(
          songs: songs,
          videos: songs,
          artists: artists,
          playlists: [
            PlaylistModel(
              id: 'pl_${cleanQuery.hashCode}',
              title: '$cleanQuery Collection',
              description: 'YouTube music results for $cleanQuery',
              thumbnailUrl: songs.first.thumbnailUrl,
              updatedAt: DateTime.now(),
            ),
          ],
        );
        _setCache(cacheKey, result);
        return result;
      }
    } catch (e) {
      AppLogger.error('YouTubeExplode live search error: $e');
    }

    // 3. Fallback: Direct YouTube Web/InnerTube endpoint for 100% search uptime
    try {
      final webResults = await _searchWebFallback(cleanQuery);
      if (webResults.songs.isNotEmpty) {
        _setCache(cacheKey, webResults);
        return webResults;
      }
    } catch (e) {
      AppLogger.error('Web search fallback error: $e');
    }

    // 4. If no results or offline, return clean empty result
    return _getEmptySearchResult();
  }

  /// Fetches trending music videos for the home screen.
  Future<List<SongModel>> getTrendingMusic({String regionCode = 'US'}) async {
    final cacheKey = 'trending_$regionCode';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<SongModel>;
    }

    if (hasValidApiKey) {
      try {
        final url = Uri.parse(
          '${ApiEndpoints.videos}?part=snippet,contentDetails,statistics&chart=mostPopular&videoCategoryId=10&maxResults=25&regionCode=$regionCode&key=$apiKey',
        );
        final response = await client.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          final songs = items.map((i) => SongModel.fromYouTubeJson(i)).toList();
          _setCache(cacheKey, songs);
          return songs;
        }
      } catch (e) {
        AppLogger.error('Trending fetch error: $e');
      }
    }

    // Live trending music via YouTube search
    try {
      final searchList = await _yt.search.search('trending music songs').timeout(const Duration(seconds: 4));
      final List<SongModel> songs = [];
      for (final video in searchList.take(20)) {
        try {
          final thumb = video.thumbnails.highResUrl.isNotEmpty
              ? video.thumbnails.highResUrl
              : (video.thumbnails.mediumResUrl.isNotEmpty
                  ? video.thumbnails.mediumResUrl
                  : 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg');

          int views = 0;
          try {
            views = video.engagement.viewCount;
          } catch (_) {}

          DateTime? uploadDate;
          try {
            uploadDate = video.uploadDate;
          } catch (_) {}

          songs.add(SongModel(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            channelId: video.channelId.value,
            thumbnailUrl: thumb,
            durationSeconds: video.duration?.inSeconds ?? 0,
            durationFormatted: Formatters.formatDuration(video.duration ?? Duration.zero),
            viewCount: views,
            publishedAt: uploadDate,
          ));
        } catch (_) {}
      }

      if (songs.isNotEmpty) {
        _setCache(cacheKey, songs);
        return songs;
      }
    } catch (e) {
      AppLogger.error('YouTubeExplode trending error: $e');
    }

    // Fallback: InnerTube web search for trending music
    try {
      final webResults = await _searchWebFallback('trending music songs');
      if (webResults.songs.isNotEmpty) {
        _setCache(cacheKey, webResults.songs);
        return webResults.songs;
      }
    } catch (e) {
      AppLogger.error('Trending web search fallback error: $e');
    }

    return [];
  }

  /// Fetches exact details for a specific video ID using direct YouTube resolution.
  Future<SongModel?> getVideoDetails(String videoId) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    final cacheKey = 'video_$cleanId';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as SongModel?;
    }

    try {
      final video = await _yt.videos.get(cleanId);
      final durationSecs = video.duration?.inSeconds ?? 0;
      final thumb = video.thumbnails.highResUrl.isNotEmpty
          ? video.thumbnails.highResUrl
          : (video.thumbnails.mediumResUrl.isNotEmpty
              ? video.thumbnails.mediumResUrl
              : 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg');

      int views = 0;
      try {
        views = video.engagement.viewCount;
      } catch (_) {}

      final song = SongModel(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        channelId: video.channelId.value,
        thumbnailUrl: thumb,
        durationSeconds: durationSecs,
        durationFormatted: Formatters.formatDuration(video.duration ?? Duration.zero),
        viewCount: views,
        publishedAt: video.uploadDate,
      );

      _setCache(cacheKey, song);
      return song;
    } catch (e) {
      AppLogger.error('getVideoDetails error for $cleanId: $e');
    }
    return null;
  }

  /// Fetches songs by genre name.
  Future<List<SongModel>> getMusicByGenre(String genre) async {
    final search = await searchAll('$genre music songs');
    return search.songs;
  }

  Future<SearchResultModel> _searchWebFallback(String query) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false');
      final resp = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'hl': 'en',
              'gl': 'US',
              'clientName': 'WEB',
              'clientVersion': '2.20240920.01.00',
            }
          },
          'query': query,
        }),
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final songs = <SongModel>[];
        final artists = <ArtistModel>[];
        final seenArtists = <String>{};

        String? extractText(dynamic node) {
          if (node == null) return null;
          if (node is Map<String, dynamic>) {
            if (node['simpleText'] is String) return node['simpleText'] as String;
            final runs = node['runs'];
            if (runs is List && runs.isNotEmpty) {
              return runs.map((r) => r is Map ? (r['text'] ?? '').toString() : '').join();
            }
          }
          if (node is String) return node;
          return null;
        }

        void extractVideos(dynamic node) {
          if (node is Map<String, dynamic>) {
            if (node.containsKey('videoRenderer')) {
              final vr = node['videoRenderer'] as Map<String, dynamic>;
              final videoId = vr['videoId'] as String?;
              final title = extractText(vr['title']);
              final author = extractText(vr['ownerText']) ?? extractText(vr['shortBylineText']) ?? 'YouTube Artist';
              final durationText = extractText(vr['lengthText']) ?? '03:30';

              if (videoId != null && title != null && videoId.length == 11) {
                final song = SongModel(
                  id: videoId,
                  title: title,
                  artist: author,
                  channelId: 'yt_$videoId',
                  thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                  durationSeconds: Formatters.parseFormattedDuration(durationText),
                  durationFormatted: durationText,
                  viewCount: 100000,
                  publishedAt: null,
                );
                songs.add(song);

                if (!seenArtists.contains(author)) {
                  seenArtists.add(author);
                  artists.add(ArtistModel(
                    id: 'channel_$videoId',
                    name: author,
                    thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                  ));
                }
              }
            }
            for (final val in node.values) {
              extractVideos(val);
            }
          } else if (node is List) {
            for (final item in node) {
              extractVideos(item);
            }
          }
        }

        extractVideos(data);

        if (songs.isNotEmpty) {
          return SearchResultModel(
            songs: songs,
            videos: songs,
            artists: artists,
            playlists: [
              PlaylistModel(
                id: 'pl_${query.hashCode}',
                title: '$query Hits',
                description: 'Search results for $query',
                thumbnailUrl: songs.first.thumbnailUrl,
                updatedAt: DateTime.now(),
              ),
            ],
          );
        }
      }
    } catch (e) {
      AppLogger.error('InnerTube search fallback error: $e');
    }
    return _getEmptySearchResult();
  }

  SearchResultModel _getEmptySearchResult() {
    return const SearchResultModel(
      songs: [],
      videos: [],
      artists: [],
      playlists: [],
    );
  }
}

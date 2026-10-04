import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class LyricsResult {
  final String? plainLyrics;
  final String? syncedLyrics;
  final bool hasLyrics;
  final String? error;

  const LyricsResult({
    this.plainLyrics,
    this.syncedLyrics,
    required this.hasLyrics,
    this.error,
  });
}

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final Map<String, LyricsResult> _cache = {};

  static String cleanTitle(String title) {
    var cleaned = title;
    // Remove bracketed or parenthesized tags like [Official Music Video], (Audio), (Lyrics), etc.
    cleaned = cleaned.replaceAll(
        RegExp(
            r'\s*[\(\[][^\)\]]*(?:official|video|audio|lyrics|hd|4k|mv|remastered|feat\.|ft\.)[^\)\]]*[\)\]]',
            caseSensitive: false),
        '');
    // Remove "feat. ..." or "ft. ..."
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*(?:feat\.|ft\.)\s+[^,;]+', caseSensitive: false), '');
    // Remove trailing dashes or extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'[\s\-]+$'), '').trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  static String cleanArtist(String artist) {
    var cleaned = artist;
    // Remove "- Topic", "VEVO", etc.
    cleaned =
        cleaned.replaceAll(RegExp(r'\s*-\s*Topic', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*VEVO', caseSensitive: false), '');
    cleaned = cleaned.trim();
    return cleaned.isNotEmpty ? cleaned : artist;
  }

  Future<LyricsResult> getLyrics({
    required String title,
    required String artist,
  }) async {
    final cleanedT = cleanTitle(title);
    final cleanedA = cleanArtist(artist);
    final cacheKey = '${cleanedA}_$cleanedT'.toLowerCase();

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final client = http.Client();
    try {
      // 1. Direct get by exact artist and track name
      final getUri = Uri.parse(
        'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(cleanedA)}&track_name=${Uri.encodeComponent(cleanedT)}',
      );

      final res = await client.get(
        getUri,
        headers: {
          'User-Agent':
              'TwilightMusic/1.0 (https://github.com/hasibcore/Twilight)'
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final plain = data['plainLyrics'] as String?;
        final synced = data['syncedLyrics'] as String?;

        if ((plain != null && plain.isNotEmpty) ||
            (synced != null && synced.isNotEmpty)) {
          final result = LyricsResult(
            plainLyrics: plain,
            syncedLyrics: synced,
            hasLyrics: true,
          );
          _cache[cacheKey] = result;
          return result;
        }
      }

      // 2. Search fallback query
      final searchUri = Uri.parse(
        'https://lrclib.net/api/search?q=${Uri.encodeComponent('$cleanedA $cleanedT')}',
      );

      final searchRes = await client.get(
        searchUri,
        headers: {
          'User-Agent':
              'TwilightMusic/1.0 (https://github.com/hasibcore/Twilight)'
        },
      ).timeout(const Duration(seconds: 4));

      if (searchRes.statusCode == 200) {
        final list = jsonDecode(searchRes.body) as List;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final plain = first['plainLyrics'] as String?;
          final synced = first['syncedLyrics'] as String?;
          if ((plain != null && plain.isNotEmpty) ||
              (synced != null && synced.isNotEmpty)) {
            final result = LyricsResult(
              plainLyrics: plain,
              syncedLyrics: synced,
              hasLyrics: true,
            );
            _cache[cacheKey] = result;
            return result;
          }
        }
      }

      const notFound = LyricsResult(
        hasLyrics: false,
        plainLyrics: null,
      );
      _cache[cacheKey] = notFound;
      return notFound;
    } catch (e) {
      AppLogger.info('Lyrics fetch exception: $e');
      return LyricsResult(
        hasLyrics: false,
        error: e.toString(),
      );
    } finally {
      client.close();
    }
  }
}

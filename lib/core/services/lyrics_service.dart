import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import 'audio_stream_extractor.dart';

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
    final extracted = AudioStreamExtractor.extractCoreTitleAndArtist(title, '');
    final core = (extracted['title'] ?? '').trim();
    if (core.isNotEmpty) return core;

    var cleaned = title;
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*[\(\[][^\)\]]*(?:official|video|audio|lyrics|hd|4k|mv|remastered|feat\.|ft\.)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*(?:feat\.|ft\.)\s+[^,;]+', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[\s\-]+$'), '').trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  static String cleanArtist(String artist, {String? rawTitle}) {
    if (rawTitle != null && rawTitle.trim().isNotEmpty) {
      final extracted = AudioStreamExtractor.extractCoreTitleAndArtist(rawTitle, artist);
      final primaryArtist = (extracted['artist'] ?? '').trim();
      if (primaryArtist.isNotEmpty) return primaryArtist;
    }

    var cleaned = artist;
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*Topic', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*VEVO', caseSensitive: false), '');
    cleaned = cleaned.trim();
    return cleaned.isNotEmpty ? cleaned : artist;
  }

  static bool _matchesCoreTitle(String candidateTitle, String targetCoreTitle) {
    final candLower = candidateTitle.toLowerCase().trim();
    final targetLower = targetCoreTitle.toLowerCase().trim();
    if (candLower.isEmpty || targetLower.isEmpty) return false;
    if (candLower == targetLower || candLower.contains(targetLower) || targetLower.contains(candLower)) {
      return true;
    }
    final tokens = targetLower
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isEmpty) return true;
    int matched = 0;
    for (final t in tokens) {
      if (candLower.contains(t)) matched++;
    }
    return matched >= (tokens.length <= 2 ? tokens.length : (tokens.length * 0.6).ceil());
  }

  Future<LyricsResult> getLyrics({
    required String title,
    required String artist,
  }) async {
    final extracted = AudioStreamExtractor.extractCoreTitleAndArtist(title, artist);
    final cleanedT = (extracted['title']?.trim().isNotEmpty ?? false)
        ? extracted['title']!.trim()
        : cleanTitle(title);
    final cleanedA = (extracted['artist']?.trim().isNotEmpty ?? false)
        ? extracted['artist']!.trim()
        : cleanArtist(artist);
    final cacheKey = '${cleanedA}_$cleanedT'.toLowerCase();

    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.hasLyrics) {
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
        headers: {'User-Agent': 'TwilightMusic/2.4 (https://github.com/hasibcore/Twilight1)'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final plain = data['plainLyrics'] as String?;
        final synced = data['syncedLyrics'] as String?;

        if ((plain != null && plain.isNotEmpty) || (synced != null && synced.isNotEmpty)) {
          final result = LyricsResult(
            plainLyrics: plain,
            syncedLyrics: synced,
            hasLyrics: true,
          );
          _cache[cacheKey] = result;
          return result;
        }
      }

      // 2. Search fallback queries (with core-title match verification so wrong song lyrics are never returned)
      final queries = <String>{
        if (cleanedA.isNotEmpty) '$cleanedT $cleanedA',
        cleanedT,
      }.where((q) => q.trim().isNotEmpty);

      for (final q in queries) {
        final searchUri = Uri.parse(
          'https://lrclib.net/api/search?q=${Uri.encodeComponent(q.trim())}',
        );

        final searchRes = await client.get(
          searchUri,
          headers: {'User-Agent': 'TwilightMusic/2.4 (https://github.com/hasibcore/Twilight1)'},
        ).timeout(const Duration(seconds: 4));

        if (searchRes.statusCode == 200) {
          final list = jsonDecode(searchRes.body);
          if (list is List && list.isNotEmpty) {
            for (final rawItem in list) {
              if (rawItem is! Map<String, dynamic>) continue;
              final candTrack = (rawItem['trackName'] ?? rawItem['name'] ?? '').toString();
              if (!_matchesCoreTitle(candTrack, cleanedT)) continue;
              final plain = rawItem['plainLyrics'] as String?;
              final synced = rawItem['syncedLyrics'] as String?;
              if ((plain != null && plain.isNotEmpty) || (synced != null && synced.isNotEmpty)) {
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
        }
      }

      return const LyricsResult(
        hasLyrics: false,
        plainLyrics: null,
      );
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

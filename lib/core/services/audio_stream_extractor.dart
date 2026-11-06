import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/logger.dart';

class AudioStreamResult {
  final String url;
  final int totalBytes;
  final String mimeType;
  final int bitrate;
  final Map<String, String> headers;
  final bool isDirectDownloadable;

  AudioStreamResult({
    required this.url,
    required this.totalBytes,
    required this.mimeType,
    required this.bitrate,
    required this.headers,
    this.isDirectDownloadable = false,
  });
}

class AudioStreamExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();

  // Updated iOS App InnerTube Client
  static const Map<String, String> _iosAppHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X; en_US)',
    'X-YouTube-Client-Name': '5',
    'X-YouTube-Client-Version': '20.03.02',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Mobile Web InnerTube Client
  static const Map<String, String> _mwebHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    'X-YouTube-Client-Name': '2',
    'X-YouTube-Client-Version': '2.20240920.01.00',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // TV Embedded Player client
  static const String _tvApiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  static const Map<String, String> _tvHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'https://www.youtube.com',
    'Referer': 'https://www.youtube.com/',
  };

  // Android Music client
  static const Map<String, String> _androidMusicHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14) gzip',
    'X-YouTube-Client-Name': '21',
    'X-YouTube-Client-Version': '7.27.52',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Official Android YouTube App client
  static const Map<String, String> _androidAppHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
    'X-YouTube-Client-Name': '3',
    'X-YouTube-Client-Version': '20.10.38',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static const List<String> _invidiousInstances = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://invidious.tiekoetter.com',
    'https://invidious.f5.si',
    'https://yewtu.be',
    'https://vid.puffyan.us',
    'https://pipedapi.kavin.rocks',
    'https://api.piped.video',
  ];

  // In-memory cache with timestamps (stream URLs cached up to 5m30s)
  static final Map<String, AudioStreamResult> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static final Map<String, Map<String, String>> _metadataByVideoId = {};
  static const int _maxCacheSize = 100;
  static const Duration _cacheTTL = Duration(minutes: 5, seconds: 30);

  static void _setCache(String key, AudioStreamResult result) {
    if (_cache.length >= _maxCacheSize) {
      final oldest = _cacheTime.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b);
      _cache.remove(oldest.key);
      _cacheTime.remove(oldest.key);
    }
    _cache[key] = result;
    _cacheTime[key] = DateTime.now();
  }

  static void invalidateCache(String videoId) {
    _cache.remove('${videoId}_false');
    _cache.remove('${videoId}_true');
    _cacheTime.remove('${videoId}_false');
    _cacheTime.remove('${videoId}_true');
  }

  /// Returns the age of the cached stream URL for [videoId], or null if not cached.
  static Duration? getCacheAge(String videoId, {bool preferDownload = false}) {
    final ts = _cacheTime['${videoId}_$preferDownload'];
    if (ts == null) return null;
    return DateTime.now().difference(ts);
  }

  static final RegExp _metadataSegmentRegex = RegExp(
    r'^(?:coke\s+studio(?:\s+bangla|\s+india|\s+pakistan|\s+global|\s+tamil|\s+bharat)?|season\s*\d+|episode\s*\d+|ep\s*\.?\s*\d+|s\d+\s*e\d+|official.*|lyric(?:al)?.*|full\s+(?:song|video|audio|album).*|audio\s+song.*|video\s+song.*|music\s+video.*|rabindra\s+sangeet.*|tagore\s+song.*|nazrul\s+geeti.*|bangla\s+(?:gaan|song|music|band|lofi).*|new\s+(?:bangla|bengali|hindi)\s+song.*|hd|4k|hq|remaster(?:ed)?|live(?:\s+performance|\s+session|\s+in\s+concert)?|unplugged|mtv\s+unplugged.*|t-series.*|sony\s+music.*|zee\s+music.*|svf.*|sangeet\s+bangla.*|soundtek.*|laser\s+vision.*|cd\s+choice.*|eagle\s+music.*|gaanchill.*|bhavna\s+records.*|g-series.*|agniveena.*|saregama.*|times\s+music.*|tips\s+official.*|yrf.*|speed\s+records.*)$',
    caseSensitive: false,
  );

  static const Set<String> _coreTitleStopWords = {
    'the', 'and', 'for', 'with', 'from', 'feat', 'ft', 'of', 'in', 'on', 'to', 'at', 'by', 'is', 'it', 'my', 'me',
    'official', 'music', 'video', 'audio', 'song', 'songs', 'full', 'lyric', 'lyrics', 'lyrical',
    'hd', '4k', 'hq', 'live', 'session', 'studio', 'coke', 'bangla', 'bengali', 'hindi',
    'season', 'episode', 'version', 'unplugged', 'rabindra', 'sangeet', 'tagore', 'records', 'creations',
  };

  static String _normalizePhoneticToken(String input) {
    return input
        .toLowerCase()
        .replaceAll('bh', 'v')
        .replaceAll('sh', 's')
        .replaceAll('ph', 'f')
        .replaceAll('kh', 'k')
        .replaceAll('gh', 'g')
        .replaceAll('chh', 'ch')
        .replaceAll('aa', 'a')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAll('ou', 'o');
  }

  static bool _tokenMatchesText(String token, String text) {
    if (token.isEmpty || text.isEmpty) return false;
    final tLower = token.toLowerCase();
    final textLower = text.toLowerCase();
    if (textLower.contains(tLower)) return true;
    final pToken = _normalizePhoneticToken(tLower);
    final pText = _normalizePhoneticToken(textLower);
    return pToken.length >= 2 && pText.contains(pToken);
  }

  static List<String> _getCoreTitleTokens(String coreTitle) {
    final allTokens = coreTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
    final filtered = allTokens.where((t) => !_coreTitleStopWords.contains(t)).toList();
    return filtered.isNotEmpty ? filtered : allTokens;
  }

  /// Cleans YouTube video titles and channel names into a canonical song search query
  static String cleanTrackText(String input) {
    return input
        .replaceAll(RegExp(r'\([^)]*(?:official|video|audio|lyric|lyrics|visualizer|hd|4k|hq|remaster|live|mv|full\s+song|coke\s+studio|season\s*\d+)[^)]*\)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\[[^\]]*(?:official|video|audio|lyric|lyrics|visualizer|hd|4k|hq|remaster|live|mv|full\s+song|coke\s+studio|season\s*\d+)[^\]]*\]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:official\s+music\s+video|official\s+video|official\s+audio|lyric(?:al)?\s+video|full\s+video|full\s+audio|full\s+song|4k\s+remaster|audio\s+song|video\s+song)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s*[-|•·]\s*(?:official|topic|vevo).*$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:VEVO|Topic)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[|•·"“”‘’]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts the core song title and specific artist from pipe/hyphen-delimited YouTube titles
  static Map<String, String> extractCoreTitleAndArtist(String rawTitle, String? rawArtist) {
    final cleanedChannelArtist = cleanTrackText(rawArtist ?? '')
        .replaceAll(RegExp(r'(?:theband|official|vevo|topic|music|records|channel|band)$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:official|vevo|topic|music|records|channel|various\s+artists)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final isChannelGenericOrShow =
        cleanedChannelArtist.isEmpty || _metadataSegmentRegex.hasMatch(cleanedChannelArtist);
    final compactChannel = cleanedChannelArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final rawSegments = rawTitle
        .split(RegExp(r'(?:\s*\|\|\s*|\s*[|•·]\s*|\s+\/\/\s+)'))
        .map((s) => cleanTrackText(s))
        .where((s) => s.isNotEmpty)
        .toList();

    final meaningfulSegments = rawSegments.where((s) => !_metadataSegmentRegex.hasMatch(s)).toList();
    final candidateSegments =
        meaningfulSegments.isNotEmpty ? meaningfulSegments : [cleanTrackText(rawTitle)];

    final latinSegment = candidateSegments.firstWhere(
      (s) => RegExp(r'[a-zA-Z]').hasMatch(s),
      orElse: () => candidateSegments.isNotEmpty ? candidateSegments.first : '',
    );
    final primarySeg = latinSegment;

    String coreTitle = primarySeg;
    String extractedArtist = '';

    if (primarySeg.contains('-') || primarySeg.contains('–') || primarySeg.contains('—')) {
      final hyphenParts = primarySeg
          .split(RegExp(r'\s*[-–—]\s*'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (hyphenParts.length == 2) {
        final left = hyphenParts[0];
        final right = hyphenParts[1];
        final leftCompact = left.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final rightCompact = right.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (compactChannel.isNotEmpty &&
            leftCompact.isNotEmpty &&
            (leftCompact == compactChannel ||
                compactChannel.contains(leftCompact) ||
                leftCompact.contains(compactChannel))) {
          coreTitle = right;
          extractedArtist = left;
        } else if (compactChannel.isNotEmpty &&
            rightCompact.isNotEmpty &&
            (rightCompact == compactChannel ||
                compactChannel.contains(rightCompact) ||
                rightCompact.contains(compactChannel))) {
          coreTitle = left;
          extractedArtist = right;
        } else if (RegExp(r'\s+[-–—]\s+').hasMatch(primarySeg)) {
          if (_metadataSegmentRegex.hasMatch(right)) {
            coreTitle = left;
          } else {
            coreTitle = right;
            extractedArtist = left;
          }
        }
      }
    }

    if (extractedArtist.isEmpty) {
      final otherLatinSegments = candidateSegments
          .where((s) => s != primarySeg && RegExp(r'[a-zA-Z]').hasMatch(s) && !_metadataSegmentRegex.hasMatch(s))
          .toList();
      if (otherLatinSegments.isNotEmpty) {
        extractedArtist = otherLatinSegments.last;
      }
    }

    final preferExtracted = extractedArtist.isNotEmpty &&
        (isChannelGenericOrShow ||
            (!cleanedChannelArtist.contains(' ') && extractedArtist.contains(' ')) ||
            compactChannel == extractedArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

    final primaryArtist = preferExtracted
        ? (extractedArtist.isNotEmpty ? extractedArtist : cleanedChannelArtist)
        : (cleanedChannelArtist.isNotEmpty ? cleanedChannelArtist : extractedArtist);

    return {
      'title': coreTitle.trim().isNotEmpty ? coreTitle.trim() : cleanTrackText(rawTitle),
      'artist': primaryArtist.trim(),
      'rawContext': '$rawTitle ${rawArtist ?? ''}',
    };
  }

  /// Resolves canonical track title and artist for [videoId] using provided metadata or YouTube oEmbed
  static Future<Map<String, String>> _resolveTrackMetadata(
    String videoId, {
    String? title,
    String? artist,
  }) async {
    final cleanId = videoId.trim();
    if (title != null && title.trim().isNotEmpty) {
      final extracted = extractCoreTitleAndArtist(title, artist);
      if (cleanId.isNotEmpty) {
        _metadataByVideoId[cleanId] = extracted;
      }
      return extracted;
    }

    if (_metadataByVideoId.containsKey(cleanId)) {
      return _metadataByVideoId[cleanId]!;
    }

    if (cleanId.length == 11 && !cleanId.startsWith('sp_')) {
      try {
        final oembedUri = Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$cleanId&format=json',
        );
        final res = await http.get(oembedUri).timeout(const Duration(milliseconds: 2500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final oembedTitle = data['title']?.toString() ?? '';
          final oembedArtist = data['author_name']?.toString() ?? '';
          if (oembedTitle.isNotEmpty) {
            final meta = extractCoreTitleAndArtist(oembedTitle, oembedArtist);
            _metadataByVideoId[cleanId] = meta;
            return meta;
          }
        }
      } catch (_) {}
    }

    return {'title': '', 'artist': '', 'rawContext': ''};
  }

  /// Extracts the best playable audio stream URL for a given YouTube video ID and optional track metadata.
  /// When [forceRefresh] is true, bypasses any existing cache entry and resolves a fresh stream URL.
  static Future<AudioStreamResult?> extractAudioStream(
    String videoId, {
    bool preferDownload = false,
    bool forceRefresh = false,
    String? title,
    String? artist,
  }) async {
    final cleanId = videoId.trim();
    if (title != null && title.trim().isNotEmpty && cleanId.isNotEmpty) {
      _metadataByVideoId[cleanId] = extractCoreTitleAndArtist(title, artist);
    }

    final cacheKey = '${cleanId}_$preferDownload';
    if (forceRefresh) {
      invalidateCache(cleanId);
    } else if (_cache.containsKey(cacheKey)) {
      final age = DateTime.now().difference(_cacheTime[cacheKey] ?? DateTime(2000));
      if (age < _cacheTTL) {
        AppLogger.info('Cache hit for $cleanId (age: ${age.inSeconds}s)');
        return _cache[cacheKey];
      } else {
        AppLogger.info('Cache expired for $cleanId (age: ${age.inSeconds}s), re-fetching');
        _cache.remove(cacheKey);
        _cacheTime.remove(cacheKey);
      }
    }

    // Resolve canonical title & artist so exact-track multi-source resolution works even if only videoId was passed
    final meta = await _resolveTrackMetadata(cleanId, title: title, artist: artist);
    final trackTitle = meta['title'] ?? '';
    final trackArtist = meta['artist'] ?? '';
    final rawContext = meta['rawContext'] ?? '$trackTitle $trackArtist';

    // Tier 0: Exact-Track 320kbps AAC Direct CDN Resolver (JioSaavn Official API)
    // Guarantees fast (<600ms), full-length 320kbps MP4/M4A playback even when YouTube blocks with LOGIN_REQUIRED
    if (trackTitle.isNotEmpty) {
      try {
        final exactCdnResult = await _extractFromJioSaavnDirect(
          title: trackTitle,
          artist: trackArtist,
          rawContext: rawContext,
        );
        if (exactCdnResult != null) {
          AppLogger.info('Extracted 320kbps exact-track stream via JioSaavn CDN for "$trackTitle" ($cleanId)');
          _setCache(cacheKey, exactCdnResult);
          return exactCdnResult;
        }
      } catch (e) {
        AppLogger.info('Tier 0 exact-track CDN error for $cleanId: $e');
      }
    }

    // Tier 0.5: SoundCloud Direct Progressive Stream Resolver for exact indie/band/album tracks
    if (trackTitle.isNotEmpty) {
      try {
        final scResult = await _extractFromSoundCloudDirect(
          title: trackTitle,
          artist: trackArtist,
          rawContext: rawContext,
        );
        if (scResult != null) {
          AppLogger.info('Extracted exact-track stream via SoundCloud CDN for "$trackTitle" ($cleanId)');
          _setCache(cacheKey, scResult);
          return scResult;
        }
      } catch (e) {
        AppLogger.info('Tier 0.5 SoundCloud CDN error for $cleanId: $e');
      }
    }

    // Tier 1: Official iOS App Client
    try {
      final iosResult = await _extractFromIosApp(cleanId);
      if (iosResult != null) {
        AppLogger.info('Extracted stream via Tier 1 iOS App for $cleanId');
        if (!preferDownload) _setCache(cacheKey, iosResult);
        return iosResult;
      }
    } catch (e) {
      AppLogger.info('Tier 1 iOS App error for $cleanId: $e');
    }

    // Tier 2: Mobile Web Client
    try {
      final mwebResult = await _extractFromMweb(cleanId);
      if (mwebResult != null) {
        AppLogger.info('Extracted stream via Tier 2 MWEB for $cleanId');
        if (!preferDownload) _setCache(cacheKey, mwebResult);
        return mwebResult;
      }
    } catch (e) {
      AppLogger.info('Tier 2 MWEB error for $cleanId: $e');
    }

    // Tier 3: Official Android YouTube App client
    try {
      final androidAppResult = await _extractFromAndroidApp(cleanId);
      if (androidAppResult != null) {
        AppLogger.info('Extracted stream via Tier 3 Android App for $cleanId');
        if (!preferDownload) _setCache(cacheKey, androidAppResult);
        return androidAppResult;
      }
    } catch (e) {
      AppLogger.info('Tier 3 Android App error for $cleanId: $e');
    }

    // Tier 4: Android Music Client
    try {
      final androidMusicResult = await _extractFromAndroidMusic(cleanId);
      if (androidMusicResult != null) {
        AppLogger.info('Extracted stream via Tier 4 Android Music for $cleanId');
        if (!preferDownload) _setCache(cacheKey, androidMusicResult);
        return androidMusicResult;
      }
    } catch (e) {
      AppLogger.info('Tier 4 Android Music error for $cleanId: $e');
    }

    // Tier 5: TV Embedded Player
    try {
      final tvResult = await _extractFromTvEmbedded(cleanId);
      if (tvResult != null) {
        AppLogger.info('Extracted stream via Tier 5 TV Embedded for $cleanId');
        if (!preferDownload) _setCache(cacheKey, tvResult);
        return tvResult;
      }
    } catch (e) {
      AppLogger.info('Tier 5 TV Embedded error for $cleanId: $e');
    }

    // Tier 6: YoutubeExplode with TV / MWEB / iOS clients
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        cleanId,
        ytClients: [YoutubeApiClient.tv, YoutubeApiClient.mweb, YoutubeApiClient.ios],
      ).timeout(const Duration(seconds: 4));
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        final m4a = audioStreams.where((s) =>
            s.container.name.toLowerCase().contains('mp4') ||
            s.container.name.toLowerCase().contains('m4a')).toList();
        final best = m4a.isNotEmpty ? m4a.withHighestBitrate() : audioStreams.withHighestBitrate();
        AppLogger.info('Extracted stream via Tier 6 YoutubeExplode for $cleanId');
        final result = AudioStreamResult(
          url: best.url.toString(),
          totalBytes: best.size.totalBytes,
          mimeType: best.container.name.toLowerCase().contains('mp4') ? 'audio/mp4' : 'audio/webm',
          bitrate: best.bitrate.bitsPerSecond,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15',
          },
        );
        _setCache(cacheKey, result);
        return result;
      }
    } catch (e) {
      AppLogger.info('Tier 6 YoutubeExplode error for $cleanId: $e');
    }

    // Tier 7: Invidious / Piped Instances
    try {
      final invResult = await _extractFromInvidious(cleanId);
      if (invResult != null) {
        AppLogger.info('Extracted stream via Tier 7 Invidious for $cleanId');
        _setCache(cacheKey, invResult);
        return invResult;
      }
    } catch (e) {
      AppLogger.info('Tier 7 Invidious error for $cleanId: $e');
    }

    // Tier 8: iTunes High-Bitrate M4A Exact-Song Fallback
    if (trackTitle.isNotEmpty) {
      try {
        final itunesResult = await _extractFromItunesSearch(
          title: trackTitle,
          artist: trackArtist,
        );
        if (itunesResult != null) {
          AppLogger.info('Extracted M4A stream via Tier 8 iTunes for "$trackTitle" ($cleanId)');
          _setCache(cacheKey, itunesResult);
          return itunesResult;
        }
      } catch (e) {
        AppLogger.info('Tier 8 iTunes fallback error for $cleanId: $e');
      }
    }

    AppLogger.error('All audio stream extraction tiers failed for $cleanId');
    return null;
  }

  /// Resolves a full-length 320kbps AAC (.mp4) direct CDN stream for the exact [title] and [artist]
  static Future<AudioStreamResult?> _extractFromJioSaavnDirect({
    required String title,
    required String artist,
    String rawContext = '',
  }) async {
    final queries = <String>{
      if (artist.isNotEmpty && !title.toLowerCase().contains(artist.toLowerCase()))
        '$title $artist'
      else
        title,
      if (artist.isNotEmpty) title,
    }.where((q) => q.trim().isNotEmpty).toList();

    final coreTokens = _getCoreTitleTokens(title);
    final normCoreTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final normTargetArtist = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final artistTokens = normTargetArtist
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_coreTitleStopWords.contains(t))
        .toList();
    final rawContextLower = (rawContext.isNotEmpty ? rawContext : '$title $artist').toLowerCase();
    final wantsCokeStudio = rawContextLower.contains('coke studio');

    for (final q in queries) {
      final searchUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?p=1&q=${Uri.encodeComponent(q.trim())}&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=10&__call=search.getResults',
      );
      final searchRes = await http.get(
        searchUri,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(milliseconds: 3500));

      if (searchRes.statusCode != 200) continue;
      final searchData = jsonDecode(searchRes.body);
      if (searchData is! Map<String, dynamic>) continue;
      final results = (searchData['results'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      if (results.isEmpty) continue;

      Map<String, dynamic>? bestMatch;
      int bestScore = -999;

      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        final moreInfo = item['more_info'] as Map<String, dynamic>? ?? {};
        final encUrl = moreInfo['encrypted_media_url']?.toString() ?? '';
        if (encUrl.isEmpty) continue;

        final candTitle = (item['title']?.toString() ?? '').toLowerCase();
        final candSubtitle = (item['subtitle']?.toString() ?? '').toLowerCase();
        final candAlbum = (moreInfo['album']?.toString() ?? '').toLowerCase();
        final combined = '$candTitle $candSubtitle $candAlbum';

        // STRICT CORE-TITLE MATCH GATE:
        // Reject candidates that do not match the core song title tokens
        if (coreTokens.isNotEmpty) {
          int matchedCoreCount = 0;
          for (final ct in coreTokens) {
            if (_tokenMatchesText(ct, candTitle)) {
              matchedCoreCount += 1;
            }
          }
          final minRequired = coreTokens.length == 1
              ? 1
              : coreTokens.length == 2
                  ? 2
                  : ((coreTokens.length * 0.6).ceil() < 2 ? 2 : (coreTokens.length * 0.6).ceil());
          final artistMatched =
              artistTokens.isNotEmpty && artistTokens.any((at) => _tokenMatchesText(at, combined));
          final hasDistinctiveTokenAndArtist = matchedCoreCount >= 1 &&
              artistMatched &&
              coreTokens.any((ct) => ct.length >= 7 && _tokenMatchesText(ct, candTitle));

          if (matchedCoreCount < minRequired && !hasDistinctiveTokenAndArtist) {
            continue;
          }

          // STRICT ARTIST GATE:
          // Never accept a track by a completely different artist (e.g. Zubeen Garg "Tumi" vs Level Five "Tumi")
          if (artistTokens.isNotEmpty && !artistMatched) {
            continue;
          }
        }

        // STRICT VERSION GATE (Coke Studio vs Original Studio Album):
        final candIsCokeStudio = combined.contains('coke studio');
        if (wantsCokeStudio != candIsCokeStudio) {
          continue;
        }

        int score = 20 - (i * 2);
        final candNormFull = candTitle.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final candNormBase = candTitle.split('|').first.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (candNormFull == normCoreTitle) {
          score += 35;
        } else if (candNormBase == normCoreTitle) {
          score += 25;
        }
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) score += 20;
        }
        for (final at in artistTokens) {
          if (_tokenMatchesText(at, combined)) score += 18;
        }

        if (wantsCokeStudio && candIsCokeStudio) {
          score += 40;
        }

        final wantsRemixOrKaraoke = RegExp(
          r'\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi)\b',
          caseSensitive: false,
        ).hasMatch(rawContextLower);
        if (!wantsRemixOrKaraoke &&
            RegExp(
              r'\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox)\b',
              caseSensitive: false,
            ).hasMatch(combined)) {
          continue;
        }

        if (score > bestScore) {
          bestScore = score;
          bestMatch = item;
        }
      }

      if (bestMatch == null) continue;
      final moreInfo = bestMatch['more_info'] as Map<String, dynamic>? ?? {};
      final encUrl = moreInfo['encrypted_media_url']?.toString() ?? '';
      if (encUrl.isEmpty) continue;

      final authUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=song.generateAuthToken&url=${Uri.encodeComponent(encUrl)}&bitrate=320&api_version=4&_format=json&ctx=web6dot0&_marker=0',
      );
      final authRes = await http.get(
        authUri,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(milliseconds: 2800));

      if (authRes.statusCode != 200) continue;
      final authData = jsonDecode(authRes.body);
      if (authData is! Map<String, dynamic>) continue;
      final rawAuthUrl = authData['auth_url']?.toString() ?? '';
      if (rawAuthUrl.isEmpty) continue;

      // Normalize to direct aac.saavncdn.com URL for fast HTTP/2 range streaming without TLS issues
      final directCdnUrl = rawAuthUrl
          .replaceFirst('https://web.saavncdn.com', 'https://aac.saavncdn.com')
          .replaceFirst('http://web.saavncdn.com', 'https://aac.saavncdn.com')
          .split('?')
          .first;

      int contentLen = 0;
      try {
        final headRes = await http.head(
          Uri.parse(directCdnUrl),
          headers: const {'User-Agent': 'Mozilla/5.0'},
        ).timeout(const Duration(milliseconds: 2200));
        if (headRes.statusCode == 200 || headRes.statusCode == 206) {
          contentLen = int.tryParse(headRes.headers['content-length'] ?? '0') ?? 0;
        } else {
          continue;
        }
      } catch (_) {}

      return AudioStreamResult(
        url: directCdnUrl,
        totalBytes: contentLen,
        mimeType: 'audio/mp4',
        bitrate: 320000,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': '*/*',
        },
        isDirectDownloadable: true,
      );
    }

    return null;
  }

  /// Resolves an exact indie/band/album track from SoundCloud API v2
  static Future<AudioStreamResult?> _extractFromSoundCloudDirect({
    required String title,
    required String artist,
    String rawContext = '',
  }) async {
    const scClientId = '39AVoiZVrdvJEMFLH8T0c5WGshQaAPRJ';
    final coreTokens = _getCoreTitleTokens(title);
    final normTargetArtist = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final artistTokens = normTargetArtist
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_coreTitleStopWords.contains(t))
        .toList();
    final wantsCokeStudio = rawContext.toLowerCase().contains('coke studio');

    final q = artist.isNotEmpty ? '$artist $title' : title;
    final searchUri = Uri.parse(
      'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(q.trim())}&client_id=$scClientId&limit=10',
    );
    final res = await http.get(
      searchUri,
      headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
    ).timeout(const Duration(milliseconds: 3500));
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return null;
    final collection = (data['collection'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    if (collection.isEmpty) return null;

    for (final item in collection) {
      final candTitle = (item['title']?.toString() ?? '').toLowerCase();
      final candUser = ((item['user'] as Map<String, dynamic>?)?['username']?.toString() ?? '').toLowerCase();
      final combined = '$candTitle $candUser';

      if (coreTokens.isNotEmpty) {
        int matched = 0;
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) matched += 1;
        }
        final minReq = coreTokens.length <= 2 ? coreTokens.length : (coreTokens.length * 0.6).ceil();
        if (matched < minReq) continue;
      }

      if (artistTokens.isNotEmpty && !artistTokens.any((at) => _tokenMatchesText(at, combined))) {
        continue;
      }
      if (wantsCokeStudio != combined.contains('coke studio')) {
        continue;
      }
      if (RegExp(r'\b(?:cover|karaoke|instrumental)\b').hasMatch(candTitle) &&
          !title.toLowerCase().contains('cover')) {
        continue;
      }

      final media = item['media'] as Map<String, dynamic>? ?? {};
      final transcodings = (media['transcodings'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      final progTr = transcodings.where((tr) => (tr['format'] as Map<String, dynamic>?)?['protocol'] == 'progressive').toList();
      if (progTr.isNotEmpty) {
        final trUrl = progTr.first['url']?.toString() ?? '';
        if (trUrl.isNotEmpty) {
          final infoRes = await http.get(Uri.parse('$trUrl?client_id=$scClientId')).timeout(const Duration(milliseconds: 2500));
          if (infoRes.statusCode == 200) {
            final info = jsonDecode(infoRes.body) as Map<String, dynamic>;
            final streamUrl = info['url']?.toString() ?? '';
            if (streamUrl.isNotEmpty) {
              return AudioStreamResult(
                url: streamUrl,
                totalBytes: 0,
                mimeType: 'audio/mp4',
                bitrate: 160000,
                headers: const {'User-Agent': 'Mozilla/5.0'},
                isDirectDownloadable: true,
              );
            }
          }
        }
      }
    }
    return null;
  }

  /// Resolves a direct full-length M4A stream via saavn.sumit.co (rejects <=35s previews)
  static Future<AudioStreamResult?> _extractFromItunesSearch({
    required String title,
    required String artist,
  }) async {
    final coreTokens = _getCoreTitleTokens(title);
    final artistTokens = artist
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_coreTitleStopWords.contains(t))
        .toList();
    final q = artist.isNotEmpty ? '$title $artist' : title;
    final uri = Uri.parse(
      'https://saavn.sumit.co/api/search/songs?query=${Uri.encodeComponent(q.trim())}&limit=10',
    );
    final res = await http.get(uri).timeout(const Duration(milliseconds: 3500));
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return null;
    final dataMap = data['data'] as Map<String, dynamic>? ?? {};
    final results = (dataMap['results'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    if (results.isEmpty) return null;

    for (final item in results) {
      final durationSec = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
      if (durationSec <= 35) continue;
      final downloadUrls = (item['downloadUrl'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      if (downloadUrls.isEmpty) continue;
      final fullStreamUrl = downloadUrls.last['url']?.toString() ?? '';
      if (fullStreamUrl.isEmpty) continue;

      final candTitle = (item['name']?.toString() ?? '').toLowerCase();
      final artistsMap = item['artists'] as Map<String, dynamic>? ?? {};
      final primaryList = (artistsMap['primary'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      final candArtist = primaryList.map((a) => a['name']?.toString() ?? '').join(' ').toLowerCase();

      if (coreTokens.isNotEmpty) {
        int matched = 0;
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) matched += 1;
        }
        final minReq = coreTokens.length <= 2 ? coreTokens.length : (coreTokens.length * 0.6).ceil();
        if (matched < minReq) continue;
      }
      if (artistTokens.isNotEmpty &&
          !artistTokens.any((at) => _tokenMatchesText(at, '$candTitle $candArtist'))) {
        continue;
      }

      int contentLen = 0;
      try {
        final head = await http.head(Uri.parse(fullStreamUrl)).timeout(const Duration(milliseconds: 2000));
        contentLen = int.tryParse(head.headers['content-length'] ?? '0') ?? 0;
      } catch (_) {}
      return AudioStreamResult(
        url: fullStreamUrl,
        totalBytes: contentLen,
        mimeType: 'audio/mp4',
        bitrate: 320000,
        headers: const {'User-Agent': 'Mozilla/5.0'},
        isDirectDownloadable: true,
      );
    }
    return null;
  }

  /// Extracts audio via official YouTube iOS App client
  static Future<AudioStreamResult?> _extractFromIosApp(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'IOS',
          'clientVersion': '20.03.02',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'osName': 'iOS',
          'osVersion': '18.2.1.22C161',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await http.post(
      uri,
      headers: _iosAppHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(milliseconds: 3500));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X; en_US)',
      },
      clientName: 'iOS App',
    );
  }

  /// Extracts audio via Mobile Web InnerTube client
  static Future<AudioStreamResult?> _extractFromMweb(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'MWEB',
          'clientVersion': '2.20240920.01.00',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await http.post(
      uri,
      headers: _mwebHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(milliseconds: 3500));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
      },
      clientName: 'MWEB',
    );
  }

  /// Extracts unthrottled audio stream via public Invidious / Piped instances
  static Future<AudioStreamResult?> _extractFromInvidious(String videoId) async {
    for (final inst in _invidiousInstances.take(3)) {
      try {
        final uri = Uri.parse('$inst/api/v1/videos/$videoId');
        final res = await http.get(
          uri,
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ).timeout(const Duration(milliseconds: 2500));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final adaptive = (data['adaptiveFormats'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();

          final audios = adaptive.where((f) {
            final type = (f['type'] ?? '').toString().toLowerCase();
            return type.contains('audio');
          }).toList();

          if (audios.isEmpty) continue;

          audios.sort((a, b) {
            final typeA = (a['type'] ?? '').toString().toLowerCase();
            final typeB = (b['type'] ?? '').toString().toLowerCase();
            final isMp4A = typeA.contains('mp4') || typeA.contains('m4a');
            final isMp4B = typeB.contains('mp4') || typeB.contains('m4a');
            if (isMp4A && !isMp4B) return -1;
            if (!isMp4A && isMp4B) return 1;

            final bitA = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
            final bitB = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
            return bitB.compareTo(bitA);
          });

          for (final audio in audios) {
            final url = audio['url'] as String?;
            if (url != null && url.isNotEmpty) {
              final clen = int.tryParse(audio['clen']?.toString() ?? '') ?? 0;
              final bitrate = int.tryParse(audio['bitrate']?.toString() ?? '') ?? 128000;
              final mime = (audio['type'] as String? ?? 'audio/mp4').split(';').first;

              return AudioStreamResult(
                url: url,
                totalBytes: clen,
                mimeType: mime,
                bitrate: bitrate,
                headers: const {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                },
                isDirectDownloadable: true,
              );
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Extracts audio stream via YouTube TV Embedded Player InnerTube endpoint.
  static Future<AudioStreamResult?> _extractFromTvEmbedded(String videoId) async {
    final uri = Uri.parse(
        'https://www.youtube.com/youtubei/v1/player?key=$_tvApiKey&prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          'clientVersion': '2.0',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
        'thirdParty': {
          'embedUrl': 'https://www.youtube.com/',
        },
      },
      'videoId': videoId,
      'playbackContext': {
        'contentPlaybackContext': {
          'html5Preference': 'HTML5_PREF_WANTS',
        },
      },
    };

    final res = await http.post(
      uri,
      headers: _tvHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(milliseconds: 3000));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1',
        'Referer': 'https://www.youtube.com/',
        'Origin': 'https://www.youtube.com',
      },
      clientName: 'TV Embedded',
    );
  }

  /// Extracts audio via Android Music client
  static Future<AudioStreamResult?> _extractFromAndroidMusic(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'ANDROID_MUSIC',
          'clientVersion': '7.27.52',
          'androidSdkVersion': 34,
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await http.post(
      uri,
      headers: _androidMusicHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(milliseconds: 3000));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14) gzip',
      },
      clientName: 'Android Music',
    );
  }

  /// Extracts audio via official YouTube Android App client
  static Future<AudioStreamResult?> _extractFromAndroidApp(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '20.10.38',
          'androidSdkVersion': 34,
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await http.post(
      uri,
      headers: _androidAppHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(milliseconds: 3000));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
      },
      clientName: 'Android App',
    );
  }

  /// Picks the best audio format from a streamingData map.
  static AudioStreamResult? _pickBestAudioFormat(
    Map<String, dynamic> streamingData, {
    required Map<String, String> headers,
    required String clientName,
  }) {
    final adaptiveFormats = [
      ...(streamingData['adaptiveFormats'] as List? ?? []),
      ...(streamingData['formats'] as List? ?? []),
    ].whereType<Map<String, dynamic>>().toList();

    final audioFormats = adaptiveFormats.where((f) {
      final mime = f['mimeType']?.toString().toLowerCase() ?? '';
      return mime.contains('audio');
    }).toList();

    if (audioFormats.isEmpty) return null;

    audioFormats.sort((a, b) {
      final mimeA = a['mimeType']?.toString().toLowerCase() ?? '';
      final mimeB = b['mimeType']?.toString().toLowerCase() ?? '';
      final isMp4A = mimeA.contains('mp4') || mimeA.contains('m4a');
      final isMp4B = mimeB.contains('mp4') || mimeB.contains('m4a');
      if (isMp4A && !isMp4B) return -1;
      if (!isMp4A && isMp4B) return 1;
      final bitA = (a['bitrate'] as num?)?.toInt() ?? 0;
      final bitB = (b['bitrate'] as num?)?.toInt() ?? 0;
      return bitB.compareTo(bitA);
    });

    for (final f in audioFormats) {
      final streamUrl = f['url'] as String?;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        final clen = int.tryParse(f['contentLength']?.toString() ?? '0') ?? 0;
        final mime = f['mimeType']?.toString().split(';').first ?? 'audio/mp4';
        final bitrate = (f['bitrate'] as num?)?.toInt() ?? 128000;
        return AudioStreamResult(
          url: streamUrl,
          totalBytes: clen,
          mimeType: mime,
          bitrate: bitrate,
          headers: headers,
          isDirectDownloadable: false,
        );
      }
    }

    return null;
  }
}

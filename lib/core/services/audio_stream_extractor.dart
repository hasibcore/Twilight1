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

  // iOS App InnerTube Client — Returns direct (non-ciphered) stream URLs reliably
  static const Map<String, String> _iosAppHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)',
    'X-YouTube-Client-Name': '5',
    'X-YouTube-Client-Version': '19.45.4',
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

  // In-memory cache with timestamps (YouTube stream URLs expire ~6 minutes)
  static final Map<String, AudioStreamResult> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
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

  /// Extracts the best playable audio stream URL for a given YouTube video ID.
  static Future<AudioStreamResult?> extractAudioStream(
    String videoId, {
    bool preferDownload = false,
  }) async {
    final cacheKey = '${videoId}_$preferDownload';
    if (_cache.containsKey(cacheKey)) {
      final age = DateTime.now().difference(_cacheTime[cacheKey] ?? DateTime(2000));
      if (age < _cacheTTL) {
        AppLogger.info('Cache hit for $videoId (age: ${age.inSeconds}s)');
        return _cache[cacheKey];
      } else {
        AppLogger.info('Cache expired for $videoId (age: ${age.inSeconds}s), re-fetching');
        _cache.remove(cacheKey);
        _cacheTime.remove(cacheKey);
      }
    }

    // Tier 1: Official iOS App Client
    try {
      final iosResult = await _extractFromIosApp(videoId);
      if (iosResult != null) {
        AppLogger.info('Extracted stream via Tier 1 iOS App for $videoId');
        if (!preferDownload) _setCache(cacheKey, iosResult);
        return iosResult;
      }
    } catch (e) {
      AppLogger.info('Tier 1 iOS App error for $videoId: $e');
    }

    // Tier 2: Mobile Web Client
    try {
      final mwebResult = await _extractFromMweb(videoId);
      if (mwebResult != null) {
        AppLogger.info('Extracted stream via Tier 2 MWEB for $videoId');
        if (!preferDownload) _setCache(cacheKey, mwebResult);
        return mwebResult;
      }
    } catch (e) {
      AppLogger.info('Tier 2 MWEB error for $videoId: $e');
    }

    // Tier 3: Official Android YouTube App client
    try {
      final androidAppResult = await _extractFromAndroidApp(videoId);
      if (androidAppResult != null) {
        AppLogger.info('Extracted stream via Tier 3 Android App for $videoId');
        if (!preferDownload) _setCache(cacheKey, androidAppResult);
        return androidAppResult;
      }
    } catch (e) {
      AppLogger.info('Tier 3 Android App error for $videoId: $e');
    }

    // Tier 4: Android Music Client
    try {
      final androidMusicResult = await _extractFromAndroidMusic(videoId);
      if (androidMusicResult != null) {
        AppLogger.info('Extracted stream via Tier 4 Android Music for $videoId');
        if (!preferDownload) _setCache(cacheKey, androidMusicResult);
        return androidMusicResult;
      }
    } catch (e) {
      AppLogger.info('Tier 4 Android Music error for $videoId: $e');
    }

    // Tier 5: TV Embedded Player
    try {
      final tvResult = await _extractFromTvEmbedded(videoId);
      if (tvResult != null) {
        AppLogger.info('Extracted stream via Tier 5 TV Embedded for $videoId');
        if (!preferDownload) _setCache(cacheKey, tvResult);
        return tvResult;
      }
    } catch (e) {
      AppLogger.info('Tier 5 TV Embedded error for $videoId: $e');
    }

    // Tier 6: YoutubeExplode with TV / MWEB / iOS clients
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.tv, YoutubeApiClient.mweb, YoutubeApiClient.ios],
      ).timeout(const Duration(seconds: 8));
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        final m4a = audioStreams.where((s) =>
            s.container.name.toLowerCase().contains('mp4') ||
            s.container.name.toLowerCase().contains('m4a')).toList();
        final best = m4a.isNotEmpty ? m4a.withHighestBitrate() : audioStreams.withHighestBitrate();
        AppLogger.info('Extracted stream via Tier 6 YoutubeExplode for $videoId');
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
      AppLogger.info('Tier 6 YoutubeExplode error for $videoId: $e');
    }

    // Tier 7: Invidious / Piped Instances
    try {
      final invResult = await _extractFromInvidious(videoId);
      if (invResult != null) {
        AppLogger.info('Extracted stream via Tier 7 Invidious for $videoId');
        _setCache(cacheKey, invResult);
        return invResult;
      }
    } catch (e) {
      AppLogger.info('Tier 7 Invidious error for $videoId: $e');
    }

    AppLogger.error('All audio stream extraction tiers failed for $videoId');
    return null;
  }

  /// Extracts audio via official YouTube iOS App client
  static Future<AudioStreamResult?> _extractFromIosApp(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'IOS',
          'clientVersion': '19.45.4',
          'deviceModel': 'iPhone16,2',
          'osName': 'iOS',
          'osVersion': '17.5.1.21F90',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    AppLogger.info('iOS App Innertube requesting for $videoId...');
    final res = await http.post(
      uri,
      headers: _iosAppHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)',
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

    AppLogger.info('MWEB Innertube requesting for $videoId...');
    final res = await http.post(
      uri,
      headers: _mwebHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 8));

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
    for (final inst in _invidiousInstances) {
      try {
        final uri = Uri.parse('$inst/api/v1/videos/$videoId');
        final res = await http.get(
          uri,
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ).timeout(const Duration(seconds: 5));

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
    ).timeout(const Duration(seconds: 8));

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
    ).timeout(const Duration(seconds: 8));

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
    ).timeout(const Duration(seconds: 8));

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

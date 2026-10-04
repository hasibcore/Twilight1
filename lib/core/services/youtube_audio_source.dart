// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/logger.dart';
import '../../domain/entities/song.dart';
import 'download_service.dart';
import 'audio_stream_extractor.dart';
import 'artwork_service.dart';

/// Custom StreamAudioSource that proxies YouTube audio chunks directly
/// through YoutubeExplode or Dart HTTP client to just_audio's local proxy.
/// This completely eliminates HTTP 403 Forbidden errors from YouTube botguard.
class YouTubeAudioSource extends StreamAudioSource {
  final AudioOnlyStreamInfo? _streamInfo;
  String? _streamUrl;
  Map<String, String>? _headers;
  final int _totalBytes;
  final String _mimeType;
  final File? _cacheFile;
  final MediaItem _mediaItem;

  // In-memory cache for saved-downloads list to avoid JSON parsing on every play
  static List<DownloadItem>? _downloadsCacheSnapshot;
  static DateTime _downloadsCacheTime = DateTime.fromMillisecondsSinceEpoch(0);

  YouTubeAudioSource.fromStreamInfo({
    required YoutubeExplode yt,
    required AudioOnlyStreamInfo streamInfo,
    File? cacheFile,
    required MediaItem mediaItem,
  })  : _streamInfo = streamInfo,
        _streamUrl = streamInfo.url.toString(),
        _headers = const {
          'User-Agent':
              'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
          'Accept': '*/*',
        },
        _totalBytes = streamInfo.size.totalBytes > 0
            ? streamInfo.size.totalBytes
            : ((mediaItem.duration != null && mediaItem.duration!.inSeconds > 0)
                ? (mediaItem.duration!.inSeconds * 32000)
                : 15000000),
        _mimeType = streamInfo.container.name,
        _cacheFile = cacheFile,
        _mediaItem = mediaItem,
        super(tag: mediaItem);

  YouTubeAudioSource.fromUrl({
    required String streamUrl,
    Map<String, String>? headers,
    required int totalBytes,
    required String mimeType,
    File? cacheFile,
    required MediaItem mediaItem,
  })  : _streamInfo = null,
        _streamUrl = streamUrl,
        _headers = headers,
        _totalBytes = totalBytes > 0
            ? totalBytes
            : ((mediaItem.duration != null && mediaItem.duration!.inSeconds > 0)
                ? (mediaItem.duration!.inSeconds * 32000)
                : 15000000),
        _mimeType = mimeType,
        _cacheFile = cacheFile,
        _mediaItem = mediaItem,
        super(tag: mediaItem);

  // Backwards compatible default constructor
  YouTubeAudioSource({
    required YoutubeExplode yt,
    required AudioOnlyStreamInfo streamInfo,
    File? cacheFile,
    required MediaItem mediaItem,
  }) : this.fromStreamInfo(
          yt: yt,
          streamInfo: streamInfo,
          cacheFile: cacheFile,
          mediaItem: mediaItem,
        );

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final estimatedTotal = (_totalBytes > 0)
        ? _totalBytes
        : ((_mediaItem.duration != null && _mediaItem.duration!.inSeconds > 0)
            ? (_mediaItem.duration!.inSeconds * 32000)
            : 15000000);
    final total = estimatedTotal > 0 ? estimatedTotal : 15000000;
    final e = end ?? total;
    final length = (e - s) > 0 ? (e - s) : 1;

    final isMp4 = _mimeType.toLowerCase().contains('mp4') ||
        _mimeType.toLowerCase().contains('m4a');

    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: total,
      contentLength: length,
      offset: s,
      stream: _createResilientStream(s, e),
      contentType: isMp4 ? 'audio/mp4' : 'audio/webm',
    );
  }

  Stream<List<int>> _createResilientStream(int start, int? end) async* {
    int currentPos = start;
    final targetEnd = end;
    int retryAttempts = 0;
    const maxRetries = 10;

    // Open progressive cache sink if streaming from byte 0
    IOSink? cacheSink;
    File? partFile;
    if (start == 0 && _cacheFile != null) {
      try {
        if (!_cacheFile!.parent.existsSync()) {
          _cacheFile!.parent.createSync(recursive: true);
        }
        partFile = File('${_cacheFile!.path}.part');
        cacheSink = partFile.openWrite(mode: FileMode.write);
      } catch (e) {
        AppLogger.warning('Could not open cache sink: $e');
      }
    }

    try {
      while ((targetEnd == null || currentPos < targetEnd) &&
          retryAttempts < maxRetries) {
        http.Client? client;
        try {
          client = http.Client();
          final url = _streamUrl ?? (_streamInfo?.url.toString() ?? '');
          if (url.isEmpty) break;

          final request = http.Request('GET', Uri.parse(url));
          if (_headers != null && _headers!.isNotEmpty) {
            request.headers.addAll(_headers!);
          } else {
            request.headers['User-Agent'] =
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
            request.headers['Accept'] = '*/*';
          }

          // YouTube throttles/rejects range requests larger than ~450KB with HTTP 403.
          // Chunking into safe 256KB blocks prevents HTTP 403 and enables smooth progressive streaming.
          const int maxChunkSize = 256 * 1024;
          final nextTarget = (targetEnd != null)
              ? (currentPos + maxChunkSize < targetEnd
                  ? currentPos + maxChunkSize
                  : targetEnd)
              : (currentPos + maxChunkSize);
          final rangeEnd = (nextTarget > currentPos) ? (nextTarget - 1) : currentPos;
          request.headers['Range'] = 'bytes=$currentPos-$rangeEnd';

          final response =
              await client.send(request).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200 || response.statusCode == 206) {
            retryAttempts = 0; // reset retry counter on successful connection
            int bytesReceivedInChunk = 0;
            await for (final chunk
                in response.stream.timeout(const Duration(seconds: 40))) {
              if (chunk.isNotEmpty) {
                currentPos += chunk.length;
                bytesReceivedInChunk += chunk.length;
                if (cacheSink != null) {
                  cacheSink.add(chunk);
                }
                yield chunk;
              }
            }

            // If we reached targetEnd, we are done
            if (targetEnd != null && currentPos >= targetEnd) {
              break;
            }
            if (bytesReceivedInChunk == 0) {
              retryAttempts++;
              await Future.delayed(Duration(milliseconds: 200 * retryAttempts));
            }
          } else if (response.statusCode == 403 || response.statusCode == 410) {
            // Stream URL expired or rate limited. Refresh it!
            AppLogger.warning(
                'Stream URL status ${response.statusCode} at $currentPos. Refreshing stream...');
            final cleanId = _mediaItem.id.trim();
            if (cleanId.isNotEmpty) {
              AudioStreamExtractor.invalidateCache(cleanId);
              final fresh =
                  await AudioStreamExtractor.extractAudioStream(cleanId);
              if (fresh != null) {
                _streamUrl = fresh.url;
                _headers = fresh.headers;
                retryAttempts++;
                continue;
              }
            }
            retryAttempts++;
            await Future.delayed(Duration(milliseconds: 300 * retryAttempts));
          } else if (response.statusCode == 416) {
            // Reached end of stream (range not satisfiable = file completely delivered)
            AppLogger.info(
                'Reached end of stream (HTTP 416) at byte $currentPos');
            break;
          } else {
            AppLogger.warning(
                'Stream HTTP status ${response.statusCode} at byte $currentPos');
            retryAttempts++;
            await Future.delayed(Duration(milliseconds: 400 * retryAttempts));
          }
        } catch (e) {
          AppLogger.warning('Stream network drop at byte $currentPos: $e');
          retryAttempts++;
          await Future.delayed(Duration(milliseconds: 500 * retryAttempts));
        } finally {
          client?.close();
        }
      }
    } finally {
      if (cacheSink != null) {
        try {
          await cacheSink.flush();
          await cacheSink.close();
        } catch (_) {}

        // Promote to verified progressive cache if complete
        if (partFile != null && partFile.existsSync()) {
          final minExpected =
              _totalBytes > 0 ? (_totalBytes * 0.90).toInt() : 400000;
          if (partFile.lengthSync() >= minExpected && _cacheFile != null) {
            try {
              if (_cacheFile!.existsSync()) _cacheFile!.deleteSync();
              await partFile.rename(_cacheFile!.path);
              final doneFile = File('${_cacheFile!.path}.done');
              await doneFile.writeAsString('1');
              AppLogger.info(
                  'Progressive cache complete: ${_cacheFile!.path} (${_cacheFile!.lengthSync()} bytes)');
            } catch (e) {
              AppLogger.warning('Failed to promote cache file: $e');
            }
          } else {
            // Remove incomplete partial download so it does not waste disk space
            try {
              partFile.deleteSync();
            } catch (_) {}
          }
        }
      }
    }
  }

  /// Called by DownloadService when downloads are added/removed to force
  /// the next resolveAudioSource call to re-read from disk.
  static void invalidateDownloadsCache() {
    _downloadsCacheSnapshot = null;
  }

  /// Resolves an AudioSource for any song:
  /// 1. If downloaded permanently -> AudioSource.file (offline)
  /// 2. If cached in temp -> AudioSource.file (instant offline)
  /// 3. Otherwise -> YouTubeAudioSource (live streaming + background progressive caching)
  static Future<AudioSource> resolveAudioSource({
    required Song song,
    required YoutubeExplode yt,
  }) async {
    final cleanId = song.id.trim();
    final fallbackSecs = song.durationSeconds > 0 ? song.durationSeconds : 210;

    final webMediaItem = MediaItem(
      id: cleanId.isNotEmpty ? cleanId : 'twilight_track',
      album: 'Twilight Music',
      title:
          song.title.trim().isNotEmpty ? song.title.trim() : 'Twilight Track',
      artist: song.artist.trim().isNotEmpty
          ? song.artist.trim()
          : 'Twilight Artist',
      artUri: Uri.tryParse(song.thumbnailUrl),
      duration: Duration(seconds: fallbackSecs),
    );

    if (kIsWeb) {
      final streamResult =
          await AudioStreamExtractor.extractAudioStream(cleanId);
      if (streamResult != null) {
        AppLogger.info(
            'Web playing "${song.title}" via direct AudioSource.uri');
        return AudioSource.uri(
          Uri.parse(streamResult.url),
          tag: webMediaItem,
        );
      }

      try {
        final manifest = await yt.videos.streamsClient
            .getManifest(cleanId)
            .timeout(const Duration(seconds: 8));
        final audioStreams = manifest.audioOnly.toList();
        if (audioStreams.isNotEmpty) {
          final bestStream = audioStreams.withHighestBitrate();
          AppLogger.info(
              'Web playing "${song.title}" via YoutubeExplode AudioSource.uri');
          return AudioSource.uri(
            Uri.parse(bestStream.url.toString()),
            tag: webMediaItem,
          );
        }
      } catch (e) {
        AppLogger.info('Web direct manifest fallback failed: $e');
      }

      throw Exception(
          'No playable web audio stream available for "${song.title}"');
    }

    // 1. Check permanent offline downloads (uses in-memory cache, refreshes every 30s)
    final now = DateTime.now();
    if (_downloadsCacheSnapshot == null ||
        now.difference(_downloadsCacheTime).inSeconds > 30) {
      _downloadsCacheSnapshot = DownloadService.loadSavedDownloads();
      _downloadsCacheTime = now;
    }

    Uri? artUri;

    // Build a lightweight fallback mediaItem with thumbnail URL (no local file needed yet)
    // The artwork service will cache the thumbnail in the background for future plays.
    MediaItem buildMediaItem(Uri? art) => MediaItem(
          id: cleanId.isNotEmpty ? cleanId : 'twilight_track',
          album: 'Twilight Music',
          title: song.title.trim().isNotEmpty
              ? song.title.trim()
              : 'Twilight Track',
          artist: song.artist.trim().isNotEmpty
              ? song.artist.trim()
              : 'Twilight Artist',
          artUri: art,
          duration: Duration(seconds: fallbackSecs),
        );

    for (final d in _downloadsCacheSnapshot!) {
      if ((d.song.id == cleanId || d.song.id == song.id) &&
          File(d.localFilePath).existsSync()) {
        // For offline playback, we need the local artwork — fetch it (fast, local FS only)
        artUri = await ArtworkService.getArtworkUri(
          thumbnailUrl: song.thumbnailUrl,
          songId: cleanId,
        );
        AppLogger.info(
            'Playing "${song.title}" from permanent offline downloads');
        final mediaItem = buildMediaItem(artUri);
        return AudioSource.file(
          d.localFilePath,
          tag: mediaItem.copyWith(
            album: 'Twilight Offline',
            artUri: (d.localThumbnailPath != null &&
                    d.localThumbnailPath!.isNotEmpty &&
                    File(d.localThumbnailPath!).existsSync())
                ? Uri.file(d.localThumbnailPath!)
                : mediaItem.artUri,
          ),
        );
      }
    }

    // 2. Check local temporary progressive cache directory
    final tempDir = await getTemporaryDirectory();
    final cacheFileM4a = File('${tempDir.path}/twilight_cache_$cleanId.m4a');
    final cacheFileWebm = File('${tempDir.path}/twilight_cache_$cleanId.webm');
    final doneM4a = File('${tempDir.path}/twilight_cache_$cleanId.m4a.done');
    final doneWebm = File('${tempDir.path}/twilight_cache_$cleanId.webm.done');

    if (cacheFileM4a.existsSync() &&
        doneM4a.existsSync() &&
        cacheFileM4a.lengthSync() > 100000) {
      artUri = await ArtworkService.getArtworkUri(
          thumbnailUrl: song.thumbnailUrl, songId: cleanId);
      AppLogger.info(
          'Playing "${song.title}" from verified local progressive cache (m4a)');
      return AudioSource.file(cacheFileM4a.path, tag: buildMediaItem(artUri));
    }
    if (cacheFileWebm.existsSync() &&
        doneWebm.existsSync() &&
        cacheFileWebm.lengthSync() > 100000) {
      artUri = await ArtworkService.getArtworkUri(
          thumbnailUrl: song.thumbnailUrl, songId: cleanId);
      AppLogger.info(
          'Playing "${song.title}" from verified local progressive cache (webm)');
      return AudioSource.file(cacheFileWebm.path, tag: buildMediaItem(artUri));
    }
    // Clean up any unverified or corrupt cache file
    if (cacheFileM4a.existsSync() && !doneM4a.existsSync()) {
      try {
        cacheFileM4a.deleteSync();
      } catch (_) {}
    }
    if (cacheFileWebm.existsSync() && !doneWebm.existsSync()) {
      try {
        cacheFileWebm.deleteSync();
      } catch (_) {}
    }

    // 3. NETWORK PATH: Run stream resolution & artwork fetch IN PARALLEL
    // Stream resolution (300-500ms Tier1) and thumbnail HTTP download no longer block each other.
    final results = await Future.wait([
      AudioStreamExtractor.extractAudioStream(cleanId),
      ArtworkService.getArtworkUri(
          thumbnailUrl: song.thumbnailUrl, songId: cleanId),
    ]);

    final streamResult = results[0] as AudioStreamResult?;
    artUri = results[1] as Uri?;
    final mediaItem = buildMediaItem(artUri);

    if (streamResult != null) {
      AppLogger.info(
          'Streaming "${song.title}" via YouTubeAudioSource proxy (${streamResult.mimeType}, ${streamResult.bitrate}bps)');
      final isMp4 = streamResult.mimeType.toLowerCase().contains('mp4') ||
          streamResult.mimeType.toLowerCase().contains('m4a');
      final cacheFile = File(
          '${tempDir.path}/twilight_cache_$cleanId.${isMp4 ? "m4a" : "webm"}');
      return YouTubeAudioSource.fromUrl(
        streamUrl: streamResult.url,
        headers: streamResult.headers,
        totalBytes: streamResult.totalBytes,
        mimeType: streamResult.mimeType,
        cacheFile: cacheFile,
        mediaItem: mediaItem,
      );
    }

    // 4. Secondary Fallback: Direct YoutubeExplode streamsClient with fast 8s timeout
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(
            cleanId,
          )
          .timeout(const Duration(seconds: 8));

      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isNotEmpty) {
        final mp4Streams = audioStreams
            .where((s) =>
                s.container.name.toLowerCase().contains('mp4') ||
                s.container.name.toLowerCase().contains('m4a'))
            .toList();

        final bestStream = mp4Streams.isNotEmpty
            ? mp4Streams.withHighestBitrate()
            : audioStreams.withHighestBitrate();

        AppLogger.info(
            'Streaming "${song.title}" via YouTubeAudioSource.fromStreamInfo (${bestStream.container.name}, ${bestStream.bitrate})');

        final isMp4 = bestStream.container.name.toLowerCase().contains('mp4') ||
            bestStream.container.name.toLowerCase().contains('m4a');
        final cacheFile = File(
            '${tempDir.path}/twilight_cache_$cleanId.${isMp4 ? "m4a" : "webm"}');

        return YouTubeAudioSource.fromStreamInfo(
          yt: yt,
          streamInfo: bestStream,
          cacheFile: cacheFile,
          mediaItem: mediaItem,
        );
      }
    } catch (e) {
      AppLogger.info('Direct getManifest fallback failed for $cleanId: $e');
    }

    throw Exception('No playable audio stream available for "${song.title}"');
  }
}

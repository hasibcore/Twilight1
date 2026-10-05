import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../data/models/song_model.dart';
import '../../domain/entities/song.dart';
import '../utils/logger.dart';
import 'audio_stream_extractor.dart';
import 'local_storage_service.dart';
import 'youtube_audio_source.dart';

import 'music_import_service.dart';

class DownloadItem {
  final Song song;
  final String localFilePath;
  final String? localThumbnailPath;
  final int downloadedAtMillis;
  final int fileSize;

  DownloadItem({
    required this.song,
    required this.localFilePath,
    this.localThumbnailPath,
    required this.downloadedAtMillis,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
        'song': SongModel.fromEntity(song).toJson(),
        'localFilePath': localFilePath,
        'localThumbnailPath': localThumbnailPath,
        'downloadedAtMillis': downloadedAtMillis,
        'fileSize': fileSize,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        song: SongModel.fromJson(
          json['song'] is Map ? Map<String, dynamic>.from(json['song'] as Map) : {},
        ).toEntity(),
        localFilePath: json['localFilePath'] as String? ?? '',
        localThumbnailPath: json['localThumbnailPath'] as String?,
        downloadedAtMillis: (json['downloadedAtMillis'] as num?)?.toInt() ?? 0,
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      );
}

class DownloadService {
  static const String _storageKey = 'twilight_downloaded_tracks';
  static final Set<String> _cancelledDownloads = <String>{};

  static void cancelDownload(String songId) {
    _cancelledDownloads.add(songId);
    try {
      final cleanId = songId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      _cancelledDownloads.add(cleanId);
    } catch (_) {}
  }

  static bool isDownloadCancelled(String songId) {
    return _cancelledDownloads.contains(songId);
  }

  static Future<Directory> getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/twilight_downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static List<DownloadItem> loadSavedDownloads() {
    if (kIsWeb) return [];
    try {
      final jsonList = LocalStorageService.getStringList(_storageKey);
      final items = <DownloadItem>[];
      for (final str in jsonList) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final item = DownloadItem.fromJson(map);
        // Verify audio file still exists on disk and is non-empty
        final file = File(item.localFilePath);
        if (file.existsSync() && file.lengthSync() > 10000) {
          items.add(item);
        }
      }
      return items;
    } catch (e) {
      AppLogger.error('Failed to load saved downloads', e);
      return [];
    }
  }

  static Future<void> _saveDownloads(List<DownloadItem> items) async {
    final list = items.map((i) => jsonEncode(i.toJson())).toList();
    await LocalStorageService.setStringList(_storageKey, list);
  }

  static final YoutubeExplode _yt = YoutubeExplode();

  static Future<DownloadItem?> downloadTrack({
    required Song song,
    required void Function(double progress) onProgress,
  }) async {
    String? tmpFilePath;
    try {
      Song targetSong = song;
      if (song.id.startsWith('sp_')) {
        final resolved = await MusicImportService().resolveStreamTrack(song);
        if (resolved != null) {
          targetSong = resolved;
        }
      }
      String cleanId = targetSong.id.trim();
      try {
        cleanId = VideoId(cleanId).value;
      } catch (_) {
        cleanId = cleanId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      }

      _cancelledDownloads.remove(song.id);
      _cancelledDownloads.remove(cleanId);

      onProgress(0.08);

      final dir = await getDownloadsDirectory();
      final audioFilePath = '${dir.path}/$cleanId.m4a';
      final thumbFilePath = '${dir.path}/$cleanId.jpg';
      tmpFilePath = '${dir.path}/$cleanId.tmp';
      int finalFileSize = 0;

      // 1. Check if already cached in verified progressive cache
      final tempDir = await getTemporaryDirectory();
      final cacheM4a = File('${tempDir.path}/twilight_cache_$cleanId.m4a');
      final cacheWebm = File('${tempDir.path}/twilight_cache_$cleanId.webm');
      final doneM4a = File('${tempDir.path}/twilight_cache_$cleanId.m4a.done');
      final doneWebm = File('${tempDir.path}/twilight_cache_$cleanId.webm.done');

      File? sourceCached;
      if (cacheM4a.existsSync() && doneM4a.existsSync() && cacheM4a.lengthSync() > 100000) {
        sourceCached = cacheM4a;
      } else if (cacheWebm.existsSync() && doneWebm.existsSync() && cacheWebm.lengthSync() > 100000) {
        sourceCached = cacheWebm;
      }

      if (sourceCached != null) {
        onProgress(0.50);
        await sourceCached.copy(audioFilePath);
        finalFileSize = sourceCached.lengthSync();
        onProgress(0.90);
      } else {
        // 2. Resolve audio stream URL with multi-tiered extractor priority
        onProgress(0.15);
        String? streamUrl;
        Map<String, String> streamHeaders = {};
        int streamTotalBytes = 0;

        // Try Tier A: AudioStreamExtractor (Fast direct iOS/TV clients without throttle)
        try {
          final streamResult = await AudioStreamExtractor.extractAudioStream(
            cleanId,
            preferDownload: true,
          ).timeout(const Duration(seconds: 8));
          if (streamResult != null && streamResult.url.isNotEmpty) {
            streamUrl = streamResult.url;
            streamHeaders = streamResult.headers;
            streamTotalBytes = streamResult.totalBytes;
          }
        } catch (e) {
          AppLogger.info('AudioStreamExtractor download resolution error: $e');
        }

        // Try Tier B: YoutubeExplode TV / MWEB clients fallback
        if (streamUrl == null) {
          try {
            final manifest = await _yt.videos.streamsClient.getManifest(
              cleanId,
              ytClients: [YoutubeApiClient.tv, YoutubeApiClient.mweb, YoutubeApiClient.ios],
            ).timeout(const Duration(seconds: 9));
            final audios = manifest.audioOnly.toList();
            if (audios.isNotEmpty) {
              final mp4s = audios.where((s) =>
                  s.container.name.toLowerCase().contains('mp4') ||
                  s.container.name.toLowerCase().contains('m4a')).toList();
              final bestStream = mp4s.isNotEmpty
                  ? mp4s.withHighestBitrate()
                  : audios.withHighestBitrate();
              streamUrl = bestStream.url.toString();
              streamTotalBytes = bestStream.size.totalBytes;
              streamHeaders = {
                'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15',
              };
            }
          } catch (e) {
            AppLogger.info('YoutubeExplode manifest download error: $e');
          }
        }

        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception('Could not resolve playable audio stream for "${song.title}"');
        }

        if (_cancelledDownloads.contains(cleanId) || _cancelledDownloads.contains(song.id)) {
          throw Exception('Download cancelled by user');
        }

        // 3. Download using resilient chunked Range requests to prevent CDN bandwidth throttling
        final downloadedBytes = await _downloadUrlWithResilientRanges(
          url: streamUrl,
          headers: streamHeaders,
          tmpFilePath: tmpFilePath,
          knownTotalBytes: streamTotalBytes,
          songId: cleanId,
          onProgress: onProgress,
        );

        if (_cancelledDownloads.contains(cleanId) || _cancelledDownloads.contains(song.id)) {
          throw Exception('Download cancelled by user');
        }

        final tmpFile = File(tmpFilePath);
        if (!tmpFile.existsSync() || tmpFile.lengthSync() < 10000) {
          throw Exception('Downloaded file is incomplete or empty.');
        }

        final finalAudioFile = File(audioFilePath);
        if (await finalAudioFile.exists()) {
          await finalAudioFile.delete();
        }
        await tmpFile.rename(audioFilePath);
        finalFileSize = downloadedBytes > 0 ? downloadedBytes : finalAudioFile.lengthSync();
      }

      onProgress(0.92);

      // 4. Download thumbnail for offline artwork display (4s timeout)
      String? savedThumbPath;
      if (song.thumbnailUrl.isNotEmpty) {
        try {
          final uri = Uri.tryParse(song.thumbnailUrl);
          if (uri != null) {
            final thumbRes = await http.get(uri).timeout(const Duration(seconds: 4));
            if (thumbRes.statusCode == 200) {
              final thumbFile = File(thumbFilePath);
              await thumbFile.writeAsBytes(thumbRes.bodyBytes);
              savedThumbPath = thumbFilePath;
            }
          }
        } catch (e) {
          AppLogger.info('Could not cache thumbnail for download: $e');
        }
      }

      onProgress(1.0);

      final cleanSong = Song(
        id: song.id,
        title: song.title.isNotEmpty ? song.title : targetSong.title,
        artist: song.artist.isNotEmpty ? song.artist : targetSong.artist,
        channelId: song.channelId.isNotEmpty ? song.channelId : targetSong.channelId,
        thumbnailUrl: (savedThumbPath != null && File(savedThumbPath).existsSync())
            ? savedThumbPath
            : (song.thumbnailUrl.isNotEmpty ? song.thumbnailUrl : targetSong.thumbnailUrl),
        durationSeconds: song.durationSeconds > 0 ? song.durationSeconds : targetSong.durationSeconds,
        durationFormatted: song.durationFormatted.isNotEmpty ? song.durationFormatted : targetSong.durationFormatted,
        viewCount: song.viewCount,
        publishedAt: song.publishedAt,
        isFavorite: song.isFavorite,
      );

      final item = DownloadItem(
        song: cleanSong,
        localFilePath: audioFilePath,
        localThumbnailPath: savedThumbPath,
        downloadedAtMillis: DateTime.now().millisecondsSinceEpoch,
        fileSize: finalFileSize > 0 ? finalFileSize : (File(audioFilePath).existsSync() ? File(audioFilePath).lengthSync() : 0),
      );

      // Persist in metadata
      final currentList = loadSavedDownloads();
      currentList.removeWhere((i) => i.song.id == song.id || i.song.id == cleanId || i.localFilePath.contains(cleanId));
      currentList.insert(0, item);
      await _saveDownloads(currentList);

      AppLogger.info('Successfully downloaded track: "${song.title}" (${(finalFileSize / (1024 * 1024)).toStringAsFixed(1)} MB)');

      // Invalidate in-memory downloads cache so next play sees this file
      YouTubeAudioSource.invalidateDownloadsCache();

      return item;
    } catch (e) {
      AppLogger.error('Download failed for ${song.title}: $e');
      try {
        if (tmpFilePath != null) {
          final tmpFile = File(tmpFilePath);
          if (tmpFile.existsSync()) {
            tmpFile.deleteSync();
          }
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Downloads stream with Range requests to avoid 20KB/s throttling & infinite stalls
  static Future<int> _downloadUrlWithResilientRanges({
    required String url,
    required Map<String, String> headers,
    required String tmpFilePath,
    required int knownTotalBytes,
    required String songId,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(tmpFilePath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    final sink = file.openWrite();
    int downloadedBytes = 0;
    int totalBytes = knownTotalBytes;

    final client = http.Client();
    try {
      // 1. If total bytes unknown, query HEAD with 4s timeout
      if (totalBytes <= 0) {
        try {
          final headRes = await client.head(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4));
          if (headRes.contentLength != null && headRes.contentLength! > 0) {
            totalBytes = headRes.contentLength!;
          }
        } catch (_) {}
      }

      // 2. Segmented Range requests: 512 KB per chunk to bypass bandwidth throttles
      const int chunkSize = 512 * 1024;

      if (totalBytes > 0) {
        while (downloadedBytes < totalBytes) {
          if (_cancelledDownloads.contains(songId)) {
            throw Exception('Download cancelled by user');
          }

          final int start = downloadedBytes;
          final int end = (start + chunkSize - 1) < totalBytes ? (start + chunkSize - 1) : (totalBytes - 1);

          bool chunkSuccess = false;
          int retries = 0;

          while (!chunkSuccess && retries < 3) {
            if (_cancelledDownloads.contains(songId)) {
              throw Exception('Download cancelled by user');
            }
            try {
              final rangeHeaders = Map<String, String>.from(headers);
              rangeHeaders['Range'] = 'bytes=$start-$end';

              final req = http.Request('GET', Uri.parse(url));
              req.headers.addAll(rangeHeaders);

              final streamedRes = await client.send(req).timeout(const Duration(seconds: 10));
              if (streamedRes.statusCode == 200 || streamedRes.statusCode == 206) {
                int bytesInThisChunk = 0;
                await for (final chunk in streamedRes.stream.timeout(const Duration(seconds: 8))) {
                  sink.add(chunk);
                  downloadedBytes += chunk.length;
                  bytesInThisChunk += chunk.length;
                  final progress = 0.15 + (0.75 * (downloadedBytes / totalBytes));
                  onProgress(progress.clamp(0.15, 0.92));
                }

                // If EOF reached (0 bytes in response) or end of file reached
                if (bytesInThisChunk == 0) {
                  chunkSuccess = true;
                  downloadedBytes = totalBytes; // Successfully reached end of audio stream
                  break;
                }
                chunkSuccess = true;
              } else if (streamedRes.statusCode == 416) {
                // Range Not Satisfiable: Stream has finished sending all bytes
                chunkSuccess = true;
                downloadedBytes = totalBytes;
                break;
              } else {
                retries++;
                await Future.delayed(const Duration(milliseconds: 300));
              }
            } catch (e) {
              retries++;
              await Future.delayed(const Duration(milliseconds: 350));
              if (retries >= 3) {
                // If more than 85% of file is already downloaded, finalize rather than fail at 99%
                if (downloadedBytes >= (totalBytes * 0.85).toInt()) {
                  chunkSuccess = true;
                  downloadedBytes = totalBytes;
                  break;
                }
                rethrow;
              }
            }
          }

          if (downloadedBytes >= totalBytes) break;
        }
      } else {
        // Fallback single stream with chunk timeout watchdog
        final req = http.Request('GET', Uri.parse(url));
        req.headers.addAll(headers);
        final streamedRes = await client.send(req).timeout(const Duration(seconds: 10));
        if (streamedRes.statusCode != 200 && streamedRes.statusCode != 206) {
          throw Exception('Stream HTTP status ${streamedRes.statusCode}');
        }
        final streamTotal = streamedRes.contentLength ?? 4000000;
        await for (final chunk in streamedRes.stream.timeout(const Duration(seconds: 8))) {
          if (_cancelledDownloads.contains(songId)) {
            throw Exception('Download cancelled by user');
          }
          sink.add(chunk);
          downloadedBytes += chunk.length;
          final progress = 0.15 + (0.75 * (downloadedBytes / streamTotal));
          onProgress(progress.clamp(0.15, 0.90));
        }
      }

      await sink.flush();
      await sink.close();
      return downloadedBytes;
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  static Future<void> deleteTrack(String songId) async {
    try {
      final currentList = loadSavedDownloads();
      final toDelete = currentList.where(
        (i) => i.song.id == songId || i.localFilePath.contains(songId),
      ).toList();

      for (final item in toDelete) {
        if (item.localFilePath.isNotEmpty) {
          final audioFile = File(item.localFilePath);
          if (audioFile.existsSync()) {
            try {
              audioFile.deleteSync();
            } catch (_) {}
          }
        }
        if (item.localThumbnailPath != null && item.localThumbnailPath!.isNotEmpty) {
          final thumbFile = File(item.localThumbnailPath!);
          if (thumbFile.existsSync()) {
            try {
              thumbFile.deleteSync();
            } catch (_) {}
          }
        }
      }

      currentList.removeWhere((i) => i.song.id == songId || i.localFilePath.contains(songId));
      await _saveDownloads(currentList);
      AppLogger.info('Deleted download for $songId');

      // Invalidate in-memory downloads cache
      YouTubeAudioSource.invalidateDownloadsCache();
    } catch (e) {
      AppLogger.error('Failed to delete download for $songId: $e');
    }
  }
}

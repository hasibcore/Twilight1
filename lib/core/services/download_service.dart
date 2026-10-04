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
          json['song'] is Map
              ? Map<String, dynamic>.from(json['song'] as Map)
              : {},
        ).toEntity(),
        localFilePath: json['localFilePath'] as String? ?? '',
        localThumbnailPath: json['localThumbnailPath'] as String?,
        downloadedAtMillis: (json['downloadedAtMillis'] as num?)?.toInt() ?? 0,
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      );
}

class DownloadService {
  static const String _storageKey = 'twilight_downloaded_tracks';

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
      onProgress(0.05);
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
      final doneWebm =
          File('${tempDir.path}/twilight_cache_$cleanId.webm.done');

      File? sourceCached;
      if (cacheM4a.existsSync() &&
          doneM4a.existsSync() &&
          cacheM4a.lengthSync() > 100000) {
        sourceCached = cacheM4a;
      } else if (cacheWebm.existsSync() &&
          doneWebm.existsSync() &&
          cacheWebm.lengthSync() > 100000) {
        sourceCached = cacheWebm;
      }

      if (sourceCached != null) {
        onProgress(0.50);
        await sourceCached.copy(audioFilePath);
        finalFileSize = sourceCached.lengthSync();
        onProgress(0.90);
      } else {
        // 2. Download audio stream directly via YoutubeExplode streamsClient with resilient fallback
        onProgress(0.15);
        bool downloadSuccess = false;

        try {
          final manifest = await _yt.videos.streamsClient.getManifest(
            cleanId,
            ytClients: [
              YoutubeApiClient.android,
              YoutubeApiClient.androidSdkless
            ],
          );
          final audios = manifest.audioOnly.toList();
          if (audios.isNotEmpty) {
            final mp4s = audios
                .where((s) =>
                    s.container.name.toLowerCase().contains('mp4') ||
                    s.container.name.toLowerCase().contains('m4a'))
                .toList();
            final bestStream = mp4s.isNotEmpty
                ? mp4s.withHighestBitrate()
                : audios.withHighestBitrate();

            final totalBytes = bestStream.size.totalBytes;
            int downloadedBytes = 0;

            final file = File(tmpFilePath);
            final sink = file.openWrite();

            try {
              final stream = _yt.videos.streamsClient.get(bestStream);
              await for (final chunk in stream) {
                sink.add(chunk);
                downloadedBytes += chunk.length;
                if (totalBytes > 0) {
                  final progress =
                      0.15 + (0.75 * (downloadedBytes / totalBytes));
                  onProgress(progress.clamp(0.15, 0.90));
                }
              }
              await sink.flush();
            } finally {
              await sink.close();
            }

            final finalAudioFile = File(audioFilePath);
            if (await finalAudioFile.exists()) {
              await finalAudioFile.delete();
            }
            await file.rename(audioFilePath);
            finalFileSize = downloadedBytes;
            downloadSuccess = true;
          }
        } catch (e) {
          AppLogger.info(
              'Direct streamsClient download error, attempting stream extractor fallback: $e');
        }

        // Fallback: extract audio stream via multi-tiered extractor (Invidious / iOS client)
        if (!downloadSuccess) {
          final streamResult = await AudioStreamExtractor.extractAudioStream(
            cleanId,
            preferDownload: true,
          );
          if (streamResult == null) {
            throw Exception(
                'Could not resolve playable audio stream for "${song.title}"');
          }

          final client = http.Client();
          try {
            final request = http.Request('GET', Uri.parse(streamResult.url));
            if (streamResult.headers.isNotEmpty) {
              request.headers.addAll(streamResult.headers);
            }

            final response = await client.send(request);
            if (response.statusCode != 200 && response.statusCode != 206) {
              throw Exception(
                  'Stream download HTTP error: ${response.statusCode}');
            }

            final totalBytes =
                response.contentLength ?? streamResult.totalBytes;
            int downloadedBytes = 0;
            final file = File(tmpFilePath);
            final sink = file.openWrite();

            try {
              await for (final chunk in response.stream) {
                sink.add(chunk);
                downloadedBytes += chunk.length;
                if (totalBytes > 0) {
                  final progress =
                      0.15 + (0.75 * (downloadedBytes / totalBytes));
                  onProgress(progress.clamp(0.15, 0.90));
                }
              }
              await sink.flush();
            } finally {
              await sink.close();
            }

            final finalAudioFile = File(audioFilePath);
            if (await finalAudioFile.exists()) {
              await finalAudioFile.delete();
            }
            await file.rename(audioFilePath);
            finalFileSize = downloadedBytes;
          } finally {
            client.close();
          }
        }
      }

      onProgress(0.92);

      // 3. Download thumbnail for offline artwork display
      String? savedThumbPath;
      if (song.thumbnailUrl.isNotEmpty) {
        try {
          final uri = Uri.tryParse(song.thumbnailUrl);
          if (uri != null) {
            final thumbRes =
                await http.get(uri).timeout(const Duration(seconds: 8));
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
        channelId:
            song.channelId.isNotEmpty ? song.channelId : targetSong.channelId,
        thumbnailUrl:
            (savedThumbPath != null && File(savedThumbPath).existsSync())
                ? savedThumbPath
                : (song.thumbnailUrl.isNotEmpty
                    ? song.thumbnailUrl
                    : targetSong.thumbnailUrl),
        durationSeconds: song.durationSeconds > 0
            ? song.durationSeconds
            : targetSong.durationSeconds,
        durationFormatted: song.durationFormatted.isNotEmpty
            ? song.durationFormatted
            : targetSong.durationFormatted,
        viewCount: song.viewCount,
        publishedAt: song.publishedAt,
        isFavorite: song.isFavorite,
      );

      final item = DownloadItem(
        song: cleanSong,
        localFilePath: audioFilePath,
        localThumbnailPath: savedThumbPath,
        downloadedAtMillis: DateTime.now().millisecondsSinceEpoch,
        fileSize: finalFileSize > 0
            ? finalFileSize
            : (File(audioFilePath).existsSync()
                ? File(audioFilePath).lengthSync()
                : 0),
      );

      // Persist in metadata
      final currentList = loadSavedDownloads();
      currentList.removeWhere((i) =>
          i.song.id == song.id ||
          i.song.id == cleanId ||
          i.localFilePath.contains(cleanId));
      currentList.insert(0, item);
      await _saveDownloads(currentList);

      AppLogger.info(
          'Successfully downloaded track: "${song.title}" (${(finalFileSize / (1024 * 1024)).toStringAsFixed(1)} MB)');

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

  static Future<void> deleteTrack(String songId) async {
    try {
      final currentList = loadSavedDownloads();
      final toDelete = currentList
          .where(
            (i) => i.song.id == songId || i.localFilePath.contains(songId),
          )
          .toList();

      for (final item in toDelete) {
        if (item.localFilePath.isNotEmpty) {
          final audioFile = File(item.localFilePath);
          if (audioFile.existsSync()) {
            try {
              audioFile.deleteSync();
            } catch (_) {}
          }
        }
        if (item.localThumbnailPath != null &&
            item.localThumbnailPath!.isNotEmpty) {
          final thumbFile = File(item.localThumbnailPath!);
          if (thumbFile.existsSync()) {
            try {
              thumbFile.deleteSync();
            } catch (_) {}
          }
        }
      }

      currentList.removeWhere(
          (i) => i.song.id == songId || i.localFilePath.contains(songId));
      await _saveDownloads(currentList);
      AppLogger.info('Deleted download for $songId');

      // Invalidate in-memory downloads cache
      YouTubeAudioSource.invalidateDownloadsCache();
    } catch (e) {
      AppLogger.error('Failed to delete download for $songId: $e');
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/song.dart';

class DownloadProvider extends ChangeNotifier {
  List<DownloadItem> _downloads = [];
  final Map<String, double> _downloadProgress = {};
  final Set<String> _activeDownloads = {};
  String? _lastError;

  DownloadProvider() {
    _loadInitialDownloads();
  }

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  List<Song> get downloadedSongs => _downloads.map((d) => d.song).toList();
  int get count => _downloads.length;
  String? get lastError => _lastError;

  bool isDownloaded(String songId) {
    return _downloads.any((d) => d.song.id == songId || d.localFilePath.contains(songId));
  }

  bool isDownloading(String songId) {
    return _activeDownloads.contains(songId);
  }

  double getProgress(String songId) {
    return _downloadProgress[songId] ?? 0.0;
  }

  DownloadItem? getDownloadItem(String songId) {
    try {
      return _downloads.firstWhere((d) => d.song.id == songId || d.localFilePath.contains(songId));
    } catch (_) {
      return null;
    }
  }

  void _loadInitialDownloads() {
    _downloads = DownloadService.loadSavedDownloads();
    notifyListeners();
  }

  Future<bool> startDownload(Song song) async {
    if (isDownloaded(song.id) || isDownloading(song.id)) {
      return true;
    }

    _activeDownloads.add(song.id);
    _downloadProgress[song.id] = 0.08;
    _lastError = null;
    notifyListeners();

    try {
      final item = await DownloadService.downloadTrack(
        song: song,
        onProgress: (progress) {
          _downloadProgress[song.id] = progress;
          notifyListeners();
        },
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Download timed out after 45 seconds. Please check your connection.');
        },
      );

      if (item != null) {
        _downloads.removeWhere((d) => d.song.id == song.id);
        _downloads.insert(0, item);
      } else {
        _lastError = 'Download could not resolve a stream.';
      }
      _activeDownloads.remove(song.id);
      _downloadProgress.remove(song.id);
      notifyListeners();
      return item != null;
    } catch (e) {
      _lastError = 'Download failed: $e';
      _activeDownloads.remove(song.id);
      _downloadProgress.remove(song.id);
      notifyListeners();
      return false;
    }
  }

  void cancelDownload(String songId) {
    DownloadService.cancelDownload(songId);
    _activeDownloads.remove(songId);
    _downloadProgress.remove(songId);
    _lastError = 'Download cancelled';
    notifyListeners();
  }

  Future<void> deleteDownload(String songId) async {
    await DownloadService.deleteTrack(songId);
    _downloads.removeWhere((d) => d.song.id == songId || d.localFilePath.contains(songId));
    notifyListeners();
  }
}

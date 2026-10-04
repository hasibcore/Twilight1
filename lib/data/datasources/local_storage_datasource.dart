import 'dart:convert';
import '../../core/services/local_storage_service.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';

class LocalStorageDatasource {
  static const String _keyRecentlyPlayed = 'mt_recently_played';
  static const String _keyFavorites = 'mt_favorites';
  static const String _keyPlaylists = 'mt_user_playlists';
  static const String _keySearchHistory = 'mt_search_history';

  // Recently Played
  Future<List<SongModel>> getRecentlyPlayed() async {
    final list = LocalStorageService.getStringList(_keyRecentlyPlayed);
    return list
        .map((item) {
          try {
            return SongModel.fromJson(jsonDecode(item));
          } catch (_) {
            return null;
          }
        })
        .whereType<SongModel>()
        .toList();
  }

  Future<void> addRecentlyPlayed(SongModel song) async {
    final list = await getRecentlyPlayed();
    // Remove if already exists to push to front
    list.removeWhere((s) => s.id == song.id);
    list.insert(0, song);
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }
    final stringList = list.map((s) => jsonEncode(s.toJson())).toList();
    await LocalStorageService.setStringList(_keyRecentlyPlayed, stringList);
  }

  Future<void> clearRecentlyPlayed() async {
    await LocalStorageService.remove(_keyRecentlyPlayed);
  }

  // Favorites
  Future<List<SongModel>> getFavorites() async {
    final list = LocalStorageService.getStringList(_keyFavorites);
    return list
        .map((item) {
          try {
            return SongModel.fromJson(jsonDecode(item));
          } catch (_) {
            return null;
          }
        })
        .whereType<SongModel>()
        .toList();
  }

  Future<void> toggleFavorite(SongModel song) async {
    final list = await getFavorites();
    final index = list.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.insert(0, song.copyWithFavorite(true));
    }
    final stringList = list.map((s) => jsonEncode(s.toJson())).toList();
    await LocalStorageService.setStringList(_keyFavorites, stringList);
  }

  Future<bool> isFavorite(String songId) async {
    final list = await getFavorites();
    return list.any((s) => s.id == songId);
  }

  // Playlists
  Future<List<PlaylistModel>> getUserPlaylists() async {
    final raw = LocalStorageService.getString(_keyPlaylists);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(raw);
      // Filter out any legacy demo/starter playlist IDs
      final demoIds = {'pl_favorites', 'pl_workout', 'pl_chill', 'pl_bangla'};
      final List<PlaylistModel> playlists = [];
      for (final item in list) {
        if (item is Map) {
          try {
            final model =
                PlaylistModel.fromJson(Map<String, dynamic>.from(item));
            if (!demoIds.contains(model.id)) {
              playlists.add(model);
            }
          } catch (_) {}
        }
      }
      return playlists;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUserPlaylists(List<PlaylistModel> playlists) async {
    final raw = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await LocalStorageService.setString(_keyPlaylists, raw);
  }

  // Search History
  Future<List<String>> getSearchHistory() async {
    return LocalStorageService.getStringList(_keySearchHistory);
  }

  Future<void> addSearchHistory(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final list = await getSearchHistory();
    list.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    list.insert(0, clean);
    if (list.length > 20) {
      list.removeRange(20, list.length);
    }
    await LocalStorageService.setStringList(_keySearchHistory, list);
  }

  Future<void> clearSearchHistory() async {
    await LocalStorageService.remove(_keySearchHistory);
  }
}

extension SongModelExtension on SongModel {
  SongModel copyWithFavorite(bool isFav) {
    return SongModel(
      id: id,
      title: title,
      artist: artist,
      channelId: channelId,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      durationFormatted: durationFormatted,
      viewCount: viewCount,
      publishedAt: publishedAt,
      isFavorite: isFav,
    );
  }
}

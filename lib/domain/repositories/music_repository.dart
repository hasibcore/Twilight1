import 'package:flutter/foundation.dart';
import '../entities/song.dart';
import '../entities/playlist.dart';

abstract class MusicRepository {
  void addChangeListener(VoidCallback listener) {}
  void removeChangeListener(VoidCallback listener) {}

  Future<List<Song>> getRecentlyPlayed();
  Future<void> addRecentlyPlayed(Song song);
  Future<void> clearRecentlyPlayed();

  Future<List<Song>> getFavorites();
  Future<void> toggleFavorite(Song song);
  Future<bool> isFavorite(String songId);

  Future<List<Playlist>> getUserPlaylists();
  Future<Playlist> createPlaylist(String title, {String? description});
  Future<void> addSongToPlaylist(String playlistId, Song song);
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
  Future<void> deletePlaylist(String playlistId);
  Future<void> renamePlaylist(String playlistId, String newTitle);

  Future<List<String>> getSearchHistory();
  Future<void> addSearchHistory(String query);
  Future<void> clearSearchHistory();
}

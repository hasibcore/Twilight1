import 'package:flutter/foundation.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';

class PlaylistProvider extends ChangeNotifier {
  final MusicRepository musicRepository;

  List<Playlist> _playlists = [];
  List<Song> _favorites = [];
  List<Song> _recentlyPlayed = [];
  bool _isLoading = false;

  PlaylistProvider({required this.musicRepository}) {
    loadAll();
  }

  List<Playlist> get playlists => _playlists;
  List<Song> get favorites => _favorites;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  bool get isLoading => _isLoading;

  Future<void> loadAll({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        musicRepository.getUserPlaylists(),
        musicRepository.getFavorites(),
        musicRepository.getRecentlyPlayed(),
      ]);

      _playlists = results[0] as List<Playlist>;
      _favorites = results[1] as List<Song>;
      _recentlyPlayed = results[2] as List<Song>;
    } catch (_) {
      // Retain existing state if load encounters an error
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final newPl =
        await musicRepository.createPlaylist(title, description: description);
    _playlists.insert(0, newPl);
    notifyListeners();
    return newPl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await musicRepository.deletePlaylist(playlistId);
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
  }

  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    await musicRepository.renamePlaylist(playlistId, newTitle);
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index] = _playlists[index].copyWith(title: newTitle);
      notifyListeners();
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final plIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (plIndex != -1) {
      if (!_playlists[plIndex].songs.any((s) => s.id == song.id)) {
        final updated = List<Song>.from(_playlists[plIndex].songs)..add(song);
        _playlists[plIndex] = _playlists[plIndex].copyWith(songs: updated);
        notifyListeners();
      }
    }
    await musicRepository.addSongToPlaylist(playlistId, song);
    await loadAll(silent: true);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final plIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (plIndex != -1) {
      final updated = List<Song>.from(_playlists[plIndex].songs)
        ..removeWhere((s) => s.id == songId);
      _playlists[plIndex] = _playlists[plIndex].copyWith(songs: updated);
      notifyListeners();
    }
    await musicRepository.removeSongFromPlaylist(playlistId, songId);
    await loadAll(silent: true);
  }

  Future<void> toggleFavorite(Song song) async {
    final wasFav = _favorites.any((s) => s.id == song.id);
    if (wasFav) {
      _favorites = _favorites.where((s) => s.id != song.id).toList();
    } else {
      _favorites = [..._favorites, song];
    }
    notifyListeners();

    try {
      await musicRepository.toggleFavorite(song);
      _favorites = await musicRepository.getFavorites();
      notifyListeners();
    } catch (_) {
      if (wasFav) {
        _favorites = [..._favorites, song];
      } else {
        _favorites = _favorites.where((s) => s.id != song.id).toList();
      }
      notifyListeners();
    }
  }

  bool isSongFavorite(String songId) {
    return _favorites.any((s) => s.id == songId);
  }

  Future<void> clearRecentlyPlayed() async {
    await musicRepository.clearRecentlyPlayed();
    _recentlyPlayed = [];
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

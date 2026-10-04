import 'package:uuid/uuid.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/music_repository.dart';
import '../datasources/local_storage_datasource.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';

class MusicRepositoryImpl implements MusicRepository {
  final LocalStorageDatasource localDatasource;
  final Uuid _uuid = const Uuid();

  MusicRepositoryImpl({required this.localDatasource});

  @override
  Future<List<Song>> getRecentlyPlayed() async {
    final models = await localDatasource.getRecentlyPlayed();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> addRecentlyPlayed(Song song) async {
    await localDatasource.addRecentlyPlayed(SongModel.fromEntity(song));
  }

  @override
  Future<void> clearRecentlyPlayed() async {
    await localDatasource.clearRecentlyPlayed();
  }

  @override
  Future<List<Song>> getFavorites() async {
    final models = await localDatasource.getFavorites();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> toggleFavorite(Song song) async {
    await localDatasource.toggleFavorite(SongModel.fromEntity(song));
  }

  @override
  Future<bool> isFavorite(String songId) async {
    return await localDatasource.isFavorite(songId);
  }

  @override
  Future<List<Playlist>> getUserPlaylists() async {
    final models = await localDatasource.getUserPlaylists();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final newPlaylist = PlaylistModel(
      id: _uuid.v4(),
      title: title,
      description: description ?? '',
      thumbnailUrl: '',
      songs: [],
      isUserCreated: true,
      updatedAt: DateTime.now(),
    );

    final playlists = await localDatasource.getUserPlaylists();
    playlists.insert(0, newPlaylist);
    await localDatasource.saveUserPlaylists(playlists);
    return newPlaylist.toEntity();
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final playlists = await localDatasource.getUserPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final target = playlists[index];
      final existingSongs = List<SongModel>.from(target.songs);
      existingSongs.removeWhere((s) => s.id == song.id);
      existingSongs.insert(0, SongModel.fromEntity(song));

      final updated = PlaylistModel(
        id: target.id,
        title: target.title,
        description: target.description,
        thumbnailUrl: song.thumbnailUrl.isNotEmpty
            ? song.thumbnailUrl
            : target.thumbnailUrl,
        songs: existingSongs,
        isUserCreated: target.isUserCreated,
        updatedAt: DateTime.now(),
      );

      playlists[index] = updated;
      await localDatasource.saveUserPlaylists(playlists);
    }
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlists = await localDatasource.getUserPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final target = playlists[index];
      final existingSongs = List<SongModel>.from(target.songs);
      existingSongs.removeWhere((s) => s.id == songId);

      final updated = PlaylistModel(
        id: target.id,
        title: target.title,
        description: target.description,
        thumbnailUrl: target.thumbnailUrl,
        songs: existingSongs,
        isUserCreated: target.isUserCreated,
        updatedAt: DateTime.now(),
      );

      playlists[index] = updated;
      await localDatasource.saveUserPlaylists(playlists);
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    final playlists = await localDatasource.getUserPlaylists();
    playlists.removeWhere((p) => p.id == playlistId);
    await localDatasource.saveUserPlaylists(playlists);
  }

  @override
  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    final playlists = await localDatasource.getUserPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final target = playlists[index];
      playlists[index] = PlaylistModel(
        id: target.id,
        title: newTitle,
        description: target.description,
        thumbnailUrl: target.thumbnailUrl,
        songs: target.songs,
        isUserCreated: target.isUserCreated,
        updatedAt: DateTime.now(),
      );
      await localDatasource.saveUserPlaylists(playlists);
    }
  }

  @override
  Future<List<String>> getSearchHistory() async {
    return await localDatasource.getSearchHistory();
  }

  @override
  Future<void> addSearchHistory(String query) async {
    await localDatasource.addSearchHistory(query);
  }

  @override
  Future<void> clearSearchHistory() async {
    await localDatasource.clearSearchHistory();
  }
}

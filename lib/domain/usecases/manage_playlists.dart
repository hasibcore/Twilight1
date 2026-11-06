import '../entities/playlist.dart';
import '../entities/song.dart';
import '../repositories/music_repository.dart';

class ManagePlaylistsUseCase {
  final MusicRepository repository;

  ManagePlaylistsUseCase(this.repository);

  Future<List<Playlist>> getPlaylists() => repository.getUserPlaylists();
  Future<Playlist> create(String title, {String? description}) =>
      repository.createPlaylist(title, description: description);
  Future<void> addSong(String playlistId, Song song) =>
      repository.addSongToPlaylist(playlistId, song);
  Future<void> removeSong(String playlistId, String songId) =>
      repository.removeSongFromPlaylist(playlistId, songId);
  Future<void> delete(String playlistId) =>
      repository.deletePlaylist(playlistId);
  Future<void> rename(String playlistId, String newTitle) =>
      repository.renamePlaylist(playlistId, newTitle);
}
